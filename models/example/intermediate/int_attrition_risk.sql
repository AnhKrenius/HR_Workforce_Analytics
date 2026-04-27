-- int_attrition_risk_improved.sql
-- Explainable attrition risk score (0-100) for active employees.
-- Uses enhanced features from stg_employees_improved.
-- BUSINESS PROBLEMS THIS SOLVES:
--  No early warning for resignations:
--    HR teams often react after resignation is submitted. This model creates a
--    proactive risk score to surface likely attrition cases before exit.
--  Retention budget not prioritized:
--    Without a structured score, salary reviews and manager interventions are
--    spread too broadly. This model ranks employees by risk and suggested action.
--  Root cause is unclear:
--    A single risk label is not enough. This model exposes component scores and
--    primary_risk_driver so HR can target the right intervention.
-- SCORING DESIGN (TOTAL = 100 PTS):
--   tenure_score (25): new hires are most vulnerable
--   salary_score (20): below-role-median pay increases flight risk
--   performance_risk_score (20): protects top performers; flags low performers
--   dept_risk_score (15): department context from historical attrition
--   engagement_risk_score (10): low engagement indicates disengagement risk
--   growth_load_risk_score (10): promotion stagnation and overtime pressure
-- OUTPUT INTERPRETATION:
-- - risk_score: 0-100 composite risk
-- - risk_tier: critical/high/medium/low based on score thresholds
-- - recommended_action: first practical action for manager/HRBP
-- - primary_risk_driver: dominant dimension explaining employee risk
-- IMPORTANT:
-- This is a transparent scorecard for prioritization, not a causal model.
-- Use together with manager context before taking employee-level decisions.

with employees as (
    select *
    from {{ ref('stg_employees') }}
    where is_active = true
),

benchmarks as (
    select
        job_title,
        education_level,
        median_salary_role
    from {{ ref('int_salary_benchmarks') }}
),

all_employees as (
    select *
    from {{ ref('stg_employees') }}
),

dept_attrition as (
    select
        department,
        countif(is_active = false) as terminated_count,
        count(*) as total_count,
        round(safe_divide(countif(is_active = false), count(*)) * 100, 1) as dept_attrition_rate
    from all_employees
    group by department
),

scored as (
    select
        e.employee_id,
        e.first_name,
        e.last_name,
        e.gender,
        e.state,
        e.city,
        e.department,
        e.job_title,
        e.education_level,
        e.salary,
        e.salary_band,
        e.performance_rating,
        e.performance_score,
        e.engagement_score,
        e.engagement_band,
        e.remote_eligible,
        e.overtime,
        e.birthdate,
        e.hiredate,
        e.last_promotion_date,
        e.current_age,
        e.age_at_hire,
        e.tenure_days,
        e.months_since_last_promotion,
        d.dept_attrition_rate,
        b.median_salary_role,
        round(safe_divide(e.salary, b.median_salary_role) * 100, 1) as salary_pct_of_median,

        -- Component 1 (25 pts): tenure risk
        case
            when e.tenure_days < 180 then 25
            when e.tenure_days < 365 then 20
            when e.tenure_days < 730 then 12
            when e.tenure_days < 1460 then 6
            else 2
        end as tenure_score,

        -- Component 2 (20 pts): compensation risk
        case
            when b.median_salary_role is null then 8
            when safe_divide(e.salary, b.median_salary_role) < 0.80 then 20
            when safe_divide(e.salary, b.median_salary_role) < 0.90 then 15
            when safe_divide(e.salary, b.median_salary_role) < 0.95 then 10
            when safe_divide(e.salary, b.median_salary_role) < 1.05 then 4
            else 0
        end as salary_score,

        -- Component 3 (20 pts): performance risk
        case
            when e.performance_rating = 'Excellent' then 16
            when e.performance_rating = 'Good' then 8
            when e.performance_rating = 'Satisfactory' then 5
            when e.performance_rating = 'Needs Improvement' then 20
            else 8
        end as performance_risk_score,

        -- Component 4 (15 pts): department-level attrition context
        case
            when d.dept_attrition_rate >= 15 then 15
            when d.dept_attrition_rate >= 12 then 12
            when d.dept_attrition_rate >= 9 then 8
            else 4
        end as dept_risk_score,

        -- Component 5 (10 pts): engagement risk
        case
            when e.engagement_band = 'low' then 10
            when e.engagement_band = 'medium' then 6
            when e.engagement_band = 'high' then 2
            else 5
        end as engagement_risk_score,

        -- Component 6 (10 pts): growth/load risk (promotion stagnation + overtime)
        least(
            case
                when e.months_since_last_promotion is null then 2
                when e.months_since_last_promotion >= 36 then 8
                when e.months_since_last_promotion >= 24 then 6
                when e.months_since_last_promotion >= 12 then 3
                else 1
            end
            + case when e.overtime then 2 else 0 end,
            10
        ) as growth_load_risk_score

    from employees e
    left join benchmarks b
        on e.job_title = b.job_title
        and e.education_level = b.education_level
    left join dept_attrition d
        on e.department = d.department
),

