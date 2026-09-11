import snowflake.snowpark.functions as F


def model(dbt, session):
    dbt.config(materialized="table", tags=["utilities", "python"])

    start_date = "2020-01-01"
    end_date = "2030-12-31"

    query = f"""
        with spine as (
            select
                dateadd(day, seq4(), to_date('{start_date}')) as date_day
            from table(generator(rowcount => 5000))
        )
        select
            date_day,
            dayofweekiso(date_day) as day_of_week_iso,
            dayofweek(date_day) as day_of_week_num,
            case dayofweekiso(date_day)
                when 1 then 'Monday'
                when 2 then 'Tuesday'
                when 3 then 'Wednesday'
                when 4 then 'Thursday'
                when 5 then 'Friday'
                when 6 then 'Saturday'
                when 7 then 'Sunday'
            end as day_of_week_name,
            day(date_day) as day_of_month,
            month(date_day) as month_num,
            monthname(date_day) as month_name,
            quarter(date_day) as quarter_num,
            'Q' || quarter(date_day) as quarter_label,
            year(date_day) as year_num,
            year(date_day) || '-Q' || quarter(date_day) as year_quarter_label,
            to_char(date_day, 'YYYY-MM') as year_month_label,
            weekofyear(date_day) as week_of_year,
            date_day = current_date() as is_today,
            date_day = current_date() - 1 as is_yesterday,
            date_day >= current_date() - 6 as is_last_7_days,
            date_day >= current_date() - 29 as is_last_30_days,
            date_day >= current_date() - 89 as is_last_90_days,
            date_day <= current_date() as is_past_or_today,
            date_day > current_date() as is_future,
            dayofweek(date_day) in (0, 6) as is_weekend,
            dayofweek(date_day) not in (0, 6) as is_weekday,
            case
                when to_char(date_day, 'MM-DD') = '01-26' then 'Republic Day'
                when to_char(date_day, 'MM-DD') = '08-15' then 'Independence Day'
                when to_char(date_day, 'MM-DD') = '10-02' then 'Gandhi Jayanti'
                when to_char(date_day, 'MM-DD') = '10-24' then 'Dussehra (approx)'
                when to_char(date_day, 'MM-DD') = '11-12' then 'Diwali (approx)'
                when to_char(date_day, 'MM-DD') = '12-25' then 'Christmas Day'
                else null
            end as national_holiday_name,
            to_char(date_day, 'MM-DD') in ('01-26', '08-15', '10-02') as is_national_holiday,
            case
                when month(date_day) in (10, 11) then 'festive_season'
                when month(date_day) in (12, 1) then 'new_year_season'
                when month(date_day) in (6, 7, 8) then 'monsoon_season'
                when month(date_day) in (3, 4) then 'summer_season'
                else 'regular'
            end as business_season,
            date_day = date_trunc('month', date_day)::date as is_first_of_month,
            date_day = last_day(date_day, 'month') as is_last_of_month,
            date_day = date_trunc('quarter', date_day)::date as is_first_of_quarter,
            to_char(date_day, 'YYYYMMDD') as date_key
        from spine
        where date_day <= to_date('{end_date}')
    """

    return session.sql(query)
