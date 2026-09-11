{% if target.name == 'stage' %}
{{
    config(
        materialized         = 'incremental',
        incremental_strategy = 'merge',
        full_refresh         = false,
        unique_key           = 'delivery_id',
        cluster_by           = ['delivered_at::date', 'city_id']
    )
}}
{% else %}
{{
    config(
        materialized         = 'incremental',
        incremental_strategy = 'microbatch',
        event_time           = 'assigned_at',
        begin                = '2024-01-01',
        batch_size           = 'day',
        lookback             = 1,
        full_refresh         = false,
        unique_key           = 'delivery_id',
        cluster_by           = ['delivered_at::date', 'city_id']
    )
}}
{% endif %}

with

    deliveries as (
        select * from {{ ref('stg_deliveries') }}
    ),

    orders as (
        select
            order_id,
            customer_id,
            restaurant_id,
            city_id,
            city_name,
            city_tier,
            order_status,
            total_amount,
            ordered_at,
            order_date,
            total_delivery_minutes,
            is_on_time_delivery,
            is_sla_breach
        from {{ ref('int_orders_enriched') }}
    ),

    delivery_partner_history as (
        select
            delivery_partner_id,
            vehicle_type,
            home_city_id,
            average_rating                          as partner_avg_rating,
            dbt_valid_from,
            dbt_valid_to
        from {{ ref('snp_delivery_partners') }}
    )

select
    -- primary key
    d.delivery_id,

    -- foreign keys
    d.order_id,
    d.delivery_partner_id,
    o.customer_id,
    o.restaurant_id,
    o.city_id,

    -- descriptive
    o.city_name,
    o.city_tier,
    dp.vehicle_type,

    -- delivery status
    d.delivery_status,
    d.failure_reason,

    -- SLA
    o.is_on_time_delivery,
    o.is_sla_breach,
    o.total_delivery_minutes,

    -- distance
    cast(d.delivery_distance_km as number(38, 6))           as delivery_distance_km,
    cast(d.route_distance_km as number(38, 6))              as route_distance_km,

    -- time breakdown
    datediff('minute', d.assigned_at, d.picked_up_at)      as minutes_partner_to_restaurant,
    datediff('minute', d.picked_up_at, d.delivered_at)     as minutes_restaurant_to_customer,

    -- order context
    o.total_amount,

    -- timestamps
    d.assigned_at,
    d.picked_up_at,
    d.delivered_at,
    o.ordered_at,
    o.order_date,
    d.updated_at,

    -- audit
    {{ add_audit_columns(hash_columns=['delivery_id']) }}

from deliveries as d
left join orders as o
    on d.order_id = o.order_id
left join delivery_partner_history as dp
    on d.delivery_partner_id = dp.delivery_partner_id
    and d.assigned_at >= dp.dbt_valid_from
    and d.assigned_at < dp.dbt_valid_to
