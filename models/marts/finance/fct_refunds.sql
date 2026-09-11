{{
    config(
        materialized         = 'incremental',
        incremental_strategy = 'delete+insert',
        unique_key           = ['refund_date', 'order_id'],
        cluster_by           = ['refund_date']
    )
}}

-- Refund events joined to orders and payments for Finance reconciliation.
-- Uses delete+insert by refund_date because refund status can change (pending → settled).
-- Reprocesses last 7 days to catch late refund status updates from Razorpay.

with

    orders as (
        select * from {{ ref('int_orders_enriched') }}
        where order_status = 'refunded'
        {% if is_incremental() %}
        and order_date >= dateadd(day, -7, current_date())
        {% endif %}
    ),

    payments as (
        select
            order_id,
            payment_id,
            payment_method,
            payment_amount,
            paid_at
        from {{ ref('stg_payments') }}
        where payment_status in ('success', 'refunded')
    )

select
    -- composite primary key
    o.order_date                                            as refund_date,
    o.order_id,

    -- foreign keys
    o.customer_id,
    o.restaurant_id,
    o.city_id,

    -- descriptive
    o.city_name,
    o.cuisine_type,
    o.restaurant_tier,
    o.customer_segment,
    o.cancellation_reason                                   as refund_reason,

    -- amounts
    o.total_amount                                          as refunded_amount,
    o.platform_commission                                   as lost_commission,
    o.delivery_fee                                          as delivery_fee_refunded,

    -- payment context
    p.payment_method,
    p.payment_id,
    p.paid_at,

    -- timing
    o.ordered_at,
    o.cancelled_at                                          as refund_initiated_at,
    datediff('hour', o.cancelled_at, current_timestamp())  as hours_since_refund_initiated,

    -- audit
    {{ add_audit_columns(hash_columns=['o.order_id', 'o.order_date']) }}

from orders as o
left join payments as p
    on o.order_id = p.order_id
