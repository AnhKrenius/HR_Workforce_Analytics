-- ═══════════════════════════════════════════════════════════════════════════
-- PROBLEM 1: THE EARLY ATTRITION HAEMORRHAGE
-- ═══════════════════════════════════════════════════════════════════════════
-- 
-- Finding: 57.2% of all terminated employees left within their first 12 months.
-- That is 553 people out of 966 total terminations.
--
-- Cost implication (industry benchmark: ~50% annual salary per replacement):
--   Avg salary: $70,964
--   Cost per early leaver: $35,482
--   Total estimated cost: $19.6 MILLION in avoidable churn
--
-- Worst departments:
--   Operations: 167 early leavers
--   Sales: 107 early leavers
--   Customer Service: 107 early leavers
--
-- HR does not track this. There is no early warning dashboard.
-- By the time someone resigns in month 8, HR is already $35K in the hole.
--
-- Business question this answers:
--   "Where are we losing the most money in the first year of employment,
--    and what can we change in onboarding to stop it?"

select
    department,
    count(*)                                     as total_terminated,
    countif(months_to_termination < 12)          as early_leavers,
    round(
        countif(months_to_termination < 12)
        / count(*) * 100, 1
    )                                            as early_leaver_pct,
    round(
        countif(months_to_termination < 12) * 35482
        / 1e6, 2
    )                                            as estimated_cost_million_usd

from {{ ref('stg_employees') }}
where is_active = false
group by department
order by early_leavers desc