final as (
    select
        *,
        -- Composite score used for prioritization queue
        tenure_score
        + salary_score
        + performance_risk_score
        + dept_risk_score
        + engagement_risk_score
        + growth_load_risk_score as risk_score,
        -- Business tiers for dashboard segmentation
        case
            when (
                tenure_score
                + salary_score
                + performance_risk_score
                + dept_risk_score
                + engagement_risk_score
                + growth_load_risk_score
            ) >= 75 then 'critical'
            when (
                tenure_score
                + salary_score
                + performance_risk_score
                + dept_risk_score
                + engagement_risk_score
                + growth_load_risk_score
            ) >= 55 then 'high'
            when (
                tenure_score
                + salary_score
                + performance_risk_score
                + dept_risk_score
                + engagement_risk_score
                + growth_load_risk_score
            ) >= 35 then 'medium'
            else 'low'
        end as risk_tier,
        -- Human-readable intervention recommendation
        case
            when tenure_days < 365 and salary_pct_of_median < 90 then 'New-hire retention + salary review'
            when engagement_band = 'low' and overtime then 'Manager intervention: workload + engagement'
            when performance_rating = 'Excellent' and salary_pct_of_median < 95 then 'Retain top performer (compensation adjustment)'
            when months_since_last_promotion >= 24 then 'Career progression conversation'
            when performance_rating = 'Needs Improvement' then 'Performance plan and coaching'
            else 'Standard engagement monitoring'
        end as recommended_action,
        -- Main contributing factor for explainability
        case
            when greatest(
                tenure_score,
                salary_score,
                performance_risk_score,
                dept_risk_score,
                engagement_risk_score,
                growth_load_risk_score
            ) = tenure_score then 'tenure'
            when greatest(
                tenure_score,
                salary_score,
                performance_risk_score,
                dept_risk_score,
                engagement_risk_score,
                growth_load_risk_score
            ) = salary_score then 'compensation'
            when greatest(
                tenure_score,
                salary_score,
                performance_risk_score,
                dept_risk_score,
                engagement_risk_score,
                growth_load_risk_score
            ) = performance_risk_score then 'performance'
            when greatest(
                tenure_score,
                salary_score,
                performance_risk_score,
                dept_risk_score,
                engagement_risk_score,
                growth_load_risk_score
            ) = engagement_risk_score then 'engagement'
            when greatest(
                tenure_score,
                salary_score,
                performance_risk_score,
                dept_risk_score,
                engagement_risk_score,
                growth_load_risk_score
            ) = growth_load_risk_score then 'growth_or_workload'
            else 'department_context'
        end as primary_risk_driver
    from scored
)

select *
from final
order by risk_score desc
