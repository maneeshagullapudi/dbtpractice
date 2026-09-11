-- Delivery performance aggregated at daily × city grain.
-- Feeds fct_delivery_sla (the delete+insert incremental model).
-- Computing SLA metrics here keeps fct_delivery_sla clean and readable.

with

    deliveries as (
        select * from {{ ref('stg_deliveries') }}
        where delivery_status in ('delivered', 'failed')
    ),

    orders as (
        select
            order_id,
            ordered_at,
            city_id,
            is_on_time_delivery,
            is_sla_breach,
            total_delivery_minutes
        from {{ ref('int_orders_enriched') }}
        where order_status in ('delivered', 'cancelled')
    ),

    cities as (
        select city_id, city_name, city_tier
        from {{ ref('stg_cities') }}
    ),

    joined as (
        select
            d.delivery_id,
            d.order_id,
            d.delivery_partner_id,
            d.delivery_status,
            d.assigned_at,
            d.picked_up_at,
            d.delivered_at,
            d.delivery_distance_km,

            o.ordered_at,
            o.city_id,
            o.is_on_time_delivery,
            o.is_sla_breach,
            o.total_delivery_minutes,

            ci.city_name,
            ci.city_tier,

            -- Derived timing fields for delivery-side analysis
            datediff('minute', d.assigned_at, d.picked_up_at) as minutes_to_pickup,
            datediff('minute', d.picked_up_at, d.delivered_at) as minutes_to_deliver,

            -- SLA categories
            case
                when o.total_delivery_minutes <= 30 then 'fast'
                when o.total_delivery_minutes <= 45 then 'standard'
                when o.total_delivery_minutes <= 60 then 'late'
                else 'very_late'
            end as delivery_speed_category,

            o.ordered_at::date as delivery_date

        from deliveries as d
        inner join orders as o
            on d.order_id = o.order_id
        left join cities as ci
            on o.city_id = ci.city_id
    ),

    daily_city_agg as (
        select
            delivery_date,
            city_id,
            city_name,
            city_tier,

            -- volume
            count(distinct delivery_id)                         as total_deliveries,
            count_if(delivery_status = 'delivered')             as successful_deliveries,
            count_if(delivery_status = 'failed')                as failed_deliveries,

            -- SLA metrics
            count_if(is_on_time_delivery = true)                as on_time_deliveries,
            count_if(is_sla_breach = true)                      as sla_breach_deliveries,
            count_if(delivery_speed_category = 'very_late')     as very_late_deliveries,

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

            -- Delivery time percentiles
            avg(total_delivery_minutes)                         as avg_delivery_minutes,
            percentile_cont(0.5) within group
                (order by total_delivery_minutes)               as p50_delivery_minutes,
            percentile_cont(0.75) within group
                (order by total_delivery_minutes)               as p75_delivery_minutes,
            percentile_cont(0.95) within group
                (order by total_delivery_minutes)               as p95_delivery_minutes

        from joined
        group by 1, 2, 3, 4
    )

select * from daily_city_agg
