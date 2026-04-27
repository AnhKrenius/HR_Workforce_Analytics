-- ═══════════════════════════════════════════════════════════════════════════
-- PROBLEM 2: WE'RE LOSING OUR BEST PEOPLE FASTER THAN OUR WORST
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Finding: "Excellent" performers attrite at 14.9% — higher than "Good" (9.6%).
-- "Needs Improvement" attrition is 18.3% (managed/PIP exits — expected).
-- But losing 1 in 7 Excellent performers to voluntary resignation is a crisis.
--
-- The pay gap explains it:
--   Excellent performer avg salary: $73,993
--   Needs Improvement avg salary:   $67,626
--   Gap: only $6,367/year (~9%)
--
-- A top performer can get 15-20% uplift by switching companies.
-- We're not paying enough to retain them.
--
-- Worst departments for Excellent attrition:
--   Finance: 17.7% of Excellent performers left
--   Sales:   17.5% of Excellent performers left
--   IT:      16.5% of Excellent performers left
--
-- Business question this answers:
--   "Are we retaining our high performers? If not, what is it costing us
--    and is compensation the lever we need to pull?"

select
    department,
    performance_rating,
    countif(is_active)                           as active_count,
    countif(not is_active)                       as terminated_count,
    count(*)                                     as total,
    round(
        countif(not is_active) / count(*) * 100, 1
    )                                            as attrition_rate_pct,
    round(avg(salary), 0)                        as avg_salary

from {{ ref('stg_employees') }}
where performance_rating = 'Excellent'
group by department, performance_rating
order by attrition_rate_pct desc
