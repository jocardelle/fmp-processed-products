# =============================================================================
# Crosswalk decisions and product classification — the data-cleaning workflow
# =============================================================================
#
# PURPOSE: The single data-cleaning workflow for the Processed Products / FMP
#          paper: every species and product assignment and drop decision behind
#          the analytical management groups and product forms (manuscript
#          §2.2; decisions summary = Appendix Table A1; audit record =
#          docs/CROSSWALK_AUDIT.md). Produces Supplementary Table S1.
#
# INPUTS (both non-confidential survey/PacFIN metadata, included in repo):
#          data/pp_names.csv - survey product codes and descriptions
#          data/sp_code.csv  - PacFIN species table (species -> management group)
#
# CONFIDENTIAL DATA: data/pp_processed.csv (plant-level quantities and values)
#          is NOT in this repository and never should be - it lives on the
#          project volume. If present locally, the validation report at the
#          end of this script uses it for coverage counts; otherwise those
#          checks are skipped and the crosswalk outputs are unaffected.
#
# DECISIONS ENCODED HERE (each documented in the notes column and the audit):
#   1. Species word extracted from the product description (first word, with
#      two-word fixes); hand-authored species -> PacFIN code table below.
#   2. fmp from PacFIN management_group_code (sp_code join) - analytical
#      groups, not legal FMP membership.
#   3. Description-level overrides (audit 2026-10-01): SHARK DOGFISH -> DSRK/
#      GRND; SEA URCHIN -> RURC; SEA CUCUMBER -> CSCU; MACKEREL ATLANTIC ->
#      OTHR; KING (= king whiting) -> OTHR; steelhead/trout kept OTHR
#      (rationale corrected 2026-10-05: out-of-region farmed product).
#   4. Business-type codes (brokers, cold storage, ...) -> NA (excluded);
#      they carry zero West Coast value 1993-2023.
#   5. Product form classified from GROUP_NAME keywords, rules in order,
#      first match wins; precedence revised 2026-10-05 after the Speir
#      cross-check (bait, roe, and whole-cooked rules precede cured/meat
#      keywords); residual = other/unclassified.
#
# SCOPE DROPS APPLIED DOWNSTREAM (documented here, executed in the analysis
#          pipeline on the project volume): WA/OR/CA plants only; analysis
#          years 1993-2023 (1989-92 frame break); unmatched fmp coalesced to
#          OTHR; at-sea processors excluded from spatial analyses only.
#
# OUTPUTS: outputs/species_fmp_crosswalk.csv  - species-level crosswalk
#          outputs/pp_names_with_fmp.csv      - product-level crosswalk
#          outputs/S1_product_fmp_crosswalk.csv - Supplementary Table S1
# =============================================================================


# Setup ----
library(tidyverse)
library(janitor)
library(here)

# Load source data ----
sp_code <- read_csv(here("data", "sp_code.csv")) %>%
  clean_names()

pp_names <- read_csv(here("data", "pp_names.csv")) %>%
  clean_names()

# Confidential; present only on the project volume, never in this repository.
pp_processed_path <- here("data", "pp_processed.csv")
has_pp_processed <- file.exists(pp_processed_path)
if (has_pp_processed) {
  pp_processed <- read_csv(pp_processed_path) %>%
    clean_names()
}

# Extract base species from pp_names ----
# The PP_DSCP field contains species + product form (e.g., "SALMON CHINOOK FILLET")
# We extract the first word as the base species

pp_names <- pp_names %>%
  mutate(
    pp_species = word(pp_dscp, 1),
    # Some entries have two-word species names
    pp_species_full = case_when(
      pp_species == "ATKA" ~ "ATKA MACKEREL",
      pp_species == "OCEAN" ~ "OCEAN PERCH",
      pp_species == "SEA" ~ word(pp_dscp, 1, 2),
      pp_species == "KING" ~ word(pp_dscp, 1, 2),
      pp_species == "YELLOW" ~ word(pp_dscp, 1, 2),
      pp_species == "STRIPED" ~ word(pp_dscp, 1, 2),
      pp_species == "WHITE" ~ word(pp_dscp, 1, 2),
      pp_species == "BLUE" ~ word(pp_dscp, 1, 2),
      pp_species == "ROCK" ~ word(pp_dscp, 1, 2),
      pp_species == "SAND" ~ word(pp_dscp, 1, 2),
      pp_species == "BIGEYE" ~ word(pp_dscp, 1, 2),
      pp_species == "ORANGE" ~ word(pp_dscp, 1, 2),
      pp_species == "PATAGONIAN" ~ word(pp_dscp, 1, 2),
      TRUE ~ pp_species
    )
  )

