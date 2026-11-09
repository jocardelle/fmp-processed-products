# fmp-processed-products

Code for the West Coast processing paper ("P1 FMP working draft"): the NMFS
Processed Products survey mapped to West Coast management groups, and every
table and figure in the draft built from it. Scripts are numbered in run
order, which also follows the paper's order.

Figure 4 and the portfolio results in §3.4 are Josephine's and are produced
by her code, not this repo.

## Paper map

| Paper element | Section | Script | Output |
| --- | --- | --- | --- |
| Table 1 — management groups, product-code counts | §2.2 | `01_crosswalk_decisions.R` | `outputs/table1_management_groups.csv` |
| Supplementary Table S1 — product crosswalk | §2.2 | `01_crosswalk_decisions.R` | `outputs/S1_product_fmp_crosswalk.csv` |
| Origin tags (Alaska groundfish, canned HMS, trade exposure, ...) | §2.5 | `02_product_context.R` | `outputs/product_context_flags.csv` |
| West Coast panel, 2023 dollars, disclosure screen | §2.1, §2.3 | `03_build_panel.R` | `data/confidential_wc_panel.rds` |
| Coverage table (draft "Table 2" in §2.4) | §2.4 | `04_coverage.R` | `outputs/table_coverage_by_fmp.csv` (supplement: `_unfiltered`) |
| Figure 1 — A: processed value share, B: ex-vessel value share of landings, by management group | §3.1 | `05_value_composition.R` | `outputs/fig1_value_share_by_fmp.png` (supplement: `figS_value_share_by_fmp_unfiltered.png`) |
| Value share and plants by era (draft "Table 2" in §3.1) | §3.1 | `05_value_composition.R` | `outputs/table_value_by_fmp_era.csv` (supplement: `_unfiltered`) |
| Figure 2 — product form by management group | §3.2 | `06_product_forms.R` | `outputs/fig2_product_form_by_fmp.png` (supplement: `figS_product_form_by_fmp_unfiltered.png`) |
| Figure 3 — landings vs employment seasonality | §3.3 | `07_seasonality.R` | `outputs/fig3_landings_vs_employment.png` (supplement: `figS_landings_vs_employment_unfiltered.png`) |
| Seasonality table ("Table X" in §3.3) | §3.3 | `07_seasonality.R` | `outputs/confidential/table_seasonality_employment.csv`, `outputs/table_seasonality_landings.csv` |
| Figure X — spatial concentration, filtered | §2.5, §3.7 | `08_spatial_theil.R` | `outputs/figX_theil_main_filtered.png` |
| Figure X+1 — groundfish by origin | §3.7 | `08_spatial_theil.R` | `outputs/figX1_theil_grnd_origin_split.png` |
| Supplement — Theil unfiltered; fixed-panel versions | §2.5, §3.7 | `08_spatial_theil.R` | `outputs/figSX_theil_*.png` |
| Figure 4, §3.4 portfolio tables | §3.4 | Josephine's code | — |

**Main vs supplement.** Every main-text figure and table uses the West
Coast-comparable products (`wc_comparable`, set in 03): groundfish without
Alaska-leaning species, HMS without canned, crab Dungeness only, shrimp
without further processed (breaded); salmon, coastal pelagics, shellfish and
Other are unfiltered. Each script also writes an `_unfiltered` version with
all products for the supplement, the same pattern as the Theil figures.

**Figure style.** `R/figure_style.R` holds one Fishery Bulletin theme
(Helvetica labels, no bold or titles inside the figure, multipart panels
lettered A, B in bold Times, 6.5 in wide or less) and writes every figure
twice: `.pdf` for submission and a 600 dpi `.png` for the working draft.
Scripts 05–08 source it. Captions go in the manuscript.

Figure and table numbers in the draft are still moving (two tables are both
"Table 2"), so output files are named by content, with the figure number
where it is settled.

## Pipeline

