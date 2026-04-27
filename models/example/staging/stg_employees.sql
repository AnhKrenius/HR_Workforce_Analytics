-- cleaning and standardising raw HR data from the source CSV load
-- granularity: employee-level, 1 row per employee. All downstream models build on this

with source as (
    select * from `feisty-flow-494614-f7.hr_analytics_raw.employees`
),
renamed as (
    select
        `Employee_ID` as employee_id,
        `First Name` as first_name,
        `Last Name` as last_name,
        Gender as gender,
        State as state,
        City as city,
        `Education Level` as education_level,
        Birthdate as birthdate,
        Hiredate as hiredate,
        Termdate as termdate,
        `Termination_Reason` as termination_reason,
        Department as department,
        `Job Title` as job_title,
        Salary as salary,
        `Salary_Band` as salary_band,
        `Performance Rating` as performance_rating,
        `Engagement_Score` as engagement_score,
        `Last_Promotion_Date` as last_promotion_date,
        `Remote_Eligible` as remote_eligible,
        `Overtime` as overtime
    from source
),

normalized as (
    select
        trim(cast(employee_id as string)) as employee_id,
        trim(cast(first_name as string)) as first_name,
        trim(cast(last_name as string)) as last_name,

        case
            when lower(trim(cast(gender as string))) in ('male', 'm') then 'Male'
            when lower(trim(cast(gender as string))) in ('female', 'f') then 'Female'
            else null
        end as gender,

        trim(cast(state as string)) as state,
        trim(cast(city as string)) as city,
        trim(cast(education_level as string)) as education_level,
        trim(cast(department as string)) as department,
        trim(cast(job_title as string)) as job_title,

        safe_cast(birthdate as date) as birthdate,
        safe_cast(hiredate as date) as hiredate,
        safe_cast(termdate as date) as termdate,
        safe_cast(last_promotion_date as date) as last_promotion_date,

        safe_cast(nullif(trim(cast(salary as string)), '') as int64) as salary,
        trim(cast(salary_band as string)) as salary_band,
        trim(cast(performance_rating as string)) as performance_rating,
        safe_cast(nullif(trim(cast(engagement_score as string)), '') as float64) as engagement_score,
        nullif(trim(cast(termination_reason as string)), '') as termination_reason,

        case
            when safe_cast(remote_eligible as bool) is not null then safe_cast(remote_eligible as bool)
            when lower(trim(cast(remote_eligible as string))) in ('yes', 'true', '1') then true
            when lower(trim(cast(remote_eligible as string))) in ('no', 'false', '0') then false
            else null
        end as remote_eligible,

        case
            when safe_cast(overtime as bool) is not null then safe_cast(overtime as bool)
            when lower(trim(cast(overtime as string))) in ('yes', 'true', '1') then true
            when lower(trim(cast(overtime as string))) in ('no', 'false', '0') then false
            else null
        end as overtime
    from renamed
),

enriched as (
    select
        *,
        termdate is null as is_active,
        termdate is not null as is_terminated,

        date_diff(
            coalesce(termdate, current_date()),
            hiredate,
            day
        ) as tenure_days,

        case
            when termdate is not null then date_diff(termdate, hiredate, month)
        end as months_to_termination,

        date_diff(current_date(), birthdate, year) as current_age,
        date_diff(hiredate, birthdate, year) as age_at_hire,

        case
            when last_promotion_date is not null then date_diff(current_date(), last_promotion_date, month)
        end as months_since_last_promotion,

        case
            when termdate is not null and date_diff(termdate, hiredate, month) < 12 then true
            else false
        end as is_early_leaver,

        case performance_rating
            when 'Excellent' then 4
            when 'Good' then 3
            when 'Satisfactory' then 2
            when 'Needs Improvement' then 1
        end as performance_score,

        case
            when engagement_score is null then 'unknown'
            when engagement_score < 2.5 then 'low'
            when engagement_score < 3.5 then 'medium'
            else 'high'
        end as engagement_band,

        case
            when termination_reason is null then null
            when starts_with(lower(termination_reason), 'voluntary') then 'voluntary'
            when starts_with(lower(termination_reason), 'involuntary') then 'involuntary'
            else 'other'
        end as termination_type,

        case
            when termination_reason is null then null
            when lower(termination_reason) like '%better opportunity%' then 'better_opportunity'
            when lower(termination_reason) like '%career change%' then 'career_change'
            when lower(termination_reason) like '%personal%' then 'personal_reasons'
            when lower(termination_reason) like '%relocation%' then 'relocation'
            when lower(termination_reason) like '%performance%' then 'performance'
            when lower(termination_reason) like '%redundancy%' then 'redundancy'
            else 'other'
        end as termination_reason_group,

        -- Useful quality flags for downstream monitoring
        hiredate is null as has_invalid_hiredate,
        birthdate is null as has_invalid_birthdate,
        salary is null or salary < 0 as has_invalid_salary
    from normalized
)

select * from enriched
