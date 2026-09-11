-- Ephemeral: inlined as a CTE into all downstream fact models.
-- Centralizes the core order enrichment join so it's written once.
-- The is_incremental() filter in downstream marts cascades through this model.

with

    orders as (
        select * from {{ ref('stg_orders') }}
    ),

    order_items as (
        select
            order_id,
            count(*)                                as total_items,
            sum(item_subtotal)                      as computed_subtotal,
            count(distinct item_category)           as distinct_item_categories,
            count_if(is_vegetarian = false)         as non_veg_item_count
        from {{ ref('stg_order_items') }}
        group by 1
    ),

    customers as (
        select
            customer_id,
            customer_segment,
            acquisition_channel,
            is_pro_subscriber
        from {{ ref('stg_customers') }}
    ),

    restaurants as (
        select
            restaurant_id,
            cuisine_type,
            restaurant_tier,
            commission_rate
        from {{ ref('stg_restaurants') }}
    ),

    cities as (
        select
            city_id,
            city_name,
            city_tier,
            is_metro
        from {{ ref('stg_cities') }}
    ),

    enriched as (
        select
            -- order identity
            o.order_id,
            o.customer_id,
            o.restaurant_id,
            o.delivery_partner_id,
            o.city_id,
            o.promo_id,

            -- amounts
            o.subtotal_amount,
            o.delivery_fee,
            o.platform_fee,
            o.promo_discount_amount,
            o.gst_amount,
            o.total_amount,

            -- status
            o.order_status,
            o.cancellation_reason,

            -- enriched from order items
            coalesce(oi.total_items, 0)             as total_items,
            coalesce(oi.computed_subtotal, 0)       as computed_subtotal,
            oi.distinct_item_categories,
            oi.non_veg_item_count,
            abs(o.subtotal_amount - coalesce(oi.computed_subtotal, 0)) as subtotal_variance,

            -- enriched from customers
            c.customer_segment,
            c.acquisition_channel,
            c.is_pro_subscriber,

            -- enriched from restaurants
            r.cuisine_type,
            r.restaurant_tier,
            r.commission_rate,
            o.total_amount * r.commission_rate      as platform_commission,

            -- enriched from cities
            ci.city_name,
            ci.city_tier,
            ci.is_metro,

            -- order timestamps
            o.ordered_at,
            o.accepted_at,
            o.prepared_at,
            o.picked_up_at,
            o.delivered_at,
            o.cancelled_at,
            o.updated_at,

            -- derived timing fields (minutes between lifecycle events)
            datediff('minute', o.ordered_at, o.accepted_at)        as minutes_to_accept,
            datediff('minute', o.accepted_at, o.prepared_at)       as minutes_to_prepare,
            datediff('minute', o.prepared_at, o.picked_up_at)      as minutes_to_pickup,
            datediff('minute', o.picked_up_at, o.delivered_at)     as minutes_to_deliver,
            datediff('minute', o.ordered_at, o.delivered_at)       as total_delivery_minutes,

            -- SLA flags
            case
                when o.order_status = 'delivered'
                    and datediff('minute', o.ordered_at, o.delivered_at) <= {{ var('delivery_sla_minutes', 45) }}
                then true
                else false
            end as is_on_time_delivery,

            case
                when o.order_status = 'delivered'
                    and datediff('minute', o.ordered_at, o.delivered_at) > 60
                then true
                else false
            end as is_sla_breach,

            -- business calendar fields (for partition-efficient queries)
            o.ordered_at::date                      as order_date,
            date_trunc('week', o.ordered_at)::date  as order_week,
            date_trunc('month', o.ordered_at)::date as order_month,
            dayofweek(o.ordered_at)                 as day_of_week_num,
            hour(o.ordered_at)                      as order_hour,

            case
                when dayofweek(o.ordered_at) in (1, 7) then true
                else false
            end as is_weekend_order

        from orders as o
        left join order_items as oi
            on o.order_id = oi.order_id
        left join customers as c
            on o.customer_id = c.customer_id
        left join restaurants as r
            on o.restaurant_id = r.restaurant_id
        left join cities as ci
            on o.city_id = ci.city_id
    )

select * from enriched