# Create complete species crosswalk table ----
# Maps pp_names species to PACFIN species codes and FMPs
# Categories:
#   - Pacific fishery species: mapped to specific PACFIN codes
#   - Non-Pacific species: mapped to OTHR
#   - Business/facility types: excluded (NA)

species_crosswalk <- tribble(
  ~pp_species, ~pacfin_species_code, ~notes,


  # === SALMON (SAMN FMP) ===
  "SALMON", "SAMN", "All salmon - maps to SAMN FMP",
  "KING", "OTHR", "KING WHITING = Atlantic kingcroaker, not salmon; every KING-prefixed product is king whiting (audit 2026-10-01)",

  # === GROUNDFISH (GRND FMP) ===
  "ROCKFISHES", "ROCK", "All rockfish",
  "SABLEFISH", "SABL", "Sablefish/black cod",
  "LINGCOD", "LCOD", "Lingcod",
  "FLOUNDERS", "FLAT", "All flatfish",
  "HALIBUT", "PHLB", "Pacific halibut (note: managed by IPHC, not PFMC)",
  "COD", "PCOD", "Pacific cod",
  "POLLOCK", "PLCK", "Walleye pollock",
  "TURBOT", "ARTH", "Arrowtooth flounder/turbot",
  "GRENADIER", "GRDR", "Grenadiers",
  "SKATES", "SKAT", "All skates",
  "HAKE", "PWHT", "Pacific whiting/hake",
  "GROUNDFISH", "GRND", "Unspecified groundfish",
  "SCULPINS", "SCLP", "Sculpins",
  "ATKA", "AMCK", "Atka mackerel - groundfish",
  "CAPELIN", "CPLN", "Capelin - groundfish",
  "IRISH", "RSCL", "Irish lord (red irish lord) - other groundfish",
  "SAND", "PDAB", "Sand dab (Pacific sanddab)",
  "ROCK", "ORCK", "Rock fish (other rockfish)",

  # === COASTAL PELAGICS (CPEL FMP) ===
  "ANCHOVY", "NANC", "Northern anchovy",
  "SARDINE", "PSDN", "Pacific sardine",
  "SQUID", "MSQD", "Market squid",
  "MACKEREL", "CMCK", "Chub mackerel (most common on West Coast)",
  "HERRING", "PHRG", "Pacific herring",
  "BONITO", "PBNT", "Pacific bonito",
  "SCADS", "JMCK", "Jack mackerel/scads - coastal pelagic",

  # === HIGHLY MIGRATORY SPECIES (HMSP FMP) ===
  "TUNA", "TUNA", "All tunas",
  "SWORDFISH", "SWRD", "Swordfish",
  "SHARK", "SHRK", "All sharks (HMS managed)",
  "MARLIN", "MRLN", "Striped marlin",
  "DOLPHINFISH", "DRDO", "Dorado/mahi-mahi",
  "WAHOO", "WHOO", "Wahoo (not HMS managed but often grouped)",
  "OPAH", "OPAH", "Opah/moonfish",
  "SPEARFISH", "SSPF", "Shortbill spearfish",
  "BIGEYE", "ETNA", "Bigeye tuna - HMS",
  "ESCOLAR", "HMSP", "Escolar - often caught with HMS",

  # === CRAB (CRAB - state managed) ===
  "CRAB", "CRAB", "All crab",

  # === SHRIMP (SRMP - state managed) ===
  "SHRIMP", "SRMP", "All shrimp",
  "CRAWFISH", "OSRM", "Crawfish/crayfish - other shrimp",
  "BRINE", "BSRM", "Brine shrimp - bait shrimp",

  # === SHELLFISH (SHLL - state managed) ===
  "ABALONE", "ABLN", "All abalone",
  "CLAMS", "CLAM", "All clams",
  "CLAM", "CLAM", "All clams",
  "OYSTERS", "OYST", "All oysters",
  "OYSTER", "OYST", "All oysters",
  "MUSSELS", "BMSL", "Blue/bay mussel",
  "SCALLOPS", "SCAL", "All scallops",
  "CONCH", "OMSK", "Other mollusks",
  "WHELKS", "OMSK", "Other mollusks",
  "PERIWINKLES", "OMSK", "Other mollusks",
  "BARNACLE", "SHLL", "Barnacles - shellfish",

  # === OTHER PACIFIC SPECIES (OTHR) ===
  "OCTOPUS", "OCTP", "Unspecified octopus",
  "EELS", "EELS", "Unspecified eels",
  "SMELT", "SMLT", "Unspecified smelt",
  "STURGEON", "STRG", "All sturgeon",
  "LOBSTER", "LOBS", "California spiny lobster",
  "SEA CUCUMBER", "CSCU", "California sea cucumber",
  "SEA URCHIN", "RURC", "Red sea urchin",
  "JELLYFISH", "UJEL", "Unspecified jellyfish",
  "SEAWEED", "OTHR", "Seaweed - other",
  "KELP", "OTHR", "Kelp - other",
  "SEA", "OTHR", "Sea-prefixed species (sea bass, sea trout, etc.)",
  "OCEAN", "POP", "Ocean perch (Pacific ocean perch)",
  "CUTTLEFISH", "OCTP", "Cuttlefish - similar to octopus",
  "WHITE", "OTHR", "White-prefixed species (white seabass, etc.)",
  "YELLOW", "OTHR", "Yellow-prefixed species",
  "STRIPED", "OTHR", "Striped-prefixed species (striped bass, etc.)",
  "BLUE", "OTHR", "Blue-prefixed species",
  "LUMPFISH", "OTHR", "Lumpfish - other",

  # === NON-PACIFIC / ATLANTIC SPECIES (map to OTHR) ===
  "CATFISH", "OTHR", "Not Pacific species",
  "HADDOCK", "OTHR", "Atlantic species",
  "ALEWIVES", "OTHR", "Atlantic species",
  "MENHADEN", "OTHR", "Atlantic species",
  "BLUEFISH", "OTHR", "Atlantic species",
  "CROAKER", "OCRK", "Other croaker",
  "DRUM", "OTHR", "Not common Pacific species",
  "CARP", "OTHR", "Freshwater species",
  "TROUT", "OTHR", "Kept OTHR (decision 2026-10-01; rationale corrected 2026-10-05): steelhead/rainbow products are predominantly out-of-region farmed raw material (Idaho land-based steelhead; no WC aquaculture at scale). Non-tribal wild sale prohibited since 1975; the small treaty-tribal wild component (only lawful wild source, PacFIN STLH=SAMN) dominated pre-2010 volumes but is immaterial and inseparable",
  "TILAPIA", "OTHR", "Aquaculture species",
  "SNAPPER", "OTHR", "Primarily tropical/Gulf species",
  "GROUPERS", "OTHR", "Primarily tropical/Gulf species",
  "POMPANO", "OTHR", "Atlantic/Gulf species",
  "MULLET", "OTHR", "Not primary Pacific commercial species",
  "SHAD", "SHAD", "Unspecified shad",
  "WHITEFISH", "OTHR", "Lake whitefish - freshwater",
  "COBIA", "OTHR", "Atlantic/Gulf species",
  "TILEFISH", "OTHR", "Not common Pacific species",
  "AMBERJACK", "OTHR", "Not common Pacific species",
  "YELLOWTAIL", "YLTL", "Yellowtail - other",
  "BARRACUDA", "CUDA", "Pacific barracuda",
  "BUTTERFISH", "PBTR", "Pacific butterfish",
  "ANGLERFISH", "OTHR", "Monkfish - primarily Atlantic",
  "WOLFFISH", "OTHR", "Atlantic species",
  "WRECKFISH", "OTHR", "Not Pacific species",
  "BALLYHOO", "OTHR", "Baitfish - Atlantic/tropical",
  "BARRAMUNDI", "OTHR", "Australian species - aquaculture",
  "BLOODWORMS", "OTHR", "Bait - not fish",
  "BLUERUNNER", "OTHR", "Atlantic species",
  "BOWFIN", "OTHR", "Freshwater species",
  "BUFFALOFISH", "OTHR", "Freshwater species",
  "BURBOT", "OTHR", "Freshwater species",
  "CHUBS", "OTHR", "Freshwater species",
  "CRAPPIE", "OTHR", "Freshwater species",
  "CREVALLE", "OTHR", "Atlantic jack species",
  "FLYINGFISH", "OTHR", "Tropical species",
  "GARFISH", "OTHR", "Not common commercial species",
  "GIZZARD", "OTHR", "Gizzard shad - freshwater",
  "GRUNTS", "OTHR", "Tropical/Gulf species",
  "HOKI", "OTHR", "New Zealand species",
  "JACK", "OTHR", "Various jack species",
  "KINGCLIP", "OTHR", "South African species",
  "LAUNCE", "OTHR", "Sand lance - baitfish",
  "MILKFISH", "OTHR", "Tropical aquaculture species",
  "MOONEYE", "OTHR", "Freshwater species",
  "NILE", "OTHR", "Nile perch - African species",
  "ORANGE", "OTHR", "Orange roughy - deep sea",
  "PADDLEFISH", "OTHR", "Freshwater species",
  "PANGASIUS", "OTHR", "Asian aquaculture species",
  "PATAGONIAN", "OTHR", "Patagonian toothfish - Southern Ocean",
  "PIKE", "OTHR", "Freshwater species",
  "POMFRET", "POMF", "Pacific pomfret",
  "SANDWORMS", "OTHR", "Bait - not fish",
  "SAUGER", "OTHR", "Freshwater species",
  "SHEEPHEAD", "SHPD", "California sheephead",
  "SHEEPSHEAD", "SHPD", "California sheephead",
  "SUCKERS", "OTHR", "Freshwater species",
  "TRIGGERFISH", "OTHR", "Tropical species",
  "TRIPLETAIL", "OTHR", "Atlantic/Gulf species",
  "TENPOUNDER", "OTHR", "Ladyfish/tenpounder - Atlantic species",
  "CUSK", "OTHR", "Atlantic species",
  "SPOT", "OTHR", "Atlantic species",
  "SCUP", "OTHR", "Atlantic species",
  "TAUTOG", "OTHR", "Atlantic species",
  "SEATROUT", "OTHR", "Atlantic/Gulf species",

  # === EXOTIC / NON-FISH (map to OTHR or NA) ===
  "ALLIGATOR", "OTHR", "Non-fish",
  "FROG", "OTHR", "Non-fish",
  "FROGS", "OTHR", "Non-fish",
  "TURTLES", "OTHR", "Non-fish",
  "SPONGES", "OTHR", "Non-fish",
  "HORSESHOE", "OTHR", "Horseshoe crab - not true crab",

  # === MISCELLANEOUS FISH ===
  "UNCL", "OTHR", "Unclassified fish",
  "FISH", "OTHR", "Unspecified fish",
  "OCEAN PERCH", "POP", "Pacific ocean perch",
  "ATKA MACKEREL", "AMCK", "Atka mackerel - groundfish",

  # === BUSINESS/FACILITY TYPES (exclude - not species) ===
  "AQUACULTURE", NA_character_, "Business type - exclude",
  "AUCTION", NA_character_, "Business type - exclude",
  "BROKER", NA_character_, "Business type - exclude",
  "BUYING", NA_character_, "Business type - exclude",
  "COLD", NA_character_, "Cold storage - exclude",
  "CUSTOM", NA_character_, "Custom processing - exclude",
  "DEPURATION", NA_character_, "Facility type - exclude",
  "DID", NA_character_, "Unknown - exclude",
  "EXPORTER", NA_character_, "Business type - exclude",
  "IMPORTER", NA_character_, "Business type - exclude",
  "PACKER-SHIPPER", NA_character_, "Business type - exclude",
  "SPORT", NA_character_, "Sport fishing - exclude",
  "SUPPLIER", NA_character_, "Business type - exclude",
  "TRANSPORTER", NA_character_, "Business type - exclude",
  "UNLOADING", NA_character_, "Facility type - exclude",
  "FUR", NA_character_, "Non-fish product - exclude"
  # (audit 2026-10-01: removed duplicate FISH/UNCL/SPONGES/HORSESHOE rows that
  #  conflicted with their OTHR entries above and produced 137 duplicated
  #  PP_CODE rows in the output; the OTHR mapping was already the effective one)
)

