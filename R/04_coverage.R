# =============================================================================
# Survey coverage by management group — processed vs landed
# =============================================================================
#
# PAPER:   §2.4 Evaluating coverage by management group; coverage table
#          (currently "Table 2" in §2.4).
#
# PURPOSE: Compares what the survey reports with what is landed on the West
#          Coast, by management group, 2010-2023: processed pounds over landed
#          pounds, and processed value over ex-vessel value. A ratio well
#          below 1 means the survey misses part of the fishery; a ratio above
#          1 means product from outside the West Coast (Alaska, at-sea,
#          imported) is in the processed numerator. Main version uses the
#          West Coast-comparable products (wc_comparable, R/03) against
#          Dungeness-only crab landings; the unfiltered version keeps every
#          product and every crab species.
#
#
# INPUTS:  data/confidential_wc_panel.rds - from R/03
#
# CONFIDENTIAL DATA (copy or symlink into data/; gitignored):
#          data/pacfin_tables_monthly.RDS - PacFIN landings and ex-vessel
#            revenue by year, month, species, management group and port
#            (from csvi_production/ on the project volume)
#
# NOTES:
#   - Processed value and pounds are nominal and product weight; landings
#     are PacFIN landed weight (metric tons x 2204.62). The monthly tables
#     carry no round weight, so the draft caption should read "product
#     weight over landed weight".
#   - Ratios are computed per year, then averaged over 2010-2023.
#
# OUTPUTS: outputs/table_coverage_by_fmp.csv            - comparable (main)
#          outputs/table_coverage_by_fmp_unfiltered.csv - all products
# =============================================================================


# Setup ----
library(tidyverse)
library(here)

wc_panel <- readRDS(here("data", "confidential_wc_panel.rds"))

# Step 1: PacFIN landings and ex-vessel revenue by year and management group ----

pacfin_monthly <- readRDS(here("data", "pacfin_tables_monthly.RDS"))

landings_by_year <- function(pacfin) {
  pacfin %>%
    group_by(year = PACFIN_YEAR, fmp = MANAGEMENT_GROUP_CODE) %>%
    summarize(
      exvessel = sum(TOTAL_EXVESSEL_REVENUE, na.rm = TRUE),
      landed_lbs = sum(TOTAL_LANDED_WEIGHT_MTONS, na.rm = TRUE) * 2204.62,
      .groups = "drop"
    )
}

# Step 2: Processed value and pounds by year and management group ----

processed_by_year <- function(panel) {
  panel %>%
    filter(year >= 2010) %>%
    group_by(year, fmp, fmp_name) %>%
    summarize(
      pp_value = sum(dollars, na.rm = TRUE),
      pp_lbs = sum(pounds, na.rm = TRUE),
      n_plants = n_distinct(pp_idnum),
      .groups = "drop"
    )
}

# Step 3: Coverage ratios, averaged over years ----

coverage <- function(processed, pacfin) {
  processed %>%
    inner_join(pacfin, by = c("year", "fmp")) %>%
    mutate(
      value_ratio = pp_value / exvessel,
      lbs_ratio = pp_lbs / landed_lbs
    ) %>%
    group_by(fmp, fmp_name) %>%
    summarize(
      pp_value_over_exvessel = mean(value_ratio),
      pp_lbs_over_landed = mean(lbs_ratio),
      plants = mean(n_plants),
      .groups = "drop"
    ) %>%
    arrange(pp_lbs_over_landed)
}

coverage_comparable <- coverage(
  processed_by_year(wc_panel %>% filter(wc_comparable)),
  landings_by_year(pacfin_monthly %>% filter(MANAGEMENT_GROUP_CODE != "CRAB" | PACFIN_SPECIES_CODE == "DCRB"))
)
coverage_unfiltered <- coverage(processed_by_year(wc_panel), landings_by_year(pacfin_monthly))

write_csv(coverage_comparable, here("outputs", "table_coverage_by_fmp.csv"))
write_csv(coverage_unfiltered, here("outputs", "table_coverage_by_fmp_unfiltered.csv"))

print(coverage_comparable %>% mutate(across(where(is.double), ~ round(.x, 2))))
print(coverage_unfiltered %>% mutate(across(where(is.double), ~ round(.x, 2))))