| Script | What it does |
| --- | --- |
| `R/01_crosswalk_decisions.R` | Builds the species crosswalk (hand-authored lookup joined to PacFIN's management-group classification), applies description-level overrides, classifies product forms, writes S1 and Table 1, and prints a validation report |
| `R/02_product_context.R` | Adds origin and market tags to the crosswalk: Alaska-leaning groundfish species, canned HMS, trade exposure class (e.g. breaded shrimp = import-competing), the 19 focal product lines, and squid-only / Dungeness-only series. Tags only, drops nothing |
| `R/03_build_panel.R` | Keeps every record from a WA/OR/CA plant, attaches management group, product form and tags, converts to constant 2023 dollars (GDP deflator), and flags the West Coast-comparable subset (`wc_comparable`), and screens every management group-year for disclosure |
| `R/04_coverage.R` | Processed pounds and value over PacFIN landed pounds and ex-vessel value, by management group, 2010–2023 |
| `R/05_value_composition.R` | Real value share by management group, by year (Figure 1A) and era, next to the ex-vessel value share of West Coast landings (Figure 1B) |
| `R/06_product_forms.R` | Product-form shares within each management group, by year (Figure 2) and era |
| `R/07_seasonality.R` | Monthly employment profiles for plants with ≥ 50 % of value in one group vs monthly landings profiles (Figure 3) |
| `R/08_spatial_theil.R` | Normalized Theil index of processing vs landings across the 19 IOPAC port groups, by management group and year: unfiltered, filtered to each group's interpretable subset, groundfish by origin, squid and Dungeness single-species series, and the fixed-panel robustness check |

Run in order from the repo root (paths resolve with `here::here()`); each
script reads the outputs of the ones before it. 01 and 02 run on the
non-confidential files in this repo; 03–08 need the confidential files below.

```r
source(here::here("R", "01_crosswalk_decisions.R"))
source(here::here("R", "02_product_context.R"))
source(here::here("R", "03_build_panel.R"))
source(here::here("R", "04_coverage.R"))
source(here::here("R", "05_value_composition.R"))
source(here::here("R", "06_product_forms.R"))
source(here::here("R", "07_seasonality.R"))
source(here::here("R", "08_spatial_theil.R"))
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
- At-sea processors (coded to WA) are a plant-level drop, applied in the
  spatial analysis only, not a product tag.

## Data sources

| File | Source | Confidential? |
| --- | --- | --- |
| `data/pp_names.csv` | NMFS Processed Products survey — product codes, descriptions, group names (survey metadata) | No |
| `data/sp_code.csv` | PacFIN species table — species → `management_group_code` | No |
| `data/iopac_lt.csv` | PacFIN port → IOPAC port group lookup, from `theil_index_creation/data/raw/` | No |
| `data/A191RD3A086NBEA.csv` | GDP implicit price deflator (BEA via FRED, 2017 = 100), rebased to 2023 in 03 | No |
| `data/pp_processed.csv` | Plant-level quantities and values | **Yes.** Used by 01 (optional checks), 03, 08 |
| `data/pp_address_23.xlsx` | Plant addresses | **Yes.** Used by 03, 08 |
| `data/pp_employment.xlsx` | Monthly employment by plant | **Yes.** Used by 07 |
| `data/pacfin_dealer.duckdb` | PacFIN dealer landings (`dealer_species_year` table) | **Yes.** Used by 08 |
| `data/pacfin_tables_monthly.RDS` | PacFIN landings and ex-vessel revenue by year, month, species, port | **Yes.** Used by 04, 05, 07 |

The confidential files are never in this repo. They live on the project
volume — `processor_cluster/data/` (the first four) and `csvi_production/`
(`pacfin_tables_monthly.RDS`). To run 03–08, copy or symlink them into
`data/`; they are gitignored.

## Outputs

Anything carrying plant counts per cell or plant-level shares goes to
`outputs/confidential/`, which is gitignored, along with
`data/confidential_wc_panel.rds`. Any cell with fewer than three plants stays
on the project volume.

| File | Script | What it is |
| --- | --- | --- |
| `outputs/pp_names_with_fmp.csv` | 01 | Product-level crosswalk: code → species → PacFIN code → management group, with a notes column recording each judgment call |
| `outputs/species_fmp_crosswalk.csv` | 01 | Species-level lookup with notes |
| `outputs/S1_product_fmp_crosswalk.csv` | 01 | Supplementary Table S1 (adds product form and management-group names) |
| `outputs/table1_management_groups.csv` | 01 | Table 1 product-code counts by management group |
| `outputs/product_context_flags.csv` | 02 | One row per product code with the tags `alaska_species_grnd`, `hms_canned`, `trade_exposure`, `focal_line`, `single_species` |
| `outputs/confidential/disclosure_screen_fmp_year.csv` | 03 | Plants and top-plant share for every management group-year |
| `outputs/table_coverage_by_fmp.csv` | 04 | Coverage ratios and plants per year by management group, 2010–2023 means (comparable products; crab vs Dungeness landings) |
| `outputs/table_coverage_by_fmp_unfiltered.csv` | 04 | Same, all products and all crab landings |
| `outputs/table_value_by_fmp_era.csv` | 05 | Real value per year, plants per year, products and value share, by management group and era |
| `outputs/table_value_by_fmp_era_unfiltered.csv` | 05 | Same, all products |
| `outputs/fig1_value_share_by_fmp.png` | 05 | Figure 1 |
| `outputs/figS_value_share_by_fmp_unfiltered.png` | 05 | Supplement: Figure 1, all products |
| `outputs/confidential/table_product_form_by_fmp_era.csv` | 06 | Product-form shares by management group and era, with plants per cell |
| `outputs/confidential/table_product_form_by_fmp_era_unfiltered.csv` | 06 | Same, all products |
| `outputs/fig2_product_form_by_fmp.png` | 06 | Figure 2 |
| `outputs/figS_product_form_by_fmp_unfiltered.png` | 06 | Supplement: Figure 2, all products |
| `outputs/confidential/employment_profile_by_main_fmp.csv` | 07 | Monthly employment profile by dominant management group |
| `outputs/confidential/table_seasonality_employment.csv` | 07 | Employment peak, trough and amplitude by dominant group |
| `outputs/landings_profile_by_fmp.csv` | 07 | Monthly landings profile by management group, 2010–2022 |
| `outputs/table_seasonality_landings.csv` | 07 | Landings peak, trough and amplitude by management group |
| `outputs/fig3_landings_vs_employment.png` | 07 | Figure 3 |
| `outputs/figS_landings_vs_employment_unfiltered.png` | 07 | Supplement: Figure 3, all products; each 07 table also has an `_unfiltered` copy |
| `outputs/theil_by_fmp_year.csv` | 08 | Theil of processing and landings, all products |
| `outputs/theil_comparable_by_fmp_year.csv` | 08 | Theil with each group's origin filter applied (Figure X) |
| `outputs/theil_grnd_origin_split.csv` | 08 | Groundfish Theil: all, WC species, Alaska-leaning species, landings |
| `outputs/theil_single_species.csv` | 08 | Squid-only and Dungeness-only Theil, processing and landings |
| `outputs/theil_by_fmp_year_fixed_panel.csv` | 08 | Robustness: unfiltered series on the fixed panel (≥ 20 of 31 years) |
| `outputs/theil_comparable_by_fmp_year_fixed_panel.csv` | 08 | Robustness: filtered series on the fixed panel |
| `outputs/theil_fixed_panel_era_change.csv` | 08 | Processing Theil, 1993–99 vs 2017–23, all plants vs fixed panel |
| `outputs/confidential/theil_grnd_origin_shares.csv` | 08 | Groundfish pounds, Puget Sound share and plants by era and origin |
| `outputs/confidential/theil_hms_form_split.csv` | 08 | HMS canned vs not canned: pounds, Los Angeles share, plants |
| `outputs/figX_theil_main_filtered.png` | 08 | Figure X (main) |
| `outputs/figX1_theil_grnd_origin_split.png` | 08 | Figure X+1 |
| `outputs/figSX_theil_unfiltered.png` | 08 | Supplement: unfiltered |
| `outputs/figSX_theil_filtered_fixed_panel.png` | 08 | Supplement: filtered, fixed panel |
| `outputs/figSX_theil_unfiltered_fixed_panel.png` | 08 | Supplement: unfiltered, fixed panel |

## Provenance

Scripts 03–08 were moved from `processor_cluster/fmp_processing/R/` on the
project volume. The unfiltered outputs reproduce the originals (verified
2026-11-09: every table identical; figures built from identical data). The
West Coast-comparable main versions are new. Figure 2 differs from the
original by one fix: form-years with no value are filled with zero, so the
stacked areas no longer exceed 100%.

| Here | Was |
| --- | --- |
| `03_build_panel.R` | `01_fmp_panel_tables.R` §1, §2, D |
| `04_coverage.R` | `01_fmp_panel_tables.R` T5 |
| `05_value_composition.R` | `01_fmp_panel_tables.R` T1; `02_p1_figures.R` Figure 1 |
| `06_product_forms.R` | `01_fmp_panel_tables.R` T2; `02_p1_figures.R` Figure 2 |
| `07_seasonality.R` | `01_fmp_panel_tables.R` T3; `06_fig3_landings_seasonality.R` |
| `08_spatial_theil.R` | `30_spatial_concentration.R` (plus the fixed-panel check) |

## Docs

- `docs/CROSSWALK_AUDIT.md` — audit record for the crosswalk decisions in 01
