-- mart_attrition_risk_dashboard_improved.sql
-- Employee-level table for attrition monitoring and manager action tracking.
-- One row per active employee from int_attrition_risk_improved.

select
    -- Identity / org context
    employee_id,
    first_name || ' ' || last_name as full_name,
    department,
    job_title,
    gender,
    education_level,
    state,
    city,

    -- Employment profile
    hiredate,
    tenure_days,
    round(tenure_days / 30.0, 1) as tenure_months,
    case
        when tenure_days < 90 then '0-3 months'
        when tenure_days < 180 then '3-6 months'
        when tenure_days < 365 then '6-12 months'
        when tenure_days < 730 then '1-2 years'
        when tenure_days < 1460 then '2-4 years'
        else '4+ years'
    end as tenure_band,
    current_age,
    age_at_hire,

    -- Compensation context
    salary,
    salary_band,
    median_salary_role,
    salary_pct_of_median,
    case
        when salary_pct_of_median < 85 then 'Severely underpaid'
        when salary_pct_of_median < 95 then 'Underpaid'
        when salary_pct_of_median < 105 then 'At market'
        else 'Above market'
    end as compensation_band,
    salary_pct_of_median < 85 as is_underpaid,

    -- Engagement / growth context
    performance_rating,
    performance_score,
    engagement_score,
    engagement_band,
    remote_eligible,
    overtime,
    last_promotion_date,
    months_since_last_promotion,
    case
        when months_since_last_promotion is null then 'No promotion data'
        when months_since_last_promotion >= 36 then '>=36 months'
        when months_since_last_promotion >= 24 then '24-35 months'
        when months_since_last_promotion >= 12 then '12-23 months'
        else '<12 months'
    end as promotion_recency_band,

    -- Risk outputs (core)
    risk_score,
    risk_tier,
    primary_risk_driver,
    recommended_action,

    -- Risk component explainability
    tenure_score,
    salary_score,
    performance_risk_score,
    dept_risk_score,
    engagement_risk_score,
    growth_load_risk_score,
    dept_attrition_rate

from {{ ref('int_attrition_risk') }}
