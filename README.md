# Dialysis Facility Outcomes Analysis (CMS Care Compare)

**Question:** Across U.S. dialysis facilities, is higher long-term catheter use associated with worse hospitalization outcomes, and which Texas facilities are flagged worse than expected on several outcome measures?

**Data:** CMS Dialysis Facility Care Compare, *Listing by Facility* (data.cms.gov, released 2026-06-16): 7,490 facilities, 142 fields. Public facility-level data; no patient-level or protected health information.

**Tools:** SQL (DuckDB), Python (pandas, statsmodels, matplotlib), Tableau-ready extract.

## Method
1. **Clean and standardize** (`sql/analysis.sql`): cast text fields to numeric, group chain names into operators, and profile how complete each measure is. Kt/V is reportable for only 56% of facilities; catheter use for 94%.
2. **Define the analysis cohort:** 4,136 facilities with a reportable hospitalization rate (SHR), catheter %, adult HD Kt/V ≥ 1.2 %, and station count.
3. **Descriptive comparison:** split facilities into catheter-use quartiles and compare median hospitalization rate, infection ratio (SIR), and the share CMS rates "Worse than Expected."
4. **Multivariable OLS regression** with heteroskedasticity-robust (HC1) standard errors: hospitalization rate ~ catheter % + Kt/V adequacy + log(stations) + profit status + operator.
5. **Texas watch list:** facilities CMS rates "Worse than Expected" on 2 or more of survival, hospitalization, readmission, and infection.

## Findings (leadership summary)
- **Catheter use tracks with hospitalizations.** Median hospitalization rate rises steadily from **132.6** admissions per 100 patient-years in the lowest catheter quartile (0–13%) to **148.8** in the highest (26–95%). The share rated "Worse than Expected" roughly triples, from 2.4% to 7.1%.
- **The pattern holds after adjustment.** Each 10-point increase in catheter use goes with **+5.2 admissions per 100 patient-years** (95% CI +3.8 to +6.6, p < 0.001), controlling for Kt/V adequacy, facility size, ownership, and operator. The model explains a small share of variation (R² = 0.075), so catheter use is one signal among many, not the main driver.
- **Infection ratio doesn't separate by catheter quartile** at the facility level (median SIR 0.26–0.28 in every quartile). That's worth a closer look with patient-level data before drawing conclusions.
- **Texas:** 9 facilities are rated worse than expected on 2+ outcome measures, mostly on hospitalization and readmission together. That makes them a reasonable starting list for a quality-improvement review.
- **Operators:** U.S. Renal Care (3.06), DaVita (2.99), and American Renal (2.96) have the highest average star ratings; independents average 2.27.

## Limitations
Facility-level, cross-sectional, observational data, so these results are associations, not causes. CMS outcome measures are already risk-adjusted standardized ratios. Measurement windows differ by measure (2021–2025). Facilities with suppressed or small-sample measures are excluded from the regression.

## Files
- `sql/analysis.sql`: cleaning, data-quality profile, operator and state summaries, Texas watch list
- `analysis.py`: cohort, quartile analysis, OLS model, charts
- `outputs/`: result tables, model summary, `tableau_extract.csv` for a Tableau Public dashboard
- `charts/`: PNG charts

Run: `pip install duckdb pandas statsmodels matplotlib` and then `python analysis.py`. The CSV goes in `data/`.
