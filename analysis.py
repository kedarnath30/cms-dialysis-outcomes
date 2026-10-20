"""Catheter use vs. hospitalization and infection outcomes across U.S. dialysis facilities.
Source: CMS Dialysis Facility Care Compare, Listing by Facility (released 2026-06-16)."""
import duckdb, pandas as pd, numpy as np, statsmodels.formula.api as smf
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt

con = duckdb.connect(); con.execute(open("sql/analysis.sql").read())
df = con.execute("SELECT * FROM fac").df()

# --- cohort: adult in-center facilities with reportable outcome + process measures
m = df.dropna(subset=["shr", "pct_catheter", "pct_ktv_ok", "stations"]).copy()
m = m[(m.stations > 0)]
print(f"Analytic cohort: {len(m)} of {len(df)} facilities")

# --- catheter quartiles vs outcomes
m["catheter_quartile"] = pd.qcut(m.pct_catheter, 4, labels=["Q1 (lowest)", "Q2", "Q3", "Q4 (highest)"])
q = m.groupby("catheter_quartile", observed=True).agg(
    facilities=("ccn", "count"), catheter_range=("pct_catheter", lambda s: f"{s.min():.0f}-{s.max():.0f}%"),
    median_hosp_rate=("shr", "median"), median_sir=("sir", "median"),
    pct_hosp_worse=("hosp_cat", lambda s: round(100 * s.str.startswith("Worse").mean(), 1))).round(2)
q.to_csv("outputs/05_catheter_quartiles.csv"); print(q)

# --- multivariable OLS: hospitalization rate ~ catheter % + Kt/V adequacy + size + ownership
ols = smf.ols("shr ~ pct_catheter + pct_ktv_ok + np.log(stations) + C(profit_status) + C(operator)", data=m).fit(cov_type="HC1")
open("outputs/06_ols_hospitalization.txt", "w").write(ols.summary().as_text())
b, lo, hi = ols.params["pct_catheter"], *ols.conf_int().loc["pct_catheter"]
print(f"Each +10 pts catheter use -> {10*b:+.1f} hospital admissions per 100 patient-years (95% CI {10*lo:+.1f} to {10*hi:+.1f}), R2={ols.rsquared:.3f}")

# --- charts
fig, ax = plt.subplots(figsize=(7, 4))
ax.bar(q.index.astype(str), q.median_hosp_rate, color="#2b6cb0")
ax.set_title("Median hospitalization rate by long-term catheter quartile"); ax.set_ylabel("Admissions per 100 patient-years")
for i, v in enumerate(q.median_hosp_rate): ax.text(i, v + 1, f"{v:.0f}", ha="center")
plt.tight_layout(); plt.savefig("charts/hosp_by_catheter_quartile.png", dpi=150)

op = pd.read_csv("outputs/02_outcomes_by_operator.csv")
fig, ax = plt.subplots(figsize=(7, 4))
ax.barh(op.operator, op.avg_star, color="#2f855a"); ax.set_xlabel("Average CMS star rating (1-5)")
ax.set_title("Average star rating by operator"); plt.tight_layout(); plt.savefig("charts/stars_by_operator.png", dpi=150)

with open("outputs/key_numbers.txt", "w") as f:
    f.write(f"cohort={len(m)}\nbeta10={10*b:.1f}\nci={10*lo:.1f},{10*hi:.1f}\nr2={ols.rsquared:.3f}\np={ols.pvalues['pct_catheter']:.2g}\n")
