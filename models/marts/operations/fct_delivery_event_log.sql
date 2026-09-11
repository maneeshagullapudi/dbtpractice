{{
    config(
        materialized         = 'incremental',
        incremental_strategy = 'append',
        event_time           = 'event_at',
        cluster_by           = ['event_at::date', 'city_id']
    )
}}

with

    deliveries as (
        select
            delivery_id,
            order_id,
            delivery_partner_id,
            delivery_status,
            failure_reason,
            assigned_at,
            en_route_restaurant_at,
            arrived_restaurant_at,
            picked_up_at,
            delivered_at,
            delivery_distance_km,
            route_distance_km,
            updated_at,
            src_load_dts
        from {{ ref('stg_deliveries') }}
    ),

    orders as (
        select
            order_id,
            customer_id,
            restaurant_id,
            city_id,
            city_name,
            city_tier,
            ordered_at,
            order_date
        from {{ ref('int_orders_enriched') }}
    ),

    assigned_events as (
        select
            d.delivery_id,
            d.order_id,
            d.delivery_partner_id,
            o.customer_id,
            o.restaurant_id,
            o.city_id,
            o.city_name,
            o.city_tier,
            o.order_date,
            o.ordered_at,
            d.delivery_distance_km,
            d.route_distance_km,
            d.failure_reason,
            d.delivery_status as latest_delivery_status,
            d.updated_at as source_delivery_updated_at,
            d.src_load_dts,
            'assigned' as event_type,
            d.assigned_at as event_at,
            1 as sequence_in_delivery
        from deliveries as d
        left join orders as o
            on d.order_id = o.order_id
        where d.assigned_at is not null
    ),

    en_route_restaurant_events as (
        select
            d.delivery_id,
            d.order_id,
            d.delivery_partner_id,
            o.customer_id,
            o.restaurant_id,
            o.city_id,
            o.city_name,
            o.city_tier,
            o.order_date,
            o.ordered_at,
            d.delivery_distance_km,
            d.route_distance_km,
            d.failure_reason,
            d.delivery_status as latest_delivery_status,
            d.updated_at as source_delivery_updated_at,
            d.src_load_dts,
            'en_route_restaurant' as event_type,
            d.en_route_restaurant_at as event_at,
            2 as sequence_in_delivery
        from deliveries as d
        left join orders as o
            on d.order_id = o.order_id
        where d.en_route_restaurant_at is not null
    ),

    arrived_restaurant_events as (
        select
            d.delivery_id,
            d.order_id,
            d.delivery_partner_id,
            o.customer_id,
            o.restaurant_id,
            o.city_id,
            o.city_name,
            o.city_tier,
            o.order_date,
            o.ordered_at,
            d.delivery_distance_km,
            d.route_distance_km,
            d.failure_reason,
            d.delivery_status as latest_delivery_status,
            d.updated_at as source_delivery_updated_at,
            d.src_load_dts,
            'arrived_restaurant' as event_type,
            d.arrived_restaurant_at as event_at,
            3 as sequence_in_delivery
        from deliveries as d
        left join orders as o
            on d.order_id = o.order_id
        where d.arrived_restaurant_at is not null
    ),

    picked_up_events as (
        select
            d.delivery_id,
            d.order_id,
            d.delivery_partner_id,
            o.customer_id,
            o.restaurant_id,
            o.city_id,
            o.city_name,
            o.city_tier,
            o.order_date,
            o.ordered_at,
            d.delivery_distance_km,
            d.route_distance_km,
            d.failure_reason,
            d.delivery_status as latest_delivery_status,
            d.updated_at as source_delivery_updated_at,
            d.src_load_dts,
            'picked_up' as event_type,
            d.picked_up_at as event_at,
            4 as sequence_in_delivery
        from deliveries as d
        left join orders as o
            on d.order_id = o.order_id
        where d.picked_up_at is not null
    ),

    delivered_events as (
        select
            d.delivery_id,
            d.order_id,
            d.delivery_partner_id,
            o.customer_id,
            o.restaurant_id,
            o.city_id,
            o.city_name,
            o.city_tier,
            o.order_date,
            o.ordered_at,
            d.delivery_distance_km,
            d.route_distance_km,
            d.failure_reason,
            d.delivery_status as latest_delivery_status,
            d.updated_at as source_delivery_updated_at,
            d.src_load_dts,
            'delivered' as event_type,
            d.delivered_at as event_at,
            5 as sequence_in_delivery
        from deliveries as d
        left join orders as o
            on d.order_id = o.order_id
        where d.delivered_at is not null
    ),

    base_events as (
        select * from assigned_events
        union all
        select * from en_route_restaurant_events
        union all
        select * from arrived_restaurant_events
        union all
        select * from picked_up_events
        union all
        select * from delivered_events
    ),

    final as (
        select
            {{ dbt_utils.generate_surrogate_key(['delivery_id', 'event_type', 'event_at']) }} as delivery_event_key,
            delivery_id,
            order_id,
            delivery_partner_id,
            customer_id,
            restaurant_id,
            city_id,
            city_name,
            city_tier,
            order_date,
            ordered_at,
            event_type,
            event_at,
            sequence_in_delivery,
            latest_delivery_status,
            failure_reason,
            delivery_distance_km,
            route_distance_km,
            source_delivery_updated_at,
            src_load_dts
        from base_events
    )

select
    f.delivery_event_key,
    f.delivery_id,
    f.order_id,
    f.delivery_partner_id,
    f.customer_id,
    f.restaurant_id,
    f.city_id,
    f.city_name,
    f.city_tier,
    f.order_date,
    f.ordered_at,
    f.event_type,
    f.event_at,
    f.sequence_in_delivery,
    f.latest_delivery_status,
    f.failure_reason,
    f.delivery_distance_km,
    f.route_distance_km,
    f.source_delivery_updated_at,
    {{ add_audit_columns(hash_columns=['f.delivery_id', 'f.event_type', 'f.event_at']) }}
from final as f
{% if is_incremental() %}
left join {{ this }} as existing
    on f.delivery_event_key = existing.delivery_event_key
where existing.delivery_event_key is null
{% endif %}
