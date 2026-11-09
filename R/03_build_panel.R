# =============================================================================
# West Coast processing panel — the record-level data behind every result
# =============================================================================
#
# PAPER:   §2.1 (scope: WA/OR/CA plants), §2.3 (constant 2023 dollars).
#          Every script from 04 on reads the panel written here.
#
# PURPOSE: Keeps every Processed Products record from a plant with a
#          Washington, Oregon, or California address, attaches the management
#          group, product form and origin tags from R/01-02, converts dollars
#          to constant 2023 dollars, and screens every management group-year
#          for disclosure (plant counts and the largest plant's share).
#
#
# INPUTS:  outputs/product_context_flags.csv - from R/02 (management group,
#                                              product form, origin tags)
#          data/A191RD3A086NBEA.csv          - GDP implicit price deflator
#                                              (BEA via FRED, 2017 = 100)
#
# CONFIDENTIAL DATA (never in this repository; copy or symlink into data/
#          from processor_cluster/data/ on the project volume):
#          data/pp_processed.csv   - plant-level quantities and values
#          data/pp_address_23.xlsx - plant addresses
#
# DECISIONS:
#   - West Coast = the plant's reporting address (plant state, or mailing
#     state where the plant state is blank). At-sea processors carry a WA
#     address and are kept here; they drop out of the spatial analysis only
#     (R/08).
#   - Real values use the GDP implicit price deflator rebased to 2023
#     (decision 2026-10-01: processed value is an output measure, so follow
#     the FEUS commercial-fisheries convention, not CPI).
#   - Product codes with no crosswalk entry are Other / non-FMP, product
#     form "other / unclassified".
#   - wc_comparable marks the West Coast-comparable subset used in the main
#     figures (05-08): groundfish without Alaska-leaning species, HMS without
#     canned, crab Dungeness only, shrimp without further processed. Salmon,
#     coastal pelagics, shellfish and Other have no filter. The same rule as
#     the comparable Theil series in R/08. Unfiltered versions go to the
#     supplement.
#
# OUTPUTS: data/confidential_wc_panel.rds - record-level panel (gitignored)
#          outputs/confidential/disclosure_screen_fmp_year.csv - plants and
#            top-plant share for every management group-year (gitignored)
# =============================================================================


# Setup ----
library(tidyverse)
library(janitor)
library(readxl)
library(here)

west_coast_states <- c("WA", "OR", "CA")

fmp_names <- c(GRND = "Groundfish", SAMN = "Salmon", CPEL = "Coastal pelagics",
               HMSP = "Highly migratory", CRAB = "Dungeness crab", SRMP = "Shrimp",
               SHLL = "Shellfish (state)", OTHR = "Other / non-FMP")

assign_era <- function(year) {
  case_when(
    year %in% 1993:1999 ~ "1993-99",
    year %in% 2000:2009 ~ "2000-09",
    year %in% 2010:2016 ~ "2010-16",
    year %in% 2017:2023 ~ "2017-23"
  )
}

dir.create(here("outputs", "confidential"), showWarnings = FALSE)

# Step 1: West Coast plants ----
# Plant state, or the mailing state where the plant state is blank

wc_plants <- read_xlsx(here("data", "pp_address_23.xlsx")) %>%
  clean_names() %>%
  mutate(
    pp_idnum = as.character(pp_idnum),
    state = coalesce(plant_state_abrv, state_abrv),
    city = toupper(coalesce(plant_city, city))
  ) %>%
  filter(state %in% west_coast_states) %>%
  select(pp_idnum, state, city)

# Step 2: Products ----
# Management group, product form and origin tags, one row per product code

products <- read_csv(here("outputs", "product_context_flags.csv"),
                     show_col_types = FALSE) %>%
  transmute(
    pp_code = as.character(product_code),
    pp_dscp = product_description,
    group_name,
    species = species_word,
    fmp = management_group,
    form = product_form,
    alaska_species_grnd,
    hms_canned,
    single_species
  ) %>%
  distinct(pp_code, .keep_all = TRUE)

# Step 3: GDP deflator, rebased to 2023 ----

deflator <- read_csv(here("data", "A191RD3A086NBEA.csv"), show_col_types = FALSE) %>%
  transmute(
    year = as.numeric(substr(observation_date, 1, 4)),
    deflator = A191RD3A086NBEA
  )

deflator_2023 <- deflator$deflator[deflator$year == 2023]

# Step 4: Build the panel ----

pp_processed <- read_csv(here("data", "pp_processed.csv"), show_col_types = FALSE) %>%
  clean_names() %>%
  mutate(
    pp_idnum = as.character(pp_idnum),
    pp_code = as.character(pp_code)
  )

wc_panel <- pp_processed %>%
  inner_join(wc_plants, by = "pp_idnum") %>%
  left_join(products, by = "pp_code") %>%
  left_join(deflator, by = "year") %>%
  mutate(
    fmp = coalesce(fmp, "OTHR"),
    fmp_name = unname(fmp_names[fmp]),
    form = coalesce(form, "other / unclassified"),
    real = dollars * deflator_2023 / deflator,
    era = assign_era(year),
    wc_comparable = case_when(
      fmp == "GRND" ~ alaska_species_grnd %in% FALSE,
      fmp == "HMSP" ~ hms_canned %in% FALSE,
      fmp == "CRAB" ~ single_species %in% "dungeness only",
      fmp == "SRMP" ~ form != "further processed",
      TRUE ~ TRUE
    )
  )

# Share of real value outside the West Coast-comparable subset, by group
wc_panel %>%
  filter(year >= 1993) %>%
  group_by(fmp_name) %>%
  summarize(share_excluded = round(sum(real[!wc_comparable], na.rm = TRUE) /
                                     sum(real, na.rm = TRUE), 3)) %>%
  print()

# Share of real value with no product form, and the largest unclassified groups
wc_panel %>%
  summarize(share_unclassified = round(sum(real[form == "other / unclassified"], na.rm = TRUE) /
                                         sum(real, na.rm = TRUE), 3)) %>%
  print()

wc_panel %>%
  filter(form == "other / unclassified") %>%
  group_by(group_name) %>%
  summarize(real_m = round(sum(real, na.rm = TRUE) / 1e6)) %>%
  arrange(desc(real_m)) %>%
  head(10) %>%
  print()

saveRDS(wc_panel, here("data", "confidential_wc_panel.rds"))

# Step 5: Disclosure screen ----
# For every management group-year: reporting plants with positive value, and
# the share of value held by the largest one and two plants. Results are
# reported only for groups with at least three plants (§2.1).

disclosure_screen <- wc_panel %>%
  group_by(year, fmp, fmp_name, pp_idnum) %>%
  summarize(v = sum(real, na.rm = TRUE), .groups = "drop") %>%
  filter(v > 0) %>%
  group_by(year, fmp, fmp_name) %>%
  summarize(
    n_plants = n(),
    top1 = max(v) / sum(v),
    top2 = sum(sort(v, decreasing = TRUE)[1:min(2, n())]) / sum(v),
    .groups = "drop"
  )

write_csv(disclosure_screen, here("outputs", "confidential", "disclosure_screen_fmp_year.csv"))

# Management group-years with < 3 plants or a top plant > 60%, 1993-2023
disclosure_screen %>%
  filter(year >= 1993, n_plants < 3 | top1 > 0.6) %>%
  group_by(fmp_name) %>%
  summarize(years = n(), max_top1 = round(max(top1), 2), min_n = min(n_plants)) %>%
  print()
