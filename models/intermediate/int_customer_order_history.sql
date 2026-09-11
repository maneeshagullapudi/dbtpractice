-- Customer-level order history aggregation.
-- Feeds fct_customer_orders and fct_customer_lifetime_value.
-- Computes first-order date (acquisition), last-order date (recency),
-- and all behavioral aggregates needed for LTV and retention modeling.

with

    orders as (
        select * from {{ ref('int_orders_enriched') }}
        where order_status in ('delivered', 'refunded')  -- only fulfilled orders count toward history
    ),

    customer_history as (
        select
            customer_id,

            -- acquisition
            min(ordered_at)                         as first_order_at,
            min(ordered_at)::date                   as first_order_date,
            date_trunc('month', min(ordered_at))::date as first_order_month,

            -- recency
            max(ordered_at)                         as last_order_at,
            max(ordered_at)::date                   as last_order_date,
            datediff('day', max(ordered_at), current_date()) as days_since_last_order,

            -- frequency
            count(distinct order_id)                as total_orders,
            count(distinct order_date)              as distinct_order_days,
            count(distinct order_month)             as active_months,

            -- monetary
            sum(total_amount)                       as lifetime_gross_revenue,
            sum(total_amount - promo_discount_amount) as lifetime_net_revenue,
            avg(total_amount)                       as average_order_value,
            max(total_amount)                       as max_order_value,

            -- behavioral
            count_if(is_pro_subscriber = true)      as pro_subscription_orders,
            count_if(promo_id is not null)          as promo_orders,
            sum(promo_discount_amount)              as total_promo_discounts_used,
            count(distinct cuisine_type)            as distinct_cuisines_ordered,
            count(distinct restaurant_id)           as distinct_restaurants_ordered,
            count(distinct city_id)                 as distinct_cities_ordered,

            -- churn risk signal
            case
                when datediff('day', max(ordered_at), current_date()) >= {{ var('churn_lookback_days', 45) }}
                then 'high'
                when datediff('day', max(ordered_at), current_date()) >= 21
                then 'medium'
                else 'low'
            end as churn_risk_tier,

            -- active flag
            datediff('day', max(ordered_at), current_date()) <= 30 as is_active_30d,
            datediff('day', max(ordered_at), current_date()) <= 60 as is_active_60d

        from orders
        group by 1
    )

select * from customer_history
