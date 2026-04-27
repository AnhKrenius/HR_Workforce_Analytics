-- mart_hr_executive_summary.sql
-- Department-level HR scorecard for leadership reviews.
-- One row per department with attrition, risk, compensation, and engagement context.

with employees as (
    select * from {{ ref('stg_employees') }}
),
risk as (
    select * from {{ ref('int_attrition_risk') }}
),
benchmarks as (
    select * from {{ ref('int_salary_benchmarks') }}
),
dept_stats as (
    select
        department,
        -- Headcount
        count(*) as total_headcount,
        countif(is_active) as active_headcount,
        countif(not is_active) as terminated_headcount,
        -- Attrition
        round(safe_divide(countif(not is_active), count(*)) * 100, 1) as attrition_rate_pct,
        countif(is_early_leaver) as early_leavers,
        round(
            safe_divide(countif(is_early_leaver), countif(not is_active)) * 100,
            1
        ) as early_attrition_pct,

        -- Compensation
        round(avg(salary), 0) as avg_salary,
        round(min(salary), 0) as min_salary,
        round(max(salary), 0) as max_salary,

        -- Performance mix
        countif(is_active and performance_rating = 'Excellent') as active_excellent,
        countif(is_active and performance_rating = 'Good') as active_good,
        round(
            safe_divide(
                countif(is_active and performance_rating = 'Excellent'),
                countif(is_active)
            ) * 100,
            1
        ) as pct_excellent,

        -- Engagement and workload
        round(avg(case when is_active then engagement_score end), 2) as avg_engagement_score,
        round(
            safe_divide(countif(is_active and engagement_band = 'low'), countif(is_active)) * 100,
            1
        ) as pct_low_engagement,
        round(
            safe_divide(countif(is_active and overtime), countif(is_active)) * 100,
            1
        ) as pct_overtime,
        round(
            safe_divide(countif(is_active and remote_eligible), countif(is_active)) * 100,
            1
        ) as pct_remote_eligible,

        -- Mobility / growth
        round(avg(case when is_active then months_since_last_promotion end), 1) as avg_months_since_promotion,
        round(
            safe_divide(
                countif(is_active and months_since_last_promotion >= 24),
                countif(is_active)
            ) * 100,
            1
        ) as pct_promotion_stagnation_24m

    from employees
    group by department
),

dept_risk as (
    select
        department,
        count(*) as total_scored,
        countif(risk_tier = 'critical') as critical_count,
        countif(risk_tier = 'high') as high_risk_count,
        countif(risk_tier in ('critical', 'high')) as high_or_critical_count,
        round(avg(risk_score), 1) as avg_risk_score,
        round(
            safe_divide(countif(risk_tier in ('critical', 'high')), count(*)) * 100,
            1
        ) as pct_high_or_critical,
        countif(salary_pct_of_median < 85) as underpaid_count
    from risk
    group by department
),

dept_pay_gap as (
    select
        e.department,
        round(avg(b.gender_gap_pct), 1) as avg_gender_gap_pct,
        countif(b.pay_equity_flag = 'male_favoured') as roles_male_favoured,
        countif(b.pay_equity_flag = 'female_favoured') as roles_female_favoured,
        countif(b.pay_equity_flag != 'equitable') as roles_equity_hotspot
    from employees e
    inner join benchmarks b
        on e.job_title = b.job_title
        and e.education_level = b.education_level
    where e.is_active
    group by e.department
),

final as (
    select
        ds.department,
        ds.total_headcount,
        ds.active_headcount,
        ds.terminated_headcount,
        ds.attrition_rate_pct,
        ds.early_leavers,
        ds.early_attrition_pct,
        ds.avg_salary,
        ds.min_salary,
        ds.max_salary,
        ds.pct_excellent,
        ds.avg_engagement_score,
        ds.pct_low_engagement,
        ds.pct_overtime,
        ds.pct_remote_eligible,
        ds.avg_months_since_promotion,
        ds.pct_promotion_stagnation_24m,
        dr.avg_risk_score,
        dr.critical_count,
        dr.high_risk_count,
        dr.high_or_critical_count,
        dr.pct_high_or_critical,
        dr.underpaid_count,
        dpg.avg_gender_gap_pct,
        dpg.roles_male_favoured,
        dpg.roles_female_favoured,
        dpg.roles_equity_hotspot,
        round(
            100
            - (ds.attrition_rate_pct * 2.0)
            - (dr.avg_risk_score * 0.7)
            - (ds.pct_low_engagement * 0.6)
            - (ds.pct_promotion_stagnation_24m * 0.3)
            + (ds.pct_excellent * 0.4),
            0
        ) as dept_health_score,
        case
            when dr.pct_high_or_critical >= 35 or ds.attrition_rate_pct >= 15 then 'urgent'
            when dr.pct_high_or_critical >= 20 or ds.attrition_rate_pct >= 10 then 'watchlist'
            else 'stable'
        end as intervention_priority
    from dept_stats ds
    left join dept_risk dr
        on ds.department = dr.department
    left join dept_pay_gap dpg
        on ds.department = dpg.department
)

select *
from final
order by intervention_priority desc, attrition_rate_pct desc
