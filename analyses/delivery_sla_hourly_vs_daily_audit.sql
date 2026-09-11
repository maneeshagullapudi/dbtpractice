-- Audit: does the hourly SLA aggregate reconcile to the existing daily SLA mart
-- over the same recent window that the hourly model incrementally rebuilds?

{% set window_start_sql %}dateadd(day, -3, current_date()){% endset %}

{% set hourly_rollup_query %}
    with hourly_rollup as (
        select
            date_trunc('day', delivery_hour)::date               as delivery_date,
            city_id,
            min(city_name)                                       as city_name,
            min(city_tier)                                       as city_tier,
            sum(total_deliveries)                                as total_deliveries,
            sum(successful_deliveries)                           as successful_deliveries,
            sum(failed_deliveries)                               as failed_deliveries,
            sum(on_time_deliveries)                              as on_time_deliveries,
            sum(sla_breach_deliveries)                           as sla_breach_deliveries,
            round(
                sum(on_time_deliveries) / nullif(sum(successful_deliveries), 0),
                4
            )                                                    as on_time_delivery_rate,
            round(
                sum(sla_breach_deliveries) / nullif(sum(successful_deliveries), 0),
                4
            )                                                    as sla_breach_rate
        from {{ ref('fct_delivery_sla_hourly') }}
        where delivery_hour::date >= {{ window_start_sql }}
        group by 1, 2
    )

    select
        delivery_date,
        city_id,
        city_name,
        city_tier,
        total_deliveries,
        successful_deliveries,
        failed_deliveries,
        on_time_deliveries,
        sla_breach_deliveries,
        on_time_delivery_rate,
        sla_breach_rate
    from hourly_rollup
{% endset %}

{% set daily_query %}
    select
        delivery_date,
        city_id,
        city_name,
        city_tier,
        total_deliveries,
        successful_deliveries,
        failed_deliveries,
        on_time_deliveries,
        sla_breach_deliveries,
        on_time_delivery_rate,
        sla_breach_rate
    from {{ ref('fct_delivery_sla') }}
    where delivery_date >= {{ window_start_sql }}
{% endset %}

{{
    audit_helper.compare_queries(
        a_query=hourly_rollup_query,
        b_query=daily_query,
        primary_key='delivery_date, city_id',
        summarize=true
    )
}}