# Add remaining species found in pp_names not yet mapped ----
# Get unique species from pp_names
pp_species_list <- pp_names %>%
  distinct(pp_species) %>%
  pull(pp_species)

# Find unmapped species
mapped_species <- species_crosswalk$pp_species
unmapped <- setdiff(pp_species_list, mapped_species)

# Add unmapped species with OTHR default
if (length(unmapped) > 0) {
  unmapped_df <- tibble(
    pp_species = unmapped,
    pacfin_species_code = "OTHR",
    notes = "Auto-mapped to OTHR - review needed"
  )
  species_crosswalk <- bind_rows(species_crosswalk, unmapped_df)
}

# Join crosswalk with sp_code to get FMP ----
sp_code_unique <- sp_code %>%
  # Handle duplicate PACFIN codes (like SHRK, TUNA which appear multiple times)
  group_by(pacfin_species_code) %>%
  slice(1) %>%
  ungroup() %>%
  select(pacfin_species_code, species_common_name, management_group_code, complex)

species_crosswalk_full <- species_crosswalk %>%
  left_join(sp_code_unique, by = "pacfin_species_code") %>%
  rename(fmp = management_group_code)

# Create pp_names with FMP mapping ----
pp_names_with_fmp <- pp_names %>%
  left_join(
    species_crosswalk_full %>% select(pp_species, pacfin_species_code, fmp, notes),
    by = "pp_species"
  )

