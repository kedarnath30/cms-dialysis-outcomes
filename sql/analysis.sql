-- CMS Dialysis Facility Care Compare (Listing by Facility, released 2026-06-16)
-- Run with DuckDB:  duckdb < sql/analysis.sql

CREATE OR REPLACE TABLE fac AS
SELECT
  "CMS Certification Number (CCN)"                     AS ccn,
  "Facility Name"                                      AS facility,
  "State"                                              AS state,
  "City/Town"                                          AS city,
  "Profit or Non-Profit"                               AS profit_status,
  CASE WHEN "Chain Organization" ILIKE '%DAVITA%' THEN 'DaVita'
       WHEN "Chain Organization" ILIKE '%FRESENIUS%' THEN 'Fresenius'
       WHEN "Chain Organization" ILIKE '%U.S. RENAL%' OR "Chain Organization" ILIKE '%US RENAL%' THEN 'U.S. Renal Care'
       WHEN "Chain Organization" ILIKE '%AMERICAN RENAL%' THEN 'American Renal'
       WHEN "Chain Owned" = 'No' THEN 'Independent'
       ELSE 'Other chain' END                          AS operator,
  TRY_CAST("# of Dialysis Stations" AS INT)            AS stations,
  TRY_CAST("Five Star" AS INT)                         AS five_star,
  "Patient Survival Category Text"                     AS survival_cat,
  "Patient hospitalization category text"              AS hosp_cat,
  "Patient Hospital Readmission Category"              AS readmit_cat,
  "Patient Infection category text"                    AS infection_cat,
  TRY_CAST("Mortality Rate (Facility)" AS DOUBLE)      AS smr,
  TRY_CAST("Hospitalization Rate (Facility)" AS DOUBLE) AS shr,
  TRY_CAST("Readmission Rate (Facility)" AS DOUBLE)    AS srr,
  TRY_CAST("Standard Infection Ratio" AS DOUBLE)       AS sir,
  TRY_CAST("Percent of Adult HD patients with Kt/V >= 1.2" AS DOUBLE)        AS pct_ktv_ok,
  TRY_CAST("Percentage of Adult patients with long term catheter in use" AS DOUBLE) AS pct_catheter,
  TRY_CAST("Percentage of Adult patients with hypercalcemia (serum calcium greater than 10.2 mg/dL)" AS DOUBLE) AS pct_hypercal
FROM read_csv_auto('data/DFC_FACILITY.csv', all_varchar=true);

-- 1. Data quality: how much of each measure is reportable
COPY (
SELECT COUNT(*) AS facilities,
       ROUND(100.0*COUNT(five_star)/COUNT(*),1)   AS pct_with_star,
       ROUND(100.0*COUNT(shr)/COUNT(*),1)         AS pct_with_hosp_rate,
       ROUND(100.0*COUNT(sir)/COUNT(*),1)         AS pct_with_sir,
       ROUND(100.0*COUNT(pct_catheter)/COUNT(*),1) AS pct_with_catheter,
       ROUND(100.0*COUNT(pct_ktv_ok)/COUNT(*),1)  AS pct_with_ktv
FROM fac) TO 'outputs/01_data_completeness.csv' (HEADER);

-- 2. Outcomes by operator
COPY (
SELECT operator, COUNT(*) AS facilities,
       ROUND(AVG(five_star),2)   AS avg_star,
       ROUND(MEDIAN(shr),1)      AS median_hosp_rate,
       ROUND(MEDIAN(srr),1)      AS median_readmit_rate,
       ROUND(MEDIAN(sir),2)      AS median_infection_ratio,
       ROUND(MEDIAN(pct_catheter),1) AS median_pct_catheter,
       ROUND(100.0*AVG(CASE WHEN hosp_cat ILIKE 'Worse%' THEN 1 ELSE 0 END),1) AS pct_hosp_worse_than_expected
FROM fac GROUP BY operator ORDER BY facilities DESC) TO 'outputs/02_outcomes_by_operator.csv' (HEADER);

-- 3. Texas facilities flagged "Worse than Expected" on 2+ outcome measures (watch list)
COPY (
SELECT * FROM (
SELECT ccn, facility, city, operator, five_star,
       (CASE WHEN survival_cat  ILIKE 'Worse%' THEN 1 ELSE 0 END +
        CASE WHEN hosp_cat      ILIKE 'Worse%' THEN 1 ELSE 0 END +
        CASE WHEN readmit_cat   ILIKE 'Worse%' THEN 1 ELSE 0 END +
        CASE WHEN infection_cat ILIKE 'Worse%' THEN 1 ELSE 0 END) AS measures_worse,
       survival_cat, hosp_cat, readmit_cat, infection_cat
FROM fac WHERE state='TX'
) WHERE measures_worse >= 2
ORDER BY measures_worse DESC, facility) TO 'outputs/03_tx_watchlist.csv' (HEADER);

-- 4. Star rating distribution by state (top 10 states by facility count)
COPY (
WITH s AS (SELECT state, COUNT(*) n FROM fac GROUP BY state ORDER BY n DESC LIMIT 10)
SELECT f.state, s.n AS facilities, ROUND(AVG(five_star),2) AS avg_star,
       ROUND(100.0*AVG(CASE WHEN five_star<=2 THEN 1 ELSE 0 END),1) AS pct_1_2_star
FROM fac f JOIN s USING(state) WHERE five_star IS NOT NULL
GROUP BY f.state, s.n ORDER BY avg_star) TO 'outputs/04_stars_by_state.csv' (HEADER);

-- 5. Tableau-ready extract
COPY (SELECT * FROM fac) TO 'outputs/tableau_extract.csv' (HEADER);
