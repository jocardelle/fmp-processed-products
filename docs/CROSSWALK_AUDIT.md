# Crosswalk audit — species → PacFIN code → FMP

Audited 2026-10-01 (Connor's request, after the KING WHITING find). Scope: every
`pp_species` word in `data/pp_names_with_fmp.csv`, valued at WA/OR/CA plants,
1993–2023, in 2023 dollars (GDP implicit price deflator). Built by
`R/28_crosswalk_audit.R` → `output/T28_crosswalk_audit_species.csv` (full table,
one row per species word, with n_codes / n_plants / real $M / share / sample
descriptions). The crosswalk itself is **unchanged** — fixes go through
`csvi_production/R/processing/pp_species_crosswalk.R` after Connor/Josephine
sign off below.

Reference standard: PacFIN's own `management_group_code` in
`csvi_production/pp_data/sp_code.csv`, since §2.2 states we follow PacFIN's
classification.

## Verdict in one paragraph

The crosswalk is sound where the money is: the top eight species words
(salmon, pollock, tuna, shrimp, crab, unclassified, hake, cod — 82% of WC real
value) are all correctly assigned, king/snow crab lands in CRAB as intended,
and halibut/white seabass/herring/kelp match PacFIN's own groupings. True
misassignments total ≈ 0.02% of WC value. The material items are **judgment
calls inside Other/non-FMP** (steelhead $426M, urchin roe $1.14B, snapper
$59M) plus one presentation gap: the draft's description of what Other/non-FMP
holds misses its two biggest components.

## 1. True misassignments (vs PacFIN's classification) — small

| Products | Now | Should be | WC real 1993–2023 | Fix |
| --- | --- | --- | --- | --- |
| SHARK DOGFISH … (2 codes) | SHRK → HMSP | DSRK → **GRND** (PacFIN: spiny dogfish is groundfish) | ≈ $19M (0.02%) | needs description-level split: only DOGFISH rows move; other SHARK stays HMSP |
| KING WHITING … (7 codes) | CHNK → SAMN | Atlantic kingcroaker → OTHR | 1 WC plant, immaterial (matters only nationally: $74M nominal) | map `KING` → OTHR, or key on `pp_species_full` |
| MACKEREL ATLANTIC SALTED | CMCK → CPEL | OTHR | ≈ $0 | cosmetic |

## 2. Judgment calls — need a documented decision (both readings defensible)

| Item | WC real | Currently | The call |
| --- | --- | --- | --- |
| **TROUT STEELHEAD** products | **$426M** (0.5%) | OTHR ("freshwater species") | PacFIN STLH → **SAMN** — the build script's own note says so. But processed "steelhead" is overwhelmingly farmed steelhead trout (aquaculture), for which OTHR is right; wild steelhead sales are essentially tribal-only. Recommend: **keep OTHR**, add a note to the crosswalk, and (optionally) a §2.2 footnote. |
| **SEA URCHINS ROE** | **$1.14B** (1.3%) | OTHR via `SEA` catch-all | **Consistent with PacFIN** (RURC group = OTHR, not SHLL), so no error — but a reader may expect urchins under state shellfish. Recommend: keep PacFIN convention; **name urchin roe in §2.2's description of Other/non-FMP**. (The build script's `SEA URCHIN → RURC` row is dead — see §4 — but fixing it wouldn't change the FMP.) |
| **SNAPPER UNCL FILLET** | $59M (0.07%) | OTHR | Could be imported tropical snapper (OTHR, right) or Pacific rockfish marketed as "snapper" (would be GRND). Not resolvable from the description. Recommend: leave OTHR, list as a crosswalk limitation. |

## 3. Presentation finding for §2.2 (no reassignment needed)

Other/non-FMP ≈ 15.6% of WC real value. Its actual composition, largest first:
UNCL (unclassified fish) $7.9B — **dominated by UNCL FISH FOR PET FOOD $3.85B
(4.3% of all WC value)** — then halibut $2.6B, SEA (urchin roe $1.14B + white
seabass $113M + sea cucumber ~$60M), kelp $502M (3 plants), trout/steelhead
$500M, sturgeon $247M, tilapia $223M, catfish $120M, lobster $117M. The §2.2
draft currently says "halibut, sturgeon, unclassified"; it should name pet-food
production and urchin roe, which outweigh sturgeon by an order of magnitude.

## 4. Structural warts (no practical effect; clean up at next rebuild)

- **137 duplicate PP_CODE rows** in `pp_names_with_fmp.csv` with conflicting
  `{OTHR, NA}` fmp — caused by FISH, UNCL, SPONGES, HORSESHOE each appearing
  twice in the build tribble (once mapped OTHR, once excluded NA).
  `01_fmp_panel_tables.R` takes `distinct(PP_CODE)` (OTHR row first) and
  coalesces NA → OTHR anyway, so both paths land identically.
- **Dead two-word keys** in the build tribble: `SEA URCHIN`, `SEA CUCUMBER`,
  `OCEAN PERCH`, `ATKA MACKEREL` can never match because the join key is the
  first word only (`pp_species`, not `pp_species_full`). OCEAN and ATKA have
  working first-word entries; the SEA pair silently falls to the `SEA → OTHR`
  catch-all (same FMP outcome, lost species detail).
- Excluded business types (154 NA rows: BROKER, COLD storage, …) carry **zero
  WC value 1993–2023** — the exclusion is moot for this paper.
- Every WC record 1993–2023 matches a `pp_names` row; no orphan PP codes.

## 5. Verified-correct spot checks

CRAB includes "CRAB SNOW/KING …" descriptions → CRAB ✓ (Alaska-origin caveat
already in §2.2 text). HALIBUT → PHLB → OTHR per PacFIN (IPHC) ✓. SEA BASS
WHITE → OTHR (PacFIN WBAS = OTHR) ✓. HERRING SEA (incl. $133M salted roe) →
CPEL per PacFIN ✓. SQUID → MSQD → CPEL ✓. HAKE → PWHT → GRND ✓. KELP
(dried/industrial) → OTHR ✓. COD/POLLOCK → GRND ✓ (Alaska-origin caveat
covers the scope question).

## Sign-off

Connor approved all recommendations 2026-10-01 ("Those calls look good").
Implemented same day — rebuilt via `csvi_production/R/processing/
pp_species_crosswalk.R`, pre-rebuild files preserved in
`csvi_production/pp_data/archive_pre_audit_20261001/` and
`data/pp_names_with_fmp.pre_audit_20261001.csv`:

- [x] SHARK DOGFISH → DSRK/GRND (description-level override)
- [x] KING → OTHR (Atlantic kingcroaker)
- [x] Steelhead: kept OTHR. Rationale corrected 2026-10-05 after Connor challenged
      the "aquaculture" framing: there is **no WC steelhead aquaculture at scale** —
      the farmed product is out-of-region (Idaho land-based, ~20M+ lbs/yr industry;
      Riverence/Clear Springs). Data shows two regimes: pre-2010 ≈ 0.2M lbs/yr,
      tribal wild (Taholah/Quinault — 1 plant, stays on the volume); post-2010
      5–6.6M lbs/yr at one Columbia River-area plant, scale only consistent with
      farmed supply (non-tribal wild sale prohibited since 1975; tribal Zone 6
      harvests ≤ ~1M lbs/yr). Sources: Riverence/Clear Springs press (2020),
      WDFW/ODFW joint staff reports, CRITFC Zone 6.
- [x] Urchin roe: kept OTHR per PacFIN; species detail restored (SEA URCHIN →
      RURC, SEA CUCUMBER → CSCU via overrides); named in §2.2
- [x] MACKEREL ATLANTIC → OTHR (cosmetic)
- [x] Duplicate FISH/UNCL/SPONGES/HORSESHOE tribble rows removed (file now
      2,184 rows, zero conflicting PP codes)
- [x] §2.2 Other/non-FMP description updated (pet food, urchin roe)
- [x] Shareable supplement exported: `R/29_crosswalk_supplement.R` →
      `output/S1_product_fmp_crosswalk.csv` (public metadata + notes only)

Post-rebuild audit (`R/28_crosswalk_audit.R` rerun 2026-10-01): zero duplicate
codes; KING, SHARK DOGFISH, SEA URCHIN/CUCUMBER, MACKEREL ATLANTIC all verified
in their decided groups. Effect on paper numbers: dogfish ≈ $19M moves HMS →
Groundfish (< 0.03 pp of any share); nothing else moves at WC plants.
`csvi_production` note: its `pp_data` crosswalk files were regenerated with
these corrections; any CSVI rerun will pick them up (effect similarly tiny).

**Form-classifier revision 2026-10-05** (Connor approved adopting the Speir
cross-check findings): three precedence fixes in `classify_form()` (canonical
in `R/00_crosswalk_decisions.R`, synced copy in `R/01`): (1) BAIT outranks
salted/pickled; (2) ROE/CAVIAR/MILT outranks salted/smoked; (3) COOKED
WHOLE/WHOLE COOKED outranks the COOKED meat keyword. Motivated by a 91.8%-
agreement comparison against C. Speir's independent manual map
(`~/Downloads/ussd_pp_map (1).csv`, US Seafood Dashboard). 47 codes moved;
WC nominal value at stake: cooked-whole shellfish → whole/live $1.08B,
salted roe → roe $209M, salted bait → bait $8M. Material T2/Fig 2 changes:
Dungeness crab whole/live 0 → 28/22/10/12% by era (meat down equally);
CPS 1993–99 smoked 29 → 2% with roe 0 → 27% (herring salted roe now
classified as roe); salmon roe 1 → 6%. §3.2 manuscript prose describing crab
("meat nearly all") and early CPS ("smoked/cured highest shares") must be
revised to match. Pre-fix outputs preserved in `output_pre_formfix_20261005/`.

**Pipeline rerun 2026-10-01** (with the GDP-deflator switch applied in
`R/01_fmp_panel_tables.R`; CPI-era outputs snapshotted in
`output_pre_gdp_20261001/`): all 8 P1 scripts ran clean. Verified against the
snapshot — T1 max share change 0.083 pp; T2 max form-share change 0.30 pp
(dogfish reclass); T5 coverage ratios ≤ 0.013 change; disclosure screen counts
move by ≤ 2 plants (HMS → GRND, all cells stay ≥ 3 plants). One plant's
dominant FMP flipped HMS → Groundfish, changing two quoted draft numbers:
§3.3 peak-to-trough 1.88 → 1.86 (groundfish) and 1.05 → 1.04 (HMS).
The override refactor (two parallel `case_when()`s replacing the packed-string
form) was verified byte-identical on `pp_names_with_fmp.csv` before the rerun.
