# =============================================================================
# Composition of reported processed value across management groups
# =============================================================================
#
# PAPER:   §3.1 Composition of reported processed value; Figure 1 (A:
#          processed value, B: ex-vessel value of landings for context) and the
#          value-by-era table ("Table 2. Share of real value and reporting
#          plants per year by management plan and era").
#
# PURPOSE: How reported real (2023 $) processed value is split across the
#          eight management groups, each year (Figure 1A) and by era (table:
#          value per year, plants per year, products, and value share), next
#          to how the ex-vessel value of West Coast landings is split across
#          the same groups (Figure 1B).
#          Main versions use the West Coast-comparable subset (wc_comparable,
#          R/03); unfiltered versions, all products, go to the supplement.
#
#
# INPUTS:  data/confidential_wc_panel.rds - from R/03
#          data/A191RD3A086NBEA.csv       - GDP deflator, for ex-vessel value
#
# CONFIDENTIAL DATA (copy or symlink into data/; gitignored):
#          data/pacfin_tables_monthly.RDS - PacFIN ex-vessel revenue by
#            year, month, species and management group (WA/OR/CA shoreside)
#
# DISCLOSURE: Figure 1 shows shares only, which is safe for every group
#          (HMS and CPS fail the top-plant screen as value levels in many
#          years; see outputs/confidential/disclosure_screen_fmp_year.csv).
#
# OUTPUTS: outputs/table_value_by_fmp_era.csv            - comparable (main)
#          outputs/table_value_by_fmp_era_unfiltered.csv - all products
#          outputs/fig1_value_share_by_fmp.pdf/.png           - Figure 1
#          outputs/figS_value_share_by_fmp_unfiltered.pdf/.png - supplement
# =============================================================================


# Setup ----
library(tidyverse)
library(patchwork)
library(here)

source(here("R", "figure_style.R"))

wc_panel <- readRDS(here("data", "confidential_wc_panel.rds"))

fmp_names <- c(GRND = "Groundfish", SAMN = "Salmon", CPEL = "Coastal pelagics",
               HMSP = "Highly migratory", CRAB = "Dungeness crab", SRMP = "Shrimp",
               SHLL = "Shellfish (state)", OTHR = "Other / non-FMP")

fmp_levels <- c("Groundfish", "Salmon", "Highly migratory", "Dungeness crab",
                "Shrimp", "Coastal pelagics", "Shellfish (state)", "Other / non-FMP")

fmp_colors <- c("#2a78d6", "#eb6834", "#1baf7a", "#eda100",
                "#e87ba4", "#008300", "#8a63d2", "#9a9a94")
names(fmp_colors) <- fmp_levels

# Step 1: Value, plants and products by management group and era ----
# Per-year averages within each era; value share is of the era's total

value_by_era <- function(panel) {
  panel %>%
    filter(!is.na(era)) %>%
    group_by(fmp, fmp_name, era) %>%
    summarize(
      real_m_per_yr = sum(real, na.rm = TRUE) / 1e6 / n_distinct(year),
      plants_per_yr = n_distinct(paste(year, pp_idnum)) / n_distinct(year),
      products = n_distinct(pp_code),
      .groups = "drop"
    ) %>%
    group_by(era) %>%
    mutate(value_share = real_m_per_yr / sum(real_m_per_yr)) %>%
    ungroup()
}

value_by_era_comparable <- value_by_era(wc_panel %>% filter(wc_comparable))
value_by_era_unfiltered <- value_by_era(wc_panel)

write_csv(value_by_era_comparable, here("outputs", "table_value_by_fmp_era.csv"))
write_csv(value_by_era_unfiltered, here("outputs", "table_value_by_fmp_era_unfiltered.csv"))

# Value share (%) by management group and era, comparable then unfiltered
value_by_era_comparable %>%
  select(fmp_name, era, value_share) %>%
  mutate(value_share = round(100 * value_share)) %>%
  pivot_wider(names_from = era, values_from = value_share) %>%
  print(width = 120)

value_by_era_unfiltered %>%
  select(fmp_name, era, value_share) %>%
  mutate(value_share = round(100 * value_share)) %>%
  pivot_wider(names_from = era, values_from = value_share) %>%
  print(width = 120)

