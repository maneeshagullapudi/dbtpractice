-- Restaurant daily revenue and order metrics.
-- Feeds fct_restaurant_revenue (merge incremental by order_date + restaurant_id).
-- Keeps business logic in intermediate to avoid repeating it in the mart.

with

    orders as (
        select * from {{ ref('int_orders_enriched') }}
        where order_status in ('delivered', 'refunded')
    ),

    ratings as (
        select
            restaurant_id,
            rated_at::date                          as rating_date,
            avg(overall_rating)                     as avg_rating,
            count(*)                                as rating_count,
            count_if(is_negative = true)            as negative_rating_count
        from {{ ref('stg_ratings') }}
        group by 1, 2
    ),

    daily_restaurant_orders as (
        select
            order_date,
            restaurant_id,
            city_id,
            city_name,
            cuisine_type,
            restaurant_tier,
            commission_rate,

            -- volume
            count(distinct order_id)                as total_orders,
            count(distinct customer_id)             as unique_customers,

            -- revenue
            sum(total_amount)                       as gross_revenue,
            sum(platform_commission)                as platform_commission_earned,
            sum(promo_discount_amount)              as promo_discounts_absorbed,

            -- averages
            avg(total_amount)                       as avg_order_value,
            avg(total_items)                        as avg_items_per_order,

            -- performance
            avg(total_delivery_minutes)             as avg_delivery_minutes,
            avg(minutes_to_prepare)                 as avg_prep_minutes,
            count_if(is_on_time_delivery = true)    as on_time_order_count,
            count_if(is_sla_breach = true)          as sla_breach_order_count

        from orders
        group by 1, 2, 3, 4, 5, 6, 7
    ),

    joined as (
        select
            dr.*,
            coalesce(r.avg_rating, null)            as daily_avg_rating,
            coalesce(r.rating_count, 0)             as daily_rating_count,
            coalesce(r.negative_rating_count, 0)    as daily_negative_rating_count
        from daily_restaurant_orders as dr
        left join ratings as r
            on dr.restaurant_id = r.restaurant_id
            and dr.order_date = r.rating_date
    )

select * from joined