# Description-level overrides (audit 2026-10-01, fmp_processing/docs/CROSSWALK_AUDIT.md) ----
# The first-word join cannot distinguish these products; fix at the description
# level. fmp values are PacFIN's management_group_code from sp_code.csv:
# DSRK (spiny dogfish) = GRND; RURC (red sea urchin) = OTHR; CSCU = OTHR.
pp_names_with_fmp <- pp_names_with_fmp %>%
  mutate(
    is_override = (pp_species == "SHARK" & str_detect(pp_dscp, "DOGFISH")) |
      str_detect(pp_dscp, "^SEA URCHIN") |
      str_detect(pp_dscp, "^SEA CUCUMBER") |
      str_detect(pp_dscp, "^MACKEREL ATLANTIC"),
    pacfin_species_code = case_when(
      pp_species == "SHARK" & str_detect(pp_dscp, "DOGFISH") ~ "DSRK",
      str_detect(pp_dscp, "^SEA URCHIN")                     ~ "RURC",
      str_detect(pp_dscp, "^SEA CUCUMBER")                   ~ "CSCU",
      str_detect(pp_dscp, "^MACKEREL ATLANTIC")              ~ "OTHR",
      TRUE ~ pacfin_species_code
    ),
    fmp = case_when(
      pp_species == "SHARK" & str_detect(pp_dscp, "DOGFISH") ~ "GRND",
      str_detect(pp_dscp, "^SEA URCHIN")                     ~ "OTHR",
      str_detect(pp_dscp, "^SEA CUCUMBER")                   ~ "OTHR",
      str_detect(pp_dscp, "^MACKEREL ATLANTIC")              ~ "OTHR",
      TRUE ~ fmp
    ),
    notes = if_else(is_override,
                    paste0(coalesce(notes, ""), " [description-level override, audit 2026-10-01]"),
                    notes)
  ) %>%
  select(-is_override)

