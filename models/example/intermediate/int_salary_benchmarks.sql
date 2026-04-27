-- compensation benchmarks per job title + education level
-- uses robust median calculations

with employees as (
    select *
    from {{ ref('stg_employees') }}
    where is_active = true
      and salary is not null
      and salary > 0
      and job_title is not null
      and education_level is not null
),
role_overall as (
    select
        job_title,
        education_level,
        count(*) as total_headcount,
        round(avg(salary), 0) as avg_salary_role,
        approx_quantiles(salary, 100)[offset(50)] as median_salary_role
    from employees
    group by job_title, education_level
),

role_gender as (
    select
        job_title,
        education_level,
        countif(gender = 'Male') as male_headcount,
        countif(gender = 'Female') as female_headcount,
        approx_quantiles(if(gender = 'Male', salary, null), 100)[offset(50)] as median_male,
        approx_quantiles(if(gender = 'Female', salary, null), 100)[offset(50)] as median_female
    from employees
    group by job_title, education_level
),

final as (
    select
        o.job_title,
        o.education_level,
        o.total_headcount,
        o.avg_salary_role,
        o.median_salary_role,
        g.male_headcount,
        g.female_headcount,
        g.median_male,
        g.median_female,
        round(
            safe_divide(g.median_male - g.median_female, g.median_female) * 100,
            1
        ) as gender_gap_pct,
        case
            when g.median_male is null or g.median_female is null then 'equitable'
            when safe_divide(g.median_male - g.median_female, g.median_female) > 0.05 then 'male_favoured'
            when safe_divide(g.median_male - g.median_female, g.median_female) < -0.05 then 'female_favoured'
            else 'equitable'
        end as pay_equity_flag
    from role_overall o
    left join role_gender g
        on o.job_title = g.job_title
        and o.education_level = g.education_level
)

select * from final