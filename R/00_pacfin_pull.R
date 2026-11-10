# =============================================================================
# PacFIN landings pull — monthly ex-vessel revenue and landed weight
# =============================================================================
#
# PURPOSE: Pulls PacFIN fish tickets (pacfin_marts.comprehensive_ft) aggregated
#          to year x month x species x management group x port, 1981-2025, and
#          saves them as data/pacfin_tables_monthly.RDS for 04, 05 and 07.
#          Rows with missing ex-vessel revenue or landed weight are excluded
#          in the SQL.
#
#
# REQUIRES: An ODBC DSN named "PACFIN" and a PacFIN account; the password is
#          prompted at run time and never stored. Run interactively.
#
# INPUTS:  PacFIN database (live query)
#
# OUTPUTS: data/pacfin_tables_monthly.RDS - CONFIDENTIAL, gitignored. Re-running
#          overwrites the existing file and pulls current PacFIN data, which
#          can differ from the Jan 2026 pull the results were built on; back
#          up the existing file first.
#
# =============================================================================

# Load libraries ----
library(RODBC)
library(here)

# Connect to PacFIN ----
pswd <- readline("Input Password: ")
channel_pacfin <- odbcConnect("PACFIN", uid = "CLEWISSMITH", pwd = pswd)
rm(pswd)

# Query monthly revenue and weight by species and port ----
query <- "
SELECT
  PACFIN_YEAR,
  EXTRACT(MONTH FROM LANDING_DATE) AS MONTH,
  PACFIN_SPECIES_CODE,
  MANAGEMENT_GROUP_CODE,
  PORT_CODE,
  PACFIN_PORT_CODE,
  IOPAC_PORT_GROUP,
  SUM(EXVESSEL_REVENUE) AS TOTAL_EXVESSEL_REVENUE,
  SUM(LANDED_WEIGHT_MTONS) AS TOTAL_LANDED_WEIGHT_MTONS
FROM
  pacfin_marts.comprehensive_ft
WHERE
  PACFIN_YEAR >= 1981 AND PACFIN_YEAR <= 2025
  AND EXVESSEL_REVENUE IS NOT NULL
  AND LANDED_WEIGHT_MTONS IS NOT NULL
GROUP BY
  PACFIN_YEAR,
  EXTRACT(MONTH FROM LANDING_DATE),
  PACFIN_SPECIES_CODE,
  MANAGEMENT_GROUP_CODE,
  PORT_CODE,
  PACFIN_PORT_CODE,
  IOPAC_PORT_GROUP
"
result_spatial <- sqlQuery(channel_pacfin, query)

# Save ----
saveRDS(result_spatial, here("data", "pacfin_tables_monthly.RDS"))

odbcClose(channel_pacfin)
