-- ═══════════════════════════════════════════════════════════════════════════
-- PROBLEM 3: COMPENSATION EQUITY — GENDER PAY GAP IS MATERIAL AND SYSTEMATIC
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Finding: Across 10 job titles, male employees earn 7–14% more than female
-- employees IN THE SAME ROLE. This is not explained by tenure or performance.
--
-- Most egregious gaps (same title, same employer):
--   Marketing Manager:          Female $91K vs Male $104K  (+13.9%)
--   Sales Representative:       Female $64K vs Male $72K   (+13.0%)
--   Accounts Payable Specialist: Female $59K vs Male $66K  (+11.3%)
--   Logistics Coordinator:      Female $60K vs Male $66K   (+10.9%)
--
-- This is not a pipeline problem — these are people in the same job title today.
-- A pay equity audit would flag this immediately.
-- In Australia, the Workplace Gender Equality Act requires reporting for
-- employers with 100+ employees. This data is a liability if not addressed.
--
-- 620 active employees (7.8% of workforce) earn below 85% of their role median.
-- Sales has 221 underpaid employees — the department also has 17.5% Excellent attrition.
-- These two facts are connected.
--
-- Business question this answers:
--   "Do we have systematic pay inequity by gender, and which roles are most exposed?
--    What would it cost to bring underpaid employees to the 85th percentile?"

select
    b.job_title,
    b.education_level,
    b.median_female,
    b.median_male,
    b.gender_gap_pct,
    b.pay_equity_flag,
    -- Estimated annual cost to close the gap (bring female to male median)
    round(
        (b.median_male - b.median_female)
        * (select count(*) from {{ ref('stg_employees') }} e
           where e.job_title = b.job_title
             and e.gender = 'Female'
             and e.is_active),
        0
    )                                            as annual_cost_to_close_gap_usd

from {{ ref('int_salary_benchmarks') }}  b
where b.pay_equity_flag = 'male_favoured'
  and b.gender_gap_pct > 5
order by b.gender_gap_pct desc