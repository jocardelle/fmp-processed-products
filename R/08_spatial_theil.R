# =============================================================================
# Spatial concentration of processing vs landings — normalized Theil index
# =============================================================================
#
# PURPOSE: Compares how geographically concentrated processing is with how
#          concentrated landings are, by FMP and year. Processing = plant
#          pounds from the Processed Products survey, with plants mapped to
#          IOPAC port groups by city. Landings = PacFIN dealer round pounds by
#          IOPAC port group. Both sides use the same metric (pounds), the same
#          19 IOPAC port groups, and the same normalized Theil index,
#          T / ln(P), which runs from 0 (spread evenly across all ports) to 1
#          (all in one port).
#
#          Groundfish, HMS and crab mix West Coast fish with Alaska or
#          imported raw material, so the script also builds series that use
#          the tags from R/02_product_context.R to separate them:
#            - groundfish split into WC species vs Alaska-leaning species
#            - HMS split into canned (foreign canning complex) vs not canned
#            - squid-only coastal pelagics and Dungeness-only crab
#            - a "comparable" series that applies each FMP's correction
#          and repeats the processing side on the fixed panel of plants
#          reporting in >= 20 of 31 years (robustness).
#
#
# PAPER:   §2.5 (spatial concentration paragraphs), §3.7 Spatial
#          Distribution; Figure X (main), Figure X+1 (groundfish by origin),
#          and the supplementary unfiltered and fixed-panel figures.
#
# INPUTS:  outputs/product_context_flags.csv - from R/02_product_context.R
#          data/iopac_lt.csv                 - PacFIN port -> IOPAC port group
#          data/sp_code.csv                  - PacFIN species -> management group
#
# CONFIDENTIAL DATA (never in this repository; copy or symlink into data/
#          from processor_cluster/data/ on the project volume):
#          data/pp_processed.csv     - plant-level pounds by product
#          data/pp_address_23.xlsx   - plant addresses
#          data/pacfin_dealer.duckdb - PacFIN dealer landings
#
# CAVEATS:
#   - At-sea processors have no port group and are excluded (~4.3B lbs,
#     groundfish-heavy).
#   - Origin proxies are one-directional: Alaska fish of shared species
#     (sablefish, rockfish, flatfish) sit in the "WC species" bucket, biasing
#     AGAINST the reported separation; not-canned HMS still contains imports.
#   - Salmon cannot be split (same species both origins) - its series carries
#     the Alaska caveat unresolved.
#   - CPS coverage is ~1/3 of landed pounds (non-reporting squid freezers), so
#     the CPS processing series may reflect the survey frame as much as the
#     industry; treat its trend as frame-sensitive.
#   - ~35 inland plant cities are assigned to IOPAC groups by hand (Step 1).
#   - Disclosure: Theil values are aggregates and can be shared. The share
#     tables in outputs/confidential/ carry n_plants; any cell with
#     n_plants < 3 stays on the project volume. outputs/confidential/ is
#     gitignored.
#
# OUTPUTS: outputs/theil_by_fmp_year.csv                      - all products
#          outputs/theil_comparable_by_fmp_year.csv           - filtered
#          outputs/theil_grnd_origin_split.csv                - groundfish by origin
#          outputs/theil_single_species.csv                   - squid, Dungeness
#          outputs/theil_by_fmp_year_fixed_panel.csv          - robustness
#          outputs/theil_comparable_by_fmp_year_fixed_panel.csv - robustness
#          outputs/theil_fixed_panel_era_change.csv           - first vs last era
#          outputs/confidential/theil_grnd_origin_shares.csv  - (gitignored)
#          outputs/confidential/theil_hms_form_split.csv      - (gitignored)
#          outputs/figX_theil_main_filtered.pdf/.png               - Figure X (main)
#          outputs/figX1_theil_grnd_origin_split.pdf/.png          - Figure X+1
#          outputs/figSX_theil_unfiltered.pdf/.png                 - supplement
#          outputs/figSX_theil_filtered_fixed_panel.pdf/.png       - supplement
#          outputs/figSX_theil_unfiltered_fixed_panel.pdf/.png     - supplement
# =============================================================================


# Setup ----
library(tidyverse)
library(janitor)
library(readxl)
library(duckdb)
library(DBI)
library(here)

source(here("R", "figure_style.R"))

dir.create(here("outputs", "confidential"), showWarnings = FALSE)

