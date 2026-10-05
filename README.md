# fmp-processed-products

Data-cleaning workflow for the NMFS Processed Products / West Coast FMP
processing paper: the species → PacFIN code → management group crosswalk and
the product-form classification, with every assignment and drop decision
documented in one script. Produces Supplementary Table S1.

## Pipeline

| Script | What it does |
| --- | --- |
| `R/01_crosswalk_decisions.R` | Builds the species crosswalk (hand-authored lookup joined to PacFIN's management-group classification), applies description-level overrides, classifies product forms, writes the outputs, and prints a validation report |

Run from the repo root (paths resolve with `here::here()`):

```r
source(here::here("R", "01_crosswalk_decisions.R"))
```

## Data sources

| File | Source | Confidential? |
| --- | --- | --- |
| `data/pp_names.csv` | NMFS Processed Products survey — product codes, descriptions, group names (survey metadata) | No |
| `data/sp_code.csv` | PacFIN species table — species → `management_group_code` | No |
| `data/pp_processed.csv` | Plant-level quantities and values | **Yes — never in this repo.** Lives on the project volume. If present locally, the script runs record-level validation checks; otherwise it skips them and the crosswalk outputs are unaffected |

## Outputs

| File | What it is |
| --- | --- |
| `outputs/pp_names_with_fmp.csv` | Product-level crosswalk: code → species → PacFIN code → management group, with a notes column recording each judgment call |
| `outputs/species_fmp_crosswalk.csv` | Species-level lookup with notes |
| `outputs/S1_product_fmp_crosswalk.csv` | Supplementary Table S1 — the shareable, citation-ready version (adds product form and group names) |

