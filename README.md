# fmp-processed-products

Data-cleaning workflow for the NMFS Processed Products / West Coast FMP
processing paper, in two scripts:

1. the species → PacFIN code → management group crosswalk and the
   product-form classification, with every assignment and drop decision
   documented. Produces Supplementary Table S1.
2. origin and market context tags on top of that crosswalk, for separating
   product lines whose raw material is clearly West Coast from Alaska,
   imported, and import-competing product.

## Pipeline

| Script | What it does |
| --- | --- |
| `R/01_crosswalk_decisions.R` | Builds the species crosswalk (hand-authored lookup joined to PacFIN's management-group classification), applies description-level overrides, classifies product forms, writes the outputs, and prints a validation report |
| `R/02_product_context.R` | Adds origin and market tags to the crosswalk from 01: Alaska-leaning groundfish species, canned HMS, trade exposure class (e.g. breaded shrimp = import-competing), the 19 focal product lines, and squid-only / Dungeness-only series. Tags only, drops nothing. Prints a validation check for each tag |

Run in order from the repo root (paths resolve with `here::here()`); 02 reads
the outputs of 01:

```r
source(here::here("R", "01_crosswalk_decisions.R"))
source(here::here("R", "02_product_context.R"))
```

## Why the context tags exist

A plant's state in the survey is its reporting address, not where its fish
was caught. Seattle-addressed firms report Alaska pollock, cod and king crab;
California canneries pack imported tuna; peeled and breaded shrimp compete
with imports. The tags in `02_product_context.R` let each analysis filter on
the distinction it needs, e.g. `filter(!alaska_species_grnd)`.

Limits, also recorded in the script header:

- The Alaska groundfish tag uses species as an origin proxy, so Alaska fish
  of shared species (sablefish, rockfish, flatfish) stays untagged.
- Salmon cannot be split by origin; the same species come from both.
- Not-canned HMS still contains imports.
- At-sea processors (coded to WA) are a plant-level drop, applied downstream
  on the project volume where plant addresses live, not a product tag.

The rules are carried over unchanged from the analysis scripts on the project
volume: `processor_cluster/fmp_processing/R/30_spatial_concentration.R` and
`processor_cluster/trade_exposure/R/explore_trade_exposure.R`.

## Data sources

| File | Source | Confidential? |
| --- | --- | --- |
| `data/pp_names.csv` | NMFS Processed Products survey — product codes, descriptions, group names (survey metadata) | No |
| `data/sp_code.csv` | PacFIN species table — species → `management_group_code` | No |
| `data/pp_processed.csv` | Plant-level quantities and values | **Yes — never in this repo.** Lives on the project volume. If present locally, `01_crosswalk_decisions.R` runs record-level validation checks; otherwise it skips them and the crosswalk outputs are unaffected. `02_product_context.R` does not use it |

## Outputs

| File | Script | What it is |
| --- | --- | --- |
| `outputs/pp_names_with_fmp.csv` | 01 | Product-level crosswalk: code → species → PacFIN code → management group, with a notes column recording each judgment call |
| `outputs/species_fmp_crosswalk.csv` | 01 | Species-level lookup with notes |
| `outputs/S1_product_fmp_crosswalk.csv` | 01 | Supplementary Table S1 — the shareable, citation-ready version (adds product form and management-group names) |
| `outputs/product_context_flags.csv` | 02 | One row per product code: description, group name, management group, product form, and the tags `alaska_species_grnd`, `hms_canned`, `trade_exposure`, `focal_line`, `single_species` |

## Docs

- `docs/CROSSWALK_AUDIT.md` — audit record for the crosswalk decisions in 01