# Join to pp_processed (confidential; skipped when the file is absent) ----
if (has_pp_processed) {
  pp_processed_with_fmp <- pp_processed %>%
    left_join(
      pp_names_with_fmp %>%
        select(pp_code, pp_dscp, pp_species, pacfin_species_code, fmp) %>%
        distinct(pp_code, .keep_all = TRUE),
      by = "pp_code"
    )
}

# ============================================================
# VALIDATION CHECKS
# ============================================================

cat("\n========================================\n")
cat("PP SPECIES CROSSWALK VALIDATION REPORT\n")
cat("========================================\n\n")

# Check 1: Coverage of pp_names species ----
cat("1. SPECIES COVERAGE\n")
cat("-------------------\n")

total_pp_species <- n_distinct(pp_names$pp_species)
mapped_to_pacfin <- species_crosswalk_full %>%

  filter(!is.na(pacfin_species_code)) %>%
  nrow()
excluded_business <- species_crosswalk_full %>%
  filter(is.na(pacfin_species_code)) %>%
  nrow()

cat(sprintf("Total unique species in pp_names: %d\n", total_pp_species))
cat(sprintf("Mapped to PACFIN codes: %d\n", mapped_to_pacfin))
cat(sprintf("Excluded (business types): %d\n", excluded_business))
cat(sprintf("Coverage: %.1f%%\n\n", 100 * mapped_to_pacfin / total_pp_species))

# Check 2: FMP distribution ----
cat("2. FMP DISTRIBUTION\n")
cat("-------------------\n")