# Step 2: Ex-vessel value of landings by management group ----
# PacFIN WA/OR/CA shoreside revenue in 2023 dollars (same GDP deflator as the
# panel). Comparable frame: crab is Dungeness (DCRB) only, matching the
# Dungeness-only processing; the other groups need no landings filter.

deflator <- read_csv(here("data", "A191RD3A086NBEA.csv"), show_col_types = FALSE) %>%
  transmute(
    year = as.numeric(substr(observation_date, 1, 4)),
    deflator = A191RD3A086NBEA
  )

deflator_2023 <- deflator$deflator[deflator$year == 2023]

pacfin_monthly <- readRDS(here("data", "pacfin_tables_monthly.RDS")) %>%
  filter(PACFIN_YEAR >= 1993, PACFIN_YEAR <= 2023)

exvessel_by_year <- function(pacfin) {
  pacfin %>%
    group_by(year = PACFIN_YEAR, fmp = MANAGEMENT_GROUP_CODE) %>%
    summarize(exvessel = sum(TOTAL_EXVESSEL_REVENUE, na.rm = TRUE), .groups = "drop") %>%
    left_join(deflator, by = "year") %>%
    mutate(
      real = exvessel * deflator_2023 / deflator,
      fmp_name = unname(fmp_names[fmp])
    )
}

exvessel_comparable <- exvessel_by_year(pacfin_monthly %>%
                                          filter(MANAGEMENT_GROUP_CODE != "CRAB" | PACFIN_SPECIES_CODE == "DCRB"))
exvessel_unfiltered <- exvessel_by_year(pacfin_monthly)

# Ex-vessel value share (%) by management group, 1993-99 vs 2017-23, comparable
exvessel_comparable %>%
  mutate(era = if_else(year <= 1999, "1993-99", if_else(year >= 2017, "2017-23", NA))) %>%
  filter(!is.na(era)) %>%
  group_by(era, fmp_name) %>%
  summarize(real = sum(real), .groups = "drop") %>%
  group_by(era) %>%
  mutate(share = round(100 * real / sum(real))) %>%
  select(-real) %>%
  pivot_wider(names_from = era, values_from = share) %>%
  print()

# Step 3: Figure 1 - annual value share by management group ----
# A: processed value (Processed Products survey); B: ex-vessel value of
# landings (PacFIN). complete() fills group-years with no value as zero so the
# stacked areas sum to 100% in every year.

value_share_by_year <- function(value) {
  value %>%
    filter(year >= 1993, year <= 2023) %>%
    group_by(year, fmp_name) %>%
    summarize(real = sum(real, na.rm = TRUE), .groups = "drop") %>%
    complete(year, fmp_name, fill = list(real = 0)) %>%
    group_by(year) %>%
    mutate(share = real / sum(real)) %>%
    ungroup() %>%
    mutate(fmp_name = factor(fmp_name, levels = rev(fmp_levels)))
}

share_panel <- function(value, y_label) {
  ggplot(value_share_by_year(value), aes(year, share, fill = fmp_name)) +
    geom_area(color = "white", linewidth = 0.15) +
    scale_fill_manual(values = fmp_colors, breaks = fmp_levels) +
    scale_x_continuous(breaks = seq(1995, 2020, 5), expand = expansion(mult = 0.01)) +
    scale_y_continuous(labels = scales::percent, expand = expansion(mult = 0)) +
    labs(x = "Year", y = y_label, fill = NULL) +
    guides(fill = guide_legend(nrow = 2)) +
    theme_fishbull
}

fig1 <- share_panel(wc_panel %>% filter(wc_comparable), "Share of processed value") + labs(x = NULL) +
  share_panel(exvessel_comparable, "Share of ex-vessel value") +
  plot_layout(ncol = 1, guides = "collect") +
  plot_annotation(tag_levels = "A") &
  theme(legend.position = "bottom")

save_figure(fig1, "fig1_value_share_by_fmp", width = 6.5, height = 6.5)

# Supplement: all products and all crab landings, no origin filter
fig1_unfiltered <- share_panel(wc_panel, "Share of processed value") + labs(x = NULL) +
  share_panel(exvessel_unfiltered, "Share of ex-vessel value") +
  plot_layout(ncol = 1, guides = "collect") +
  plot_annotation(tag_levels = "A") &
  theme(legend.position = "bottom")

save_figure(fig1_unfiltered, "figS_value_share_by_fmp_unfiltered", width = 6.5, height = 6.5)
