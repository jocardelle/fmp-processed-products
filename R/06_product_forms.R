# =============================================================================
# Product forms within management groups
# =============================================================================
#
# PAPER:   §3.2 product forms (section currently headed "Sensitivity to the
#          reporting frame" in the draft); Figure 2.
#
# PURPOSE: The share of each management group's real processed value in each
#          of the product forms defined in R/01 (S1), by year (Figure 2) and
#          by era (table). Other / non-FMP is left out. Main versions use the
#          West Coast-comparable subset (wc_comparable, R/03), which removes
#          canned HMS and breaded shrimp by construction; unfiltered versions,
#          all products, go to the supplement and carry the canning story.
#
# FIX (2026-11-09): the original Figure 2 stacked above 100% wherever a
#          form had no value in a year (geom_area interpolates across the
#          missing row). Form-years are now completed with zeros. The era
#          table is unaffected.
#
# INPUTS:  data/confidential_wc_panel.rds - from R/03
#
# OUTPUTS: outputs/confidential/table_product_form_by_fmp_era.csv - comparable
#          outputs/confidential/table_product_form_by_fmp_era_unfiltered.csv
#            (both carry n_plants per form cell; gitignored)
#          outputs/fig2_product_form_by_fmp.pdf/.png            - Figure 2
#          outputs/figS_product_form_by_fmp_unfiltered.pdf/.png - supplement
# =============================================================================


# Setup ----
library(tidyverse)
library(here)

source(here("R", "figure_style.R"))

wc_panel <- readRDS(here("data", "confidential_wc_panel.rds"))

fmp_levels <- c("Groundfish", "Salmon", "Highly migratory", "Dungeness crab",
                "Shrimp", "Coastal pelagics", "Shellfish (state)", "Other / non-FMP")

form_levels <- c("whole / live", "dressed / headed and gutted", "fillet / steak",
                 "meat, peeled, shucked, sections", "canned", "smoked / cured",
                 "further processed", "roe", "meal, oil, bait, pet food",
                 "other / unclassified")

form_colors <- c("#cde2fb", "#86b6ef", "#2a78d6", "#1c5cab", "#eb6834",
                 "#eda100", "#1baf7a", "#e87ba4", "#9a9a94", "#dddddd")
names(form_colors) <- form_levels

# Step 1: Product-form shares by management group and era ----

form_by_era <- function(panel) {
  panel %>%
    filter(!is.na(era), fmp != "OTHR") %>%
    group_by(fmp, fmp_name, era, form) %>%
    summarize(
      v = sum(real, na.rm = TRUE),
      n_plants = n_distinct(pp_idnum),
      .groups = "drop"
    ) %>%
    group_by(fmp, era) %>%
    mutate(share = v / sum(v)) %>%
    ungroup() %>%
    select(-v)
}

form_by_era_comparable <- form_by_era(wc_panel %>% filter(wc_comparable))
form_by_era_unfiltered <- form_by_era(wc_panel)

write_csv(form_by_era_comparable, here("outputs", "confidential", "table_product_form_by_fmp_era.csv"))
write_csv(form_by_era_unfiltered, here("outputs", "confidential", "table_product_form_by_fmp_era_unfiltered.csv"))

# Product-form share (%), 1993-99 vs 2017-23, comparable
form_by_era_comparable %>%
  filter(era %in% c("1993-99", "2017-23")) %>%
  mutate(share = round(100 * share)) %>%
  select(fmp_name, era, form, share) %>%
  pivot_wider(names_from = form, values_from = share, values_fill = 0) %>%
  arrange(fmp_name, era) %>%
  print(width = 200)

# Step 2: Figure 2 - annual product-form shares, one panel per management group ----
# complete() fills form-years with no value as zero so each panel sums to 100%

form_share_by_year <- function(panel) {
  panel %>%
    filter(year >= 1993, year <= 2023, fmp != "OTHR") %>%
    group_by(year, fmp_name, form) %>%
    summarize(real = sum(real, na.rm = TRUE), .groups = "drop") %>%
    complete(year, fmp_name, form, fill = list(real = 0)) %>%
    group_by(year, fmp_name) %>%
    mutate(share = real / sum(real)) %>%
    ungroup() %>%
    mutate(
      fmp_name = factor(fmp_name, levels = fmp_levels),
      form = factor(form, levels = rev(form_levels))
    )
}

fig2 <- ggplot(form_share_by_year(wc_panel %>% filter(wc_comparable)),
               aes(year, share, fill = form)) +
  geom_area(color = "white", linewidth = 0.1) +
  facet_wrap(~fmp_name, ncol = 2) +
  scale_fill_manual(values = form_colors, breaks = form_levels) +
  scale_x_continuous(breaks = seq(1995, 2020, 5), expand = expansion(mult = 0.01)) +
  scale_y_continuous(labels = scales::percent, expand = expansion(mult = 0)) +
  labs(x = "Year", y = "Share of processed value", fill = NULL) +
  guides(fill = guide_legend(ncol = 3)) +
  theme_fishbull

save_figure(fig2, "fig2_product_form_by_fmp", width = 6.5, height = 8)

# Supplement: all products, no origin filter
fig2_unfiltered <- fig2 + form_share_by_year(wc_panel)

save_figure(fig2_unfiltered, "figS_product_form_by_fmp_unfiltered", width = 6.5, height = 8)
