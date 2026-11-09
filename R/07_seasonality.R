# =============================================================================
# Seasonality of processing employment vs fishery landings
# =============================================================================
#
# PAPER:   §2.5 (seasonality paragraph), §3.3 Processing employment is less
#          seasonal than fishery production; Figure 3 and the seasonality
#          table ("Table X" in §3.3).
#
# PURPOSE: For plants with at least half of their 2010-2023 real value in one
#          management group, the monthly employment profile (each month's
#          employment relative to the monthly mean, 2010-2022), compared with
#          the monthly profile of West Coast landings for the same group.
#          Main version: a plant's dominant group is judged on West
#          Coast-comparable value (wc_comparable, R/03), with excluded
#          products (Alaska-leaning groundfish, canned HMS, non-Dungeness
#          crab, breaded shrimp) kept in the denominator, so a plant mostly
#          packing Alaska pollock or imported tuna is not assigned to a group;
#          crab landings are Dungeness only. Unfiltered version, all products,
#          goes to the supplement.
#
#
# INPUTS:  data/confidential_wc_panel.rds - from R/03
#
# CONFIDENTIAL DATA (copy or symlink into data/; gitignored):
#          data/pp_employment.xlsx         - monthly employment by plant
#          data/pacfin_tables_monthly.RDS  - PacFIN landings by month
#
# NOTES:
#   - Employment profiles pool plants by dominant group; the figure shows
#     groups with at least 5 plants. Shellfish (state) is in the tables but
#     dropped from the figure (Connor, 2026-09-25): aquaculture-like, no
#     seasonality on either side.
#   - Landings are coastwide shoreside WA/OR/CA; the plants also process
#     at-sea and Alaska raw material, which is not in the landings series.
#   - No title or caption in the figure (R/figure_style.R); the source
#     notes that were embedded (landings = coastwide shoreside WA/OR/CA;
#     plants also process at-sea and Alaska raw material; shellfish omitted
#     as aquaculture-like) belong in the manuscript caption.
#
# OUTPUTS: comparable (main), plus an _unfiltered copy of each:
#          outputs/confidential/employment_profile_by_main_fmp.csv
#          outputs/confidential/table_seasonality_employment.csv
#          outputs/landings_profile_by_fmp.csv
#          outputs/table_seasonality_landings.csv
#          outputs/fig3_landings_vs_employment.pdf/.png             - Figure 3
#          outputs/figS_landings_vs_employment_unfiltered.pdf/.png  - supplement
# =============================================================================


# Setup ----
library(tidyverse)
library(janitor)
library(readxl)
library(here)

source(here("R", "figure_style.R"))

wc_panel <- readRDS(here("data", "confidential_wc_panel.rds"))

fmp_names <- c(GRND = "Groundfish", SAMN = "Salmon", CPEL = "Coastal pelagics",
               HMSP = "Highly migratory", CRAB = "Dungeness crab", SRMP = "Shrimp",
               SHLL = "Shellfish (state)", OTHR = "Other / non-FMP")

fmp_levels <- c("Groundfish", "Salmon", "Highly migratory", "Dungeness crab",
                "Shrimp", "Coastal pelagics", "Shellfish (state)", "Other / non-FMP")

# Step 1: Each plant's dominant management group ----
# The group with the most 2010-2023 real value, kept if it holds >= 50%. In
# the comparable frame, value outside wc_comparable counts as "excluded": it
# stays in the denominator and cannot be a plant's dominant group.

