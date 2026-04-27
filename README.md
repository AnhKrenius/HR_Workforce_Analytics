# HR Workforce Analytics — End-to-End Data Pipeline

## The business problem (real numbers from 8,950 employees)

This project starts from three uncomfortable findings buried in HR data that
most dashboards don't surface — because they require transformation logic,
not just visualisation.

---

### Problem 1 — $19.6M walking out the door in year one

**57.2% of all terminated employees left within their first 12 months.**

That is 553 people. At an industry-standard replacement cost of 50% of annual
salary ($35,482 per head), this represents approximately **$19.6M in avoidable
spend** — money lost to recruitment, onboarding, and lost productivity that
reset to zero before the employee ever became effective.

HR had no early warning system. The only signal was a resignation email.

This project builds a tenure-aware risk model that flags new hires showing
early flight-risk indicators — so HR can run 30-day pulse surveys and
manager check-ins *before* losing the employee, not after.

---

### Problem 2 — Losing the best people fastest

**"Excellent" performers attrite at 14.9% — higher than "Good" performers (9.6%).**

The pay gap is the explanation: Excellent performers earn only **$6,367/year
more** than Needs Improvement employees. A top performer can get a 15–20%
uplift by switching employers. We are not paying enough to retain them.

In Finance and Sales, Excellent performer attrition exceeds **17%** —
meaning 1 in 6 of the best employees leaves every year.

This project builds a compensation positioning model that shows which high
performers are underpaid relative to their role median, with a recommended
action: *"Retention conversation — underpaid high performer."*

---

### Problem 3 — Systematic gender pay gap across 10 job titles

Within the same job title, male employees earn **7–14% more** than female
employees — not explained by tenure, performance, or education level.

Largest gaps:
- Marketing Manager: +13.9% (Male $104K vs Female $91K)
- Sales Representative: +13.0%
- Accounts Payable Specialist: +11.3%

In Australia, the Workplace Gender Equality Act requires pay equity reporting
for employers with 100+ employees. This data would fail that audit.

This project surfaces the gap at role level with an estimated annual cost
to close it — turning an invisible liability into a tractable HR action item.

---

## Data pipeline architecture

```
CSV export (HRIS)
    │
    ▼
BigQuery raw layer           hr_raw.employees
    │
    ▼
dbt staging                  stg_employees
    │  ├─ type casting + date parsing
    │  ├─ tenure_days, age_at_hire
    │  └─ is_early_leaver flag
    │
    ├──▶ int_salary_benchmarks
    │       ├─ median salary per role + education
    │       ├─ gender pay gap % per title
    │       └─ pay_equity_flag
    │
    ├──▶ int_attrition_risk
    │       ├─ 4-component risk score (0–100)
    │       ├─ risk_tier: critical / high / medium / low
    │       └─ recommended_action (plain English)
    │
    └──▶ Marts (Power BI ready)
            ├─ mart_hr_executive_summary    (dept-level, overview page)
            └─ mart_attrition_risk_dashboard (employee-level, risk explorer)
```

## Tech stack

| Layer | Tool | Why |
|---|---|---|
| Warehouse | BigQuery (or Snowflake) | Scalable, SQL-native, BI connector built-in |
| Transformation | dbt Core | Version control, tests, lineage docs |
| Orchestration | dbt Cloud scheduler (or Cloud Functions) | Daily refresh |
| Visualisation | Power BI | Row-level security, existing dashboard extended |
| Language | SQL + Python | Risk scoring logic |

## dbt model DAG

```
stg_employees
    ├── int_salary_benchmarks
    │       └── mart_hr_executive_summary
    │       └── (analyses/business_problems.sql)
    └── int_attrition_risk
            ├── mart_hr_executive_summary
            └── mart_attrition_risk_dashboard
```

## Running this project

```bash
# Install dbt
pip install dbt-bigquery

# Run all models
dbt run

# Run tests
dbt test

# Generate and serve docs
dbt docs generate
dbt docs serve
```

## Key metrics surfaced

| Metric | Value | Source |
|---|---|---|
| Total employees | 8,950 | stg_employees |
| Active | 7,984 (89.2%) | stg_employees |
| Overall attrition | 10.8% | mart_hr_executive_summary |
| Early attrition (<12m) | 57.2% of terminations | int_attrition_risk |
| Estimated early attrition cost | ~$19.6M | analyses/business_problems |
| Excellent performer attrition | 14.9% | mart_hr_executive_summary |
| Underpaid active employees | 620 (7.8%) | int_attrition_risk |
| Highest gender pay gap | 13.9% (Marketing Manager) | int_salary_benchmarks |
| Highest-risk department | Finance (13.9% attrition) | mart_hr_executive_summary |