analysis_years <- 1993:2023
west_coast_states <- c("WA", "OR", "CA")

# Analysis eras used for the summary tables
assign_era <- function(year) {
  case_when(
    year %in% 1993:1999 ~ "1993-99",
    year %in% 2000:2009 ~ "2000-09",
    year %in% 2010:2016 ~ "2010-16",
    year %in% 2017:2023 ~ "2017-23"
  )
}

# Step 1: Map plants to IOPAC port groups ----
# Plants are matched to a port group by city, using both the PacFIN port name
# and its longer description.

iopac_lt <- read_csv(here("data", "iopac_lt.csv"), show_col_types = FALSE) %>%
  clean_names()

# Inland/processing cities absent from the PacFIN port list, assigned to the
# geographically associated IOPAC group (exploratory audit 2026-10-01).
manual_cities <- tribble(
  ~city,               ~iopac,
  "VERNON",            "Los Angeles",
  "SANTA FE SPRINGS",  "Los Angeles",
  "LOS ANGELES",       "Los Angeles",
  "WILMINGTON",        "Los Angeles",
  "RANCHO DOMINGUEZ",  "Los Angeles",
  "ANAHEIM",           "Los Angeles",
  "HUNTINGTON PARK",   "Los Angeles",
  "CITY OF INDUSTRY",  "Los Angeles",
  "WARRENTON",         "Astoria",
  "HAMMOND",           "Astoria",
  "WATSONVILLE",       "Monterey",
  "SALINAS",           "Monterey",
  "MORGAN HILL",       "Monterey",
  "FRESNO",            "Monterey",
  "REDMOND",           "Puget Sound",
  "RENTON",            "Puget Sound",
  "SUMNER",            "Puget Sound",
  "FIFE",              "Puget Sound",
  "KENT",              "Puget Sound",
  "BURLINGTON",        "Puget Sound",
  "BAINBRIDGE ISLAND", "Puget Sound",
  "FEDERAL WAY",       "Puget Sound",
  "EDMONDS",           "Puget Sound",
  "ILWACO",            "Columbia River",
  "WOODLAND",          "Columbia River",
  "PORTLAND",          "Columbia River",
  "CLACKAMAS",         "Columbia River",
  "SALEM",             "Columbia River",
  "SOUTH BEND",        "WA Coast",
  "BAY CENTER",        "WA Coast",
  "CHARLESTON",        "Coos Bay",
  "HAYWARD",           "San Francisco",
  "SAN JOSE",          "San Francisco",
  "SACRAMENTO",        "San Francisco",
  "YUBA CITY",         "San Francisco",
  "EL GRANADA",        "San Francisco",
  "SANTA ROSA",        "Bodega Bay",
  "BAY CITY",          "Tillamook"
)

city_iopac <- bind_rows(
  iopac_lt %>% transmute(city = toupper(pacfin_port_name), iopac),
  iopac_lt %>% transmute(city = toupper(pacfin_port_description), iopac),
  manual_cities
) %>%
  distinct(city, .keep_all = TRUE)

pp_address <- read_xlsx(here("data", "pp_address_23.xlsx")) %>%
  clean_names() %>%
  mutate(
    pp_idnum = as.character(pp_idnum),
    state = coalesce(plant_state_abrv, state_abrv),
    city = toupper(coalesce(plant_city, city))
  ) %>%
  filter(state %in% west_coast_states) %>%
  distinct(pp_idnum, city) %>%
  left_join(city_iopac, by = "city")

# Plants with a port group, out of all WA/OR/CA plants
pp_address %>%
  summarize(plants_with_iopac = sum(!is.na(iopac)), plants = n()) %>%
  print()

# Step 2: Build the processing panel ----
# Plant pounds by product, WA/OR/CA plants with a port group, 1993-2023,
# joined to the FMP crosswalk and context tags.

pp_processed <- read_csv(here("data", "pp_processed.csv"), show_col_types = FALSE) %>%
  clean_names() %>%
  mutate(
    pp_idnum = as.character(pp_idnum),
    pp_code = as.character(pp_code)
  )

products <- read_csv(here("outputs", "product_context_flags.csv"),
                     show_col_types = FALSE) %>%
  transmute(
    pp_code = as.character(product_code),
    product_description,
    species = species_word,
    fmp = management_group,
    product_form,
    alaska_species_grnd,
    hms_canned,
    single_species
  ) %>%
  distinct(pp_code, .keep_all = TRUE)