dominant_group <- function(panel) {
  panel %>%
    filter(year >= 2010, fmp != "OTHR") %>%
    group_by(pp_idnum, fmp_name) %>%
    summarize(v = sum(real, na.rm = TRUE), .groups = "drop") %>%
    group_by(pp_idnum) %>%
    mutate(share = v / sum(v)) %>%
    slice_max(v, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    filter(share >= 0.5, fmp_name != "excluded") %>%
    select(pp_idnum, main_fmp = fmp_name, main_share = share)
}

main_fmp_comparable <- dominant_group(wc_panel %>% mutate(fmp_name = if_else(wc_comparable, fmp_name, "excluded")))
main_fmp_unfiltered <- dominant_group(wc_panel)

# Step 2: Monthly employment profile by dominant group ----

pp_employment <- read_xlsx(here("data", "pp_employment.xlsx")) %>%
  clean_names() %>%
  mutate(
    pp_idnum = as.character(pp_idnum),
    year = as.numeric(year)
  )

# profile = month's employment / mean monthly employment; n_plants is the
# smallest monthly plant count for the group
employment_profile <- function(main_fmp) {
  pp_employment %>%
    filter(year >= 2010, pp_idnum %in% wc_panel$pp_idnum) %>%
    inner_join(main_fmp, by = "pp_idnum") %>%
    pivot_longer(ends_with("_emp"), names_to = "month", values_to = "emp") %>%
    mutate(month = match(substr(month, 1, 3), tolower(month.abb))) %>%
    filter(!is.na(emp)) %>%
    group_by(main_fmp, month) %>%
    summarize(emp = sum(emp), n_plants = n_distinct(pp_idnum), .groups = "drop") %>%
    group_by(main_fmp) %>%
    mutate(
      profile = emp / mean(emp),
      n_plants = min(n_plants)
    ) %>%
    ungroup()
}

employment_seasonality <- function(profile) {
  profile %>%
    group_by(main_fmp) %>%
    summarize(
      n_plants = first(n_plants),
      peak_month = month.abb[which.max(profile)],
      trough_month = month.abb[which.min(profile)],
      amplitude = max(profile) / min(profile),
      .groups = "drop"
    ) %>%
    arrange(desc(amplitude))
}

employment_comparable <- employment_profile(main_fmp_comparable)
employment_unfiltered <- employment_profile(main_fmp_unfiltered)

write_csv(employment_comparable, here("outputs", "confidential", "employment_profile_by_main_fmp.csv"))
write_csv(employment_unfiltered, here("outputs", "confidential", "employment_profile_by_main_fmp_unfiltered.csv"))
write_csv(employment_seasonality(employment_comparable),
          here("outputs", "confidential", "table_seasonality_employment.csv"))
write_csv(employment_seasonality(employment_unfiltered),
          here("outputs", "confidential", "table_seasonality_employment_unfiltered.csv"))

print(employment_seasonality(employment_comparable) %>% mutate(amplitude = round(amplitude, 2)))
print(employment_seasonality(employment_unfiltered) %>% mutate(amplitude = round(amplitude, 2)))

# Step 3: Monthly landings profile by management group, 2010-2022 ----
# Same groups as the employment figure (>= 5 plants). Comparable frame: crab
# landings are Dungeness (DCRB) only, matching the Dungeness-only processing.

pacfin_monthly <- readRDS(here("data", "pacfin_tables_monthly.RDS")) %>%
  filter(PACFIN_YEAR >= 2010, PACFIN_YEAR <= 2022)

landings_profile <- function(pacfin, employment) {
  pacfin %>%
    group_by(fmp = MANAGEMENT_GROUP_CODE, month = MONTH) %>%
    summarize(landed_mt = sum(TOTAL_LANDED_WEIGHT_MTONS, na.rm = TRUE), .groups = "drop") %>%
    mutate(fmp_name = unname(fmp_names[fmp])) %>%
    filter(fmp_name %in% unique(employment$main_fmp[employment$n_plants >= 5])) %>%
    group_by(fmp, fmp_name) %>%
    mutate(profile = landed_mt / mean(landed_mt)) %>%
    ungroup()
}

landings_seasonality <- function(profile) {
  profile %>%
    group_by(fmp, fmp_name) %>%
    summarize(
      peak_month = month.abb[which.max(profile)],
      trough_month = month.abb[which.min(profile)],
      peak_profile = max(profile),
      amplitude = max(profile) / min(profile),
      .groups = "drop"
    ) %>%
    arrange(desc(peak_profile))
}

landings_comparable <- landings_profile(
  pacfin_monthly %>% filter(MANAGEMENT_GROUP_CODE != "CRAB" | PACFIN_SPECIES_CODE == "DCRB"),
  employment_comparable
)
landings_unfiltered <- landings_profile(pacfin_monthly, employment_unfiltered)

write_csv(landings_comparable, here("outputs", "landings_profile_by_fmp.csv"))
write_csv(landings_unfiltered, here("outputs", "landings_profile_by_fmp_unfiltered.csv"))
write_csv(landings_seasonality(landings_comparable), here("outputs", "table_seasonality_landings.csv"))
write_csv(landings_seasonality(landings_unfiltered), here("outputs", "table_seasonality_landings_unfiltered.csv"))

print(landings_seasonality(landings_comparable) %>% mutate(across(where(is.double), ~ round(.x, 2))))

# Step 4: Figure 3 - landings (shaded) vs employment (line), one panel per group ----
# Shared y scale on purpose: landings swing to 4x the monthly mean, employment
# stays within about +/- 30%.

fmp_dropped <- "Shellfish (state)"

both_profiles <- function(landings, employment) {
  bind_rows(
    landings %>% transmute(fmp_name, month, profile, series = "Fishery landings (PacFIN)"),
    employment %>% filter(n_plants >= 5) %>% transmute(fmp_name = main_fmp, month, profile, series = "Plant employment")
  ) %>%
    filter(!fmp_name %in% fmp_dropped) %>%
    mutate(fmp_name = factor(fmp_name, levels = fmp_levels))
}

# One y limit for both versions so they can be compared
y_max <- 1.05 * max(landings_comparable$profile, landings_unfiltered$profile)

fig3 <- ggplot(both_profiles(landings_comparable, employment_comparable), aes(month, profile)) +
  geom_hline(yintercept = 1, color = "grey60", linewidth = 0.3) +
  geom_area(data = ~ filter(.x, series == "Fishery landings (PacFIN)"), aes(fill = series), alpha = 0.45) +
  geom_line(aes(color = series, linewidth = series)) +
  geom_point(data = ~ filter(.x, series == "Plant employment"), aes(color = series), size = 0.6) +
  facet_wrap(~fmp_name, ncol = 3) +
  scale_fill_manual(values = c("Fishery landings (PacFIN)" = "#9fc4ed")) +
  scale_color_manual(values = c("Fishery landings (PacFIN)" = "#5b8fc9", "Plant employment" = "#b6300f"),
                     breaks = "Plant employment") +
  scale_linewidth_manual(values = c("Fishery landings (PacFIN)" = 0.4, "Plant employment" = 0.7),
                         guide = "none") +
  scale_x_continuous(breaks = 1:12, labels = str_sub(month.abb, 1, 1),
                     expand = expansion(add = 0.4)) +
  scale_y_continuous(limits = c(0, y_max),
                     expand = expansion(mult = c(0, 0.02))) +
  labs(x = "Month", y = "Monthly value / monthly mean", color = NULL, fill = NULL) +
  theme_fishbull +
  theme(axis.text.x = element_text(size = 6.5))

save_figure(fig3, "fig3_landings_vs_employment", width = 6.5, height = 4.2)

# Supplement: all products, no origin filter
fig3_unfiltered <- fig3 + both_profiles(landings_unfiltered, employment_unfiltered)

save_figure(fig3_unfiltered, "figS_landings_vs_employment_unfiltered", width = 6.5, height = 4.2)
