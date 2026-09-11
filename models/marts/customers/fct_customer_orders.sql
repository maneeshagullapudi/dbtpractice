{{
    config(
        materialized         = 'incremental',
        incremental_strategy = 'merge',
        unique_key           = 'order_id',
        cluster_by           = ['ordered_at::date']
    )
}}

-- Customer-focused order fact. Optimized for cohort analysis and retention reporting.
-- Includes acquisition/order sequence context so retention calculations
-- don't require self-joins in BI.

with

    orders as (
        select * from {{ ref('int_orders_enriched') }}
        where order_status in ('delivered', 'cancelled', 'refunded')
        {% if is_incremental() %}
        and updated_at >= (
            select dateadd(hour, -{{ var('incremental_buffer_hours', 3) }}, max(t.updated_at))
            from {{ this }} as t
        )
        {% endif %}
    ),

    customer_history as (
        select
            customer_id,
            first_order_date,
            first_order_month,
            total_orders
        from {{ ref('int_customer_order_history') }}
    )

select
    -- primary key
    o.order_id,

    -- customer context
    o.customer_id,
    o.customer_segment,
    o.acquisition_channel,
    o.is_pro_subscriber,

    -- cohort analysis fields
    h.first_order_date,
    h.first_order_month,
    cast(datediff('day', h.first_order_date, o.order_date) as number(38, 0))     as days_since_first_order,
    cast(datediff('month', h.first_order_month, o.order_month) as number(38, 0)) as months_since_acquisition,

    -- order sequence (used for first-order vs repeat analysis)
    cast(row_number() over (
        partition by o.customer_id
        order by o.ordered_at
    ) as number(38, 0))                                                           as customer_order_number,

    -- geography
    o.city_id,
    o.city_name,
    o.city_tier,

    -- order details
    o.restaurant_id,
    o.cuisine_type,
    o.restaurant_tier,
    o.order_status,
    o.total_amount,
    o.promo_discount_amount,
    o.total_items,

    -- timing
    o.ordered_at,
    o.delivered_at,
    o.order_date,
    o.order_month,
    o.is_weekend_order,
    o.total_delivery_minutes,
    o.updated_at,

    -- audit
    {{ add_audit_columns(hash_columns=['order_id']) }}

from orders as o
left join customer_history as h
    on o.customer_id = h.customer_id