processing <- pp_processed %>%
  filter(year %in% analysis_years) %>%
  inner_join(pp_address %>% filter(!is.na(iopac)), by = "pp_idnum") %>%
  left_join(products, by = "pp_code") %>%
  mutate(
    fmp = coalesce(fmp, "OTHR"),
    era = assign_era(year)
  )

# Share of West Coast pounds that land at a plant with a port group
wc_pounds <- pp_processed %>%
  filter(year >= 1993, pp_idnum %in% pp_address$pp_idnum) %>%
  pull(pounds) %>%
  sum(na.rm = TRUE)

print(round(sum(processing$pounds, na.rm = TRUE) / wc_pounds, 3))

# Step 3: Build the landings panel ----
# PacFIN dealer round pounds (landed weight where round is missing or zero)
# by year, IOPAC port group and species, mapped to management group.

sp_code <- read_csv(here("data", "sp_code.csv"), show_col_types = FALSE) %>%
  clean_names() %>%
  transmute(
    species_name = toupper(species_common_name),
    fmp = management_group_code
  ) %>%
  distinct(species_name, .keep_all = TRUE)

con <- dbConnect(duckdb(), here("data", "pacfin_dealer.duckdb"), read_only = TRUE)

landings <- dbGetQuery(con, "
  SELECT PACFIN_YEAR AS year,
         IOPAC_PORT_GROUP AS iopac,
         UPPER(PACFIN_SPECIES_COMMON_NAME) AS species_name,
         SUM(COALESCE(NULLIF(ROUND_WEIGHT_LBS, 0), LANDED_WEIGHT_LBS)) AS lbs
  FROM dealer_species_year
  WHERE PACFIN_YEAR BETWEEN 1993 AND 2023
  GROUP BY 1, 2, 3
")

dbDisconnect(con, shutdown = TRUE)

# Port group names in PacFIN are upper case; match them to the IOPAC lookup
landings <- landings %>%
  left_join(sp_code, by = "species_name") %>%
  mutate(
    iopac = str_to_title(iopac),
    iopac = recode(iopac,
                   "Wa Coast" = "WA Coast",
                   "North Wa Coast" = "North WA Coast",
                   "Morro" = "Morro Bay",
                   "South And Central Wa Coast" = "WA Coast")
  ) %>%
  filter(!is.na(fmp), !is.na(iopac), !iopac %in% c("Na", "Unknown Ports"))

# The port-group universe is shared by both sides: 19 groups
iopac_all <- sort(union(unique(landings$iopac), unique(na.omit(pp_address$iopac))))
n_ports <- length(iopac_all)
stopifnot(n_ports == 19)

# Step 4: Normalized Theil index ----
# For each year and FMP: each port's share s of pounds, across all 19 ports
# (ports with no pounds get s = 1e-10), then
#   theil = sum(s * log(n_ports * s)) / log(n_ports)
# Used for every series below, processing and landings alike.

normalized_theil <- function(df, pounds_col) {
  df %>%
    group_by(year, fmp, iopac) %>%
    summarize(v = sum(.data[[pounds_col]], na.rm = TRUE), .groups = "drop") %>%
    complete(year = analysis_years, fmp = unique(df$fmp), iopac = iopac_all,
             fill = list(v = 0)) %>%
    group_by(year, fmp) %>%
    mutate(
      s = v / sum(v),
      s = replace(s, s == 0 | is.nan(s), 1e-10)
    ) %>%
    summarize(theil = sum(s * log(n_ports * s)) / log(n_ports), .groups = "drop")
}

# Step 5: Processing vs landings, all FMPs ----

theil_by_fmp <- full_join(
  normalized_theil(processing, "pounds") %>% rename(theil_processing = theil),
  normalized_theil(landings, "lbs") %>% rename(theil_landings = theil),
  by = c("year", "fmp")
) %>%
  filter(fmp %in% c("GRND", "SAMN", "CPEL", "HMSP", "CRAB", "SRMP", "SHLL", "OTHR"))

write_csv(theil_by_fmp, here("outputs", "theil_by_fmp_year.csv"))

# Era means, processing vs landings
theil_by_fmp %>%
  mutate(era = assign_era(year)) %>%
  group_by(fmp, era) %>%
  summarize(
    proc = round(mean(theil_processing), 2),
    land = round(mean(theil_landings, na.rm = TRUE), 2),
    .groups = "drop"
  ) %>%
  pivot_wider(names_from = era, values_from = c(proc, land)) %>%
  print(width = 140)

# Step 6: Groundfish split by origin ----
# Species identity as the origin proxy (alaska_species_grnd, from R/02).

groundfish <- processing %>%
  filter(fmp == "GRND")

grnd_origin_theil <- bind_rows(
  normalized_theil(groundfish %>% mutate(fmp = "GRND_all"), "pounds"),
  normalized_theil(groundfish %>% filter(!alaska_species_grnd) %>% mutate(fmp = "GRND_wc_species"), "pounds"),
  normalized_theil(groundfish %>% filter(alaska_species_grnd) %>% mutate(fmp = "GRND_alaska_species"), "pounds"),
  normalized_theil(landings %>% filter(fmp == "GRND") %>% mutate(fmp = "GRND_landings"), "lbs")
)

write_csv(grnd_origin_theil, here("outputs", "theil_grnd_origin_split.csv"))

# Pounds, Puget Sound share and plant counts by era and origin (confidential)
grnd_origin_shares <- groundfish %>%
  group_by(era, origin = if_else(alaska_species_grnd, "alaska_species", "wc_species")) %>%
  summarize(
    mlbs_per_yr = round(sum(pounds, na.rm = TRUE) / 1e6 / n_distinct(year)),
    puget_share = round(sum(pounds[iopac == "Puget Sound"], na.rm = TRUE) /
                          sum(pounds, na.rm = TRUE), 2),
    n_plants = n_distinct(pp_idnum),
    .groups = "drop"
  )

write_csv(grnd_origin_shares, here("outputs", "confidential", "theil_grnd_origin_shares.csv"))
print(grnd_origin_shares)

# Step 7: HMS split by product form ----
# Canned HMS is the foreign-sourced canning complex (hms_canned, from R/02).

hms_landings_by_era <- landings %>%
  filter(fmp == "HMSP") %>%
  mutate(era = assign_era(year)) %>%
  group_by(era) %>%
  summarize(
    wc_landings_mlbs_per_yr = round(sum(lbs) / 1e6 / n_distinct(year)),
    .groups = "drop"
  )

hms_form_split <- processing %>%
  filter(fmp == "HMSP") %>%
  group_by(era, segment = if_else(hms_canned, "canned", "not_canned")) %>%
  summarize(
    mlbs_per_yr = round(sum(pounds, na.rm = TRUE) / 1e6 / n_distinct(year)),
    la_share = round(sum(pounds[iopac == "Los Angeles"], na.rm = TRUE) /
                       sum(pounds, na.rm = TRUE), 2),
    n_plants = n_distinct(pp_idnum),
    .groups = "drop"
  ) %>%
  left_join(hms_landings_by_era, by = "era")

write_csv(hms_form_split, here("outputs", "confidential", "theil_hms_form_split.csv"))
print(hms_form_split)

# Step 8: Single-species series ----
# Squid-only coastal pelagics and Dungeness-only crab (single_species, from
# R/02), each against the same species' landings.

single_species_theil <- bind_rows(
  normalized_theil(processing %>% filter(single_species %in% "squid only") %>% mutate(fmp = "CPEL_squid_only"), "pounds"),
  normalized_theil(processing %>% filter(single_species %in% "dungeness only") %>% mutate(fmp = "CRAB_dungeness_only"), "pounds"),
  normalized_theil(landings %>% filter(species_name == "MARKET SQUID") %>% mutate(fmp = "CPEL_squid_landings"), "lbs"),
  normalized_theil(landings %>% filter(species_name == "DUNGENESS CRAB") %>% mutate(fmp = "CRAB_dungeness_landings"), "lbs")
)

write_csv(single_species_theil, here("outputs", "theil_single_species.csv"))

# Era means
single_species_theil %>%
  mutate(era = assign_era(year)) %>%
  group_by(fmp, era) %>%
  summarize(theil = round(mean(theil), 2), .groups = "drop") %>%
  pivot_wider(names_from = era, values_from = theil) %>%
  print()

# Step 9: Comparable (origin-resolved) series ----
# Each FMP gets its own correction so no single confound gets special
# billing:
#   GRND = WC species only
#   HMSP = not canned only
#   CRAB = Dungeness products / species only
#   SRMP = excluding further processed (breaded, import-leaning)
# SAMN, CPEL and SHLL have no filter that can be applied (Alaska salmon
# unresolvable; CPS frame; shellfish exception) and keep all products, with
# the caveats carried in the figure labels. OTHR is the residual and keeps
# all products.

processing_comparable <- bind_rows(
  processing %>% filter(fmp == "GRND", !alaska_species_grnd),
  processing %>% filter(fmp == "HMSP", !hms_canned),
  processing %>% filter(fmp == "CRAB", single_species %in% "dungeness only"),
  processing %>% filter(fmp == "SRMP", product_form != "further processed"),
  processing %>% filter(fmp %in% c("SAMN", "CPEL", "SHLL", "OTHR"))
)

landings_comparable <- bind_rows(
  landings %>% filter(fmp %in% c("GRND", "HMSP", "SAMN", "CPEL", "SHLL", "SRMP", "OTHR")),
  landings %>% filter(fmp == "CRAB", species_name == "DUNGENESS CRAB")
)

theil_comparable <- full_join(
  normalized_theil(processing_comparable, "pounds") %>% rename(theil_processing = theil),
  normalized_theil(landings_comparable, "lbs") %>% rename(theil_landings = theil),
  by = c("year", "fmp")
)

write_csv(theil_comparable, here("outputs", "theil_comparable_by_fmp_year.csv"))

# Step 10: Robustness - fixed panel of plants ----
# Reporting plants are a convenience sample, so the frame turns over. Recompute
# processing on the fixed panel: WA/OR/CA plants reporting in at least 20 of
# the 31 study years (same rule as the fixed frame in Figure 4,
# fmp_processing/R/01_fmp_panel_tables.R). Landings are unchanged.

min_years_reported <- 20

fixed_plants <- pp_processed %>%
  filter(year >= 1993, pp_idnum %in% pp_address$pp_idnum) %>%
  distinct(pp_idnum, year) %>%
  count(pp_idnum) %>%
  filter(n >= min_years_reported) %>%
  pull(pp_idnum)

processing_fixed <- processing %>%
  filter(pp_idnum %in% fixed_plants)
processing_comparable_fixed <- processing_comparable %>%
  filter(pp_idnum %in% fixed_plants)

# Fixed-panel plants, and their share of the processing pounds used above
tibble(
  fixed_plants = length(fixed_plants),
  fixed_plants_with_iopac = n_distinct(processing_fixed$pp_idnum),
  share_of_pounds = round(sum(processing_fixed$pounds, na.rm = TRUE) /
                            sum(processing$pounds, na.rm = TRUE), 3)
) %>%
  print()

theil_by_fmp_fixed <- full_join(
  normalized_theil(processing_fixed, "pounds") %>% rename(theil_processing = theil),
  normalized_theil(landings, "lbs") %>% rename(theil_landings = theil),
  by = c("year", "fmp")
) %>%
  filter(fmp %in% c("GRND", "SAMN", "CPEL", "HMSP", "CRAB", "SRMP", "SHLL", "OTHR"))

theil_comparable_fixed <- full_join(
  normalized_theil(processing_comparable_fixed, "pounds") %>% rename(theil_processing = theil),
  normalized_theil(landings_comparable, "lbs") %>% rename(theil_landings = theil),
  by = c("year", "fmp")
)

write_csv(theil_by_fmp_fixed, here("outputs", "theil_by_fmp_year_fixed_panel.csv"))
write_csv(theil_comparable_fixed, here("outputs", "theil_comparable_by_fmp_year_fixed_panel.csv"))

# Processing Theil, first vs last era: all plants vs fixed panel (comparable series)
era_change <- bind_rows(
  theil_comparable %>% mutate(frame = "all plants"),
  theil_comparable_fixed %>% mutate(frame = "fixed panel")
) %>%
  mutate(era = assign_era(year)) %>%
  filter(era %in% c("1993-99", "2017-23")) %>%
  group_by(fmp, frame, era) %>%
  summarize(theil = round(mean(theil_processing), 2), .groups = "drop") %>%
  pivot_wider(names_from = era, values_from = theil) %>%
  mutate(change = `2017-23` - `1993-99`) %>%
  arrange(fmp, frame)

write_csv(era_change, here("outputs", "theil_fixed_panel_era_change.csv"))
print(era_change, n = 20)

# Step 11: Figures ----
# Main manuscript: the filtered (comparable) series, Step 9.
# Supplement: the same layout, unfiltered (all products), Step 5.
# Also kept: groundfish by origin, Step 6.

side_colors <- c("Processing (plant pounds)" = "#1d5f6e",
                 "Landings (round pounds)" = "#c46a1f")

# Long format with readable panel and line labels, for the two FMP-panel figures
theil_long <- function(df, panel_names) {
  df %>%
    filter(fmp %in% names(panel_names)) %>%
    pivot_longer(starts_with("theil_"), names_to = "side", values_to = "theil") %>%
    filter(!is.na(theil)) %>%
    mutate(
      side = recode(side,
                    theil_processing = "Processing (plant pounds)",
                    theil_landings = "Landings (round pounds)"),
      fmp_name = factor(panel_names[fmp], unname(panel_names))
    )
}

# Main manuscript figure: filtered (comparable) series ----
# Each panel label states the filter applied to that FMP.
comparable_names <- c(GRND = "Groundfish (WC species only)",
                      SAMN = "Salmon (all; AK unresolved)",
                      CPEL = "Coastal pelagics (all; frame caveat)",
                      HMSP = "Highly migratory (non-canned only)",
                      CRAB = "Dungeness crab (Dungeness only)",
                      SRMP = "Shrimp (excl. breaded products)",
                      SHLL = "Shellfish, state (all)",
                      OTHR = "Other / non-FMP (all; residual)")

fig_main <- ggplot(theil_long(theil_comparable, comparable_names), aes(year, theil, color = side)) +
  geom_line(linewidth = 0.6) +
  facet_wrap(~fmp_name, ncol = 2) +
  scale_color_manual(values = side_colors) +
  scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.25)) +
  scale_x_continuous(breaks = seq(1995, 2020, 5)) +
  labs(y = "Normalized Theil index", x = "Year", color = NULL) +
  theme_fishbull

