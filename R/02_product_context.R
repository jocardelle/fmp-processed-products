# =============================================================================
# Product context — origin and market tags on top of the FMP crosswalk
# =============================================================================
#
# PURPOSE: "West Coast" in the Processed Products survey is the plant's
#          reporting address, not where the fish was caught. Seattle-addressed
#          firms report Alaska pollock and cod; California canneries pack
#          imported tuna; breaded shrimp competes with imports. This script
#          adds the tags used to separate those product lines from the ones
#          whose raw material is clearly West Coast. Nothing is dropped here -
#          every product keeps its row, and each analysis filters on the tags
#          it needs.
#
# INPUTS:  outputs/S1_product_fmp_crosswalk.csv - from R/01_crosswalk_decisions.R
#          outputs/pp_names_with_fmp.csv        - from R/01 (for group_name)
#
#
# TAGS ADDED:
#   1. alaska_species_grnd - groundfish species that are Alaska-leaning
#      (pollock, cod, Atka mackerel, turbot, grenadier, capelin). Species
#      identity is the origin proxy.
#   2. hms_canned - canned HMS product (the tuna canning complex, built on
#      imported / Pacific-wide raw material, not the WC troll fishery).
#   3. trade_exposure - import-competing (canned; fresh/frozen, e.g. peeled
#      and breaded shrimp), export-oriented, domestic fresh, or
#      "other / Alaska / unclassified".
#   4. focal_line - the 19 product lines followed individually in the trade
#      paper (WC-origin raw material or the main import-competing products).
#   5. single_species - squid-only (CPS) and Dungeness-only (crab) series.
#
# CAVEATS:
#   - The Alaska proxy is one-directional: Alaska fish of shared species
#     (sablefish, rockfish, flatfish) stays untagged, so it understates the
#     Alaska share.
#   - Salmon cannot be split - the same species come from both origins.
#   - Not-canned HMS still contains imports.
#   - At-sea processors (coded to WA) are a plant-level drop, not a product
#     tag; that is applied downstream on the project volume, where plant
#     addresses live.
#
# OUTPUTS: outputs/product_context_flags.csv - one row per product code
# =============================================================================


# Setup ----
library(tidyverse)
library(here)

# Load the crosswalk from 01 ----
s1 <- read_csv(here("outputs", "S1_product_fmp_crosswalk.csv"),
               show_col_types = FALSE)

group_names <- read_csv(here("outputs", "pp_names_with_fmp.csv"),
                        show_col_types = FALSE) %>%
  select(product_code = pp_code, group_name)

products <- s1 %>%
  left_join(group_names, by = "product_code") %>%
  select(product_code, product_description, group_name, species_word,
         management_group, product_form)

# Step 1: Alaska-leaning groundfish ----
# Groundfish species that, on the West Coast, are mostly Alaska product
# reported by Seattle-addressed firms.

ak_species <- c("POLLOCK", "COD", "ATKA", "TURBOT", "GRENADIER", "CAPELIN")

products <- products %>%
  mutate(
    alaska_species_grnd = management_group == "GRND" & species_word %in% ak_species
  )

# Step 2: HMS canning complex ----
# Canned HMS is the tuna canning complex; its raw material is largely
# foreign or Pacific-wide, not the West Coast troll fishery.

products <- products %>%
  mutate(
    hms_canned = management_group == "HMSP" & product_form == "canned"
  )

# Step 3: Trade exposure class ----
# Classified from the survey's group name. Rules run in order, first match
# wins. Breaded and peeled shrimp, shucked oysters, salmon fillet and fish
# sticks compete with imports; anything unmatched falls to
# "other / Alaska / unclassified".

products <- products %>%
  mutate(
    g = coalesce(group_name, ""),
    trade_exposure = case_when(
      str_detect(g, "TUNA.*[(]CAN[)]|PET FOOD|MACKEREL [(]CAN[)]|SARDINE.*[(]CAN[)]") ~ "import-competing: canned",
      str_detect(g, "^SHRIMP (PEELED|BREADED|HEADLESS)|^OYSTERS SHUCKED|^CLAMS SHUCKED|^SALMON FILLET|^SURIMI ANALOG|UNCL FISH BREADED|FISH STICKS") ~ "import-competing: fresh/frozen",
      str_detect(g, "^HAKE|^SQUID|^SEA URCHIN|^SABLEFISH|^SARDINE PACIFIC|ROE$|^SALMON.*ROE|^HERRING") ~ "export-oriented",
      str_detect(g, "^CRAB DUNGENESS|^SALMON (SMOKED|DRESSED|STEAKS)|^ROCKFISH|^SOLE|^FLOUNDER|^HALIBUT|^LINGCOD|^OYSTERS (IN SHELL|LIVE)|^CLAMS|^MUSSEL|^GEODUCK") ~ "domestic fresh",
      TRUE ~ "other / Alaska / unclassified"
    )
  ) %>%
  select(-g)

# Step 4: Focal product lines ----
# Lines followed individually: raw material is unambiguously West Coast, or
# the line is one of the main import-competing products.

focal_lines <- c(
  "SHRIMP PEELED COOKED MEAT", "SHRIMP BREADED MEAT", "TUNA ALBACORE SOLID (CAN)",
  "OYSTERS SHUCKED MEAT", "SALMON FILLET", "SURIMI ANALOG",
  "SEA URCHINS ROE", "HAKE SURIMI", "HAKE DRESSED", "HAKE FILLET", "SQUID WHOLE", "SQUID MEAT", "SABLEFISH DRESSED",
  "CRAB DUNGENESS COOKED WHOLE", "CRAB DUNGENESS COOKED SECTIONS", "CRAB DUNGENESS COOKED MEAT",
  "SALMON SMOKED OR KIPPERED", "SALMON DRESSED", "ROCKFISHES FILLET"
)

products <- products %>%
  mutate(
    focal_line = group_name %in% focal_lines
  )

# Step 5: Single-species series ----
# Robustness series that drop the mixed parts of two FMPs: squid only for
# coastal pelagics, Dungeness only for crab (CRAB also holds king and snow
# crab product).

products <- products %>%
  mutate(
    single_species = case_when(
      management_group == "CPEL" & species_word == "SQUID"                  ~ "squid only",
      management_group == "CRAB" & str_detect(product_description, "DUNGENESS") ~ "dungeness only",
      TRUE ~ NA_character_
    )
  )

# ============================================================
# VALIDATION CHECKS
# ============================================================

# Check 1: Alaska-leaning groundfish products ----
products %>%
  filter(alaska_species_grnd) %>%
  count(species_word) %>%
  print()

# Check 2: HMS products, canned vs not ----
products %>%
  filter(management_group == "HMSP") %>%
  count(hms_canned) %>%
  print()

# Check 3: Trade exposure classes ----
products %>%
  count(trade_exposure, sort = TRUE) %>%
  print()

# Check 4: Focal lines missing from pp_names group names (should be empty) ----
print(setdiff(focal_lines, products$group_name))

# Check 5: Single-species series ----
products %>%
  filter(management_group %in% c("CPEL", "CRAB")) %>%
  count(management_group, single_species) %>%
  print()

# Save outputs ----
write_csv(products, here("outputs", "product_context_flags.csv"))
