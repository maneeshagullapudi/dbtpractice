{{
    config(
        materialized         = 'incremental',
        incremental_strategy = 'insert_overwrite',
        cluster_by           = ['delivery_hour::date', 'city_id']
    )
}}

with

    deliveries as (
        select
            delivery_id,
            order_id,
            delivery_status,
            assigned_at,
            delivered_at,
            delivery_distance_km
        from {{ ref('stg_deliveries') }}
        where delivery_status in ('delivered', 'failed')
    ),

    orders as (
        select
            order_id,
            city_id,
            city_name,
            city_tier,
            ordered_at,
            is_on_time_delivery,
            is_sla_breach,
            total_delivery_minutes
        from {{ ref('int_orders_enriched') }}
        where order_status in ('delivered', 'cancelled')
    ),

    joined as (
        select
            date_trunc('hour', o.ordered_at)                      as delivery_hour,
            o.city_id,
            o.city_name,
            o.city_tier,
            d.delivery_id,
            d.delivery_status,
            o.is_on_time_delivery,
            o.is_sla_breach,
            o.total_delivery_minutes,
            d.delivery_distance_km
        from deliveries as d
        inner join orders as o
            on d.order_id = o.order_id
        {% if is_incremental() %}
        where o.ordered_at >= dateadd(day, -3, current_timestamp())
        {% endif %}
    ),

    hourly_city_agg as (
        select
            delivery_hour,
            city_id,
            city_name,
            city_tier,
            count(distinct delivery_id)                         as total_deliveries,
            count_if(delivery_status = 'delivered')             as successful_deliveries,
            count_if(delivery_status = 'failed')                as failed_deliveries,
            count_if(is_on_time_delivery = true)                as on_time_deliveries,
            count_if(is_sla_breach = true)                      as sla_breach_deliveries,
            round(
                count_if(is_on_time_delivery = true) /
                nullif(count_if(delivery_status = 'delivered'), 0),
                4
            )                                                   as on_time_delivery_rate,
            round(
                count_if(is_sla_breach = true) /
                nullif(count_if(delivery_status = 'delivered'), 0),
                4
            )                                                   as sla_breach_rate,
            avg(total_delivery_minutes)                         as avg_delivery_minutes,
            percentile_cont(0.5) within group
                (order by total_delivery_minutes)               as p50_delivery_minutes,
            percentile_cont(0.95) within group
                (order by total_delivery_minutes)               as p95_delivery_minutes,
            avg(delivery_distance_km)                           as avg_delivery_distance_km
        from joined
        group by 1, 2, 3, 4
    )

select
    delivery_hour,
    city_id,
    city_name,
    city_tier,
    total_deliveries,
    successful_deliveries,
    failed_deliveries,
    on_time_deliveries,
    sla_breach_deliveries,
    on_time_delivery_rate,
    sla_breach_rate,
    avg_delivery_minutes,
    p50_delivery_minutes,
    p95_delivery_minutes,
    avg_delivery_distance_km,
    {{ add_audit_columns(hash_columns=['delivery_hour', 'city_id']) }}
from hourly_city_agg