fmp_dist <- species_crosswalk_full %>%
  filter(!is.na(pacfin_species_code)) %>%
  count(fmp, sort = TRUE) %>%
  mutate(pct = round(100 * n / sum(n), 1))

print(fmp_dist, n = 20)
cat("\n")

# Checks 3-5 need the confidential pp_processed records; run them on the
# project volume where that file exists.
if (has_pp_processed) {
  # Check 3: Coverage of pp_processed records ----
  cat("3. PP_PROCESSED RECORD COVERAGE\n")
  cat("--------------------------------\n")

  total_records <- nrow(pp_processed_with_fmp)
  records_with_fmp <- pp_processed_with_fmp %>%
    filter(!is.na(fmp)) %>%
    nrow()
  records_no_fmp <- pp_processed_with_fmp %>%
    filter(is.na(fmp)) %>%
    nrow()
  records_no_pp_code_match <- pp_processed_with_fmp %>%
    filter(is.na(pp_dscp)) %>%
    nrow()

  cat(sprintf("Total records in pp_processed: %s\n", format(total_records, big.mark = ",")))
  cat(sprintf("Records with FMP assigned: %s (%.1f%%)\n",
              format(records_with_fmp, big.mark = ","),
              100 * records_with_fmp / total_records))
  cat(sprintf("Records without FMP: %s (%.1f%%)\n",
              format(records_no_fmp, big.mark = ","),
              100 * records_no_fmp / total_records))
  cat(sprintf("Records with no PP_CODE match in pp_names: %s\n\n",
              format(records_no_pp_code_match, big.mark = ",")))

  # Check 4: Value by FMP ----
  cat("4. DOLLAR VALUE BY FMP\n")
  cat("----------------------\n")

  value_by_fmp <- pp_processed_with_fmp %>%
    filter(!is.na(dollars)) %>%
    group_by(fmp) %>%
    summarise(
      total_dollars = sum(dollars, na.rm = TRUE),
      n_records = n(),
      .groups = "drop"
    ) %>%
    arrange(desc(total_dollars)) %>%
    mutate(
      pct_value = round(100 * total_dollars / sum(total_dollars), 1),
      total_dollars_fmt = scales::dollar(total_dollars)
    )

  print(value_by_fmp %>% select(fmp, total_dollars_fmt, n_records, pct_value), n = 15)
  cat("\n")

  # Check 5: Unmapped PP_CODEs with significant value ----
  cat("5. TOP UNMAPPED PP_CODES BY VALUE\n")
  cat("----------------------------------\n")

  unmapped_codes <- pp_processed_with_fmp %>%
    filter(is.na(fmp) | is.na(pp_dscp)) %>%
    group_by(pp_code) %>%
    summarise(
      total_dollars = sum(dollars, na.rm = TRUE),
      n_records = n(),
      .groups = "drop"
    ) %>%
    arrange(desc(total_dollars)) %>%
    head(20)

  # Try to get descriptions for these codes
  unmapped_with_desc <- unmapped_codes %>%
    left_join(pp_names %>% select(pp_code, pp_dscp) %>% distinct(), by = "pp_code")

  print(unmapped_with_desc, n = 20)
  cat("\n")
} else {
  cat("3-5. RECORD-LEVEL CHECKS SKIPPED (confidential pp_processed.csv not present)\n\n")
}

# Check 6: Species mapping to unexpected FMPs ----
cat("6. SPECIES-FMP MAPPING REVIEW\n")
cat("-----------------------------\n")
cat("West Coast relevant FMPs: GRND, CPEL, HMSP, SAMN, CRAB, SRMP, SHLL\n\n")

wc_fmps <- c("GRND", "CPEL", "HMSP", "SAMN", "CRAB", "SRMP", "SHLL", "OTHR")

non_wc_species <- species_crosswalk_full %>%
  filter(!is.na(fmp), !fmp %in% wc_fmps)

if (nrow(non_wc_species) > 0) {
  cat("Species mapped to non-standard FMPs:\n")
  print(non_wc_species %>% select(pp_species, pacfin_species_code, fmp))
} else {
  cat("All species mapped to standard West Coast FMPs.\n")
}
cat("\n")

# Check 7: Auto-mapped species needing review ----
cat("7. AUTO-MAPPED SPECIES (NEED REVIEW)\n")
cat("------------------------------------\n")