save_figure(fig_main, "figX_theil_main_filtered", width = 6.5, height = 7.5)

# Supplementary figure: unfiltered series, all products ----
fmp_names <- c(GRND = "Groundfish", SAMN = "Salmon", CPEL = "Coastal pelagics",
               HMSP = "Highly migratory", CRAB = "Dungeness crab", SRMP = "Shrimp",
               SHLL = "Shellfish (state)", OTHR = "Other / non-FMP")

fig_sm <- fig_main + theil_long(theil_by_fmp, fmp_names)

save_figure(fig_sm, "figSX_theil_unfiltered", width = 6.5, height = 7.5)

# Fixed-panel versions of both figures (robustness, Step 10) ----
# Same plots, processing recomputed on the fixed panel (adding a data frame
# to a ggplot swaps in the new data).
fig_main_fixed <- fig_main + theil_long(theil_comparable_fixed, comparable_names)
fig_sm_fixed <- fig_main + theil_long(theil_by_fmp_fixed, fmp_names)

save_figure(fig_main_fixed, "figSX_theil_filtered_fixed_panel", width = 6.5, height = 7.5)
save_figure(fig_sm_fixed, "figSX_theil_unfiltered_fixed_panel", width = 6.5, height = 7.5)

# Groundfish by origin ----
grnd_series <- c(
  GRND_alaska_species = "Alaska-species processing (pollock, cod...)",
  GRND_all = "All groundfish processing",
  GRND_wc_species = "WC-species processing (whiting, rockfish, sablefish...)",
  GRND_landings = "WC groundfish landings"
)

grnd_colors <- c("Alaska-species processing (pollock, cod...)" = "#8a8f94",
                 "All groundfish processing" = "#7fa8b1",
                 "WC-species processing (whiting, rockfish, sablefish...)" = "#1d5f6e",
                 "WC groundfish landings" = "#c46a1f")

fig_grnd_data <- grnd_origin_theil %>%
  mutate(series = factor(grnd_series[fmp], unname(grnd_series)))

fig_grnd <- ggplot(fig_grnd_data, aes(year, theil, color = series)) +
  geom_line(linewidth = 0.6) +
  scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.25)) +
  scale_x_continuous(breaks = seq(1995, 2020, 5)) +
  scale_color_manual(values = grnd_colors) +
  labs(y = "Normalized Theil index", x = "Year", color = NULL) +
  guides(color = guide_legend(nrow = 2)) +
  theme_fishbull

save_figure(fig_grnd, "figX1_theil_grnd_origin_split", width = 6.5, height = 4)