auto_mapped <- species_crosswalk_full %>%
  filter(str_detect(notes, "Auto-mapped"))

if (nrow(auto_mapped) > 0) {
  print(auto_mapped %>% select(pp_species, pacfin_species_code, fmp, notes), n = 30)
} else {
  cat("No auto-mapped species.\n")
}
cat("\n")

# Save outputs ----
cat("========================================\n")
cat("SAVING OUTPUTS\n")
cat("========================================\n\n")

# Save crosswalk table
write_csv(species_crosswalk_full, here("outputs", "species_fmp_crosswalk.csv"))
cat("Saved: outputs/species_fmp_crosswalk.csv\n")

# Save pp_names with FMP
write_csv(pp_names_with_fmp, here("outputs", "pp_names_with_fmp.csv"))
cat("Saved: outputs/pp_names_with_fmp.csv\n")

# (pp_processed_with_fmp.csv not written here: large and unused by this
# project; csvi_production writes its own copy for CSVI purposes.)

cat("\nCrosswalk complete!\n")

# ============================================================
# PRODUCT FORMS + SUPPLEMENTARY TABLE S1 (absorbed from R/29)
# ============================================================
# Product-form classifier — the single definition for this project (R/01
# carries an identical inline copy for its pipeline; keep in sync).
classify_form <- function(g) {
  g <- toupper(coalesce(g, ""))
  case_when(
    str_detect(g, "\\(CAN\\)|CANNED") ~ "canned",
    # Speir cross-check adoptions (Connor, 2026-10-05): bait outranks salted/
    # pickled; roe outranks salted/smoked; whole-cooked outranks COOKED.
    str_detect(g, "BAIT") ~ "meal, oil, bait, pet food",
    str_detect(g, "ROE|CAVIAR|MILT") ~ "roe",
    str_detect(g, "SMOKED|KIPPERED|SALTED|DRIED|PICKLED|CURED") ~ "smoked / cured",
    str_detect(g, "SURIMI|MINCED|BLOCKS|ANALOG|STICKS|PORTIONS|BREADED|CAKES|PATTIES|NUGGETS|DINNERS|SPECIALT|COCKTAIL|SAUCE|STUFFED|SOUP|CHOWDER|SALAD|DIPS|SPREADS|BALLS|RINGS") ~ "further processed",
    str_detect(g, "MEAL|OIL|FERTILIZ|FEED|PET FOOD|INDUSTRIAL|SOLUBLES") ~ "meal, oil, bait, pet food",
    str_detect(g, "COOKED WHOLE|WHOLE COOKED") ~ "whole / live",
    str_detect(g, "FILLET|STEAK|LOIN|WINGS") ~ "fillet / steak",
    str_detect(g, "MEAT|PEELED|SHUCKED|SECTIONS|LEGS|CLAWS|TAILS|COOKED") ~ "meat, peeled, shucked, sections",
    str_detect(g, "DRESSED|HEADLESS|H&G|HEADED|GUTTED") ~ "dressed / headed and gutted",
    str_detect(g, "WHOLE|ROUND|LIVE|IN SHELL|HALF SHELL|FRESH|FROZEN") ~ "whole / live",
    TRUE ~ "other / unclassified"
  )
}

s1 <- pp_names_with_fmp %>%
  mutate(fmp = coalesce(fmp, "OTHR"),
         product_form = classify_form(group_name),
         fmp_name = recode(fmp, GRND = "Groundfish", SAMN = "Salmon",
                           CPEL = "Coastal pelagics", HMSP = "Highly migratory",
                           CRAB = "Dungeness crab", SRMP = "Shrimp",
                           SHLL = "Shellfish (state)", OTHR = "Other / non-FMP")) %>%
  select(product_code = pp_code, product_description = pp_dscp,
         species_word = pp_species, species_full = pp_species_full,
         pacfin_species_code, management_group = fmp,
         management_group_name = fmp_name, product_form, mapping_notes = notes) %>%
  arrange(management_group, species_word, product_code)
write_csv(s1, here("outputs", "S1_product_fmp_crosswalk.csv"))
cat("Saved: outputs/S1_product_fmp_crosswalk.csv -", nrow(s1), "rows\n")
cat("Rows by management group / product form:\n")
print(count(s1, management_group_name, sort = TRUE))
print(count(s1, product_form, sort = TRUE), n = 10)

cat("\nCrosswalk + cleaning decisions workflow complete.\n")
