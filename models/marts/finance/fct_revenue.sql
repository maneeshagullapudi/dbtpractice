{% if target.name == 'stage' %}
{{
    config(
        materialized         = 'incremental',
        incremental_strategy = 'merge',
        unique_key           = ['order_id'],
        cluster_by           = ['ordered_at::date', 'city_id'],
        on_schema_change     = 'append_new_columns'
    )
}}
{% else %}
{{
    config(
        materialized         = 'incremental',
        incremental_strategy = 'microbatch',
        event_time           = 'ordered_at',
        begin                = '2020-01-01',
        batch_size           = 'year',
        lookback             = 1,
        unique_key           = 'order_id',
        cluster_by           = ['ordered_at::date', 'city_id'],
        on_schema_change     = 'append_new_columns'
    )
}}
{% endif %}





with

    orders as (
        select * from {{ ref('int_orders_enriched') }}
    ),

    payments as (
        select
            order_id,
            payment_method,
            payment_amount,
            is_reconciled,
            paid_at
        from {{ ref('int_payment_reconciliation') }}
        where reconciliation_status != 'orphan_payment'
    )

select
    -- primary key
    o.order_id,

    -- foreign keys (for BI joins without going to dimensions)
    o.customer_id,
    o.restaurant_id,
    o.delivery_partner_id,
    o.city_id,
    o.promo_id,

    -- descriptive attributes (denormalized for BI performance)
    o.city_name,
    case cast(o.city_tier as varchar)
        when '1' then 'tier_1'
        when '2' then 'tier_2'
        when '3' then 'tier_3'
        else cast(o.city_tier as varchar)
    end as city_tier,
    o.is_metro,
    o.cuisine_type,
    o.restaurant_tier,
    o.customer_segment,
    o.acquisition_channel,

    -- order status
    o.order_status,
    o.cancellation_reason,
    o.is_on_time_delivery,
    o.is_sla_breach,

    -- revenue components
    cast(o.subtotal_amount as number(38, 6))               as subtotal_amount,
    cast(o.delivery_fee as number(38, 6))                  as delivery_fee,
    cast(o.platform_fee as number(38, 6))                  as platform_fee,
    cast(o.gst_amount as number(38, 6))                    as gst_amount,
    cast(o.promo_discount_amount as number(38, 6))         as promo_discount_amount,
    cast(o.total_amount as number(38, 6))                  as gross_revenue,
    cast(o.total_amount as number(38, 6)) - cast(o.promo_discount_amount as number(38, 6)) as net_revenue,

    cast(o.platform_commission as number(38, 6))           as platform_commission,
    cast(o.delivery_fee as number(38, 6))                  as delivery_fee_revenue,

    -- order composition
    cast(o.total_items as number(38, 0))                   as total_items,
    cast(o.distinct_item_categories as number(38, 0))      as distinct_item_categories,

    -- payment
    p.payment_method,
    p.is_reconciled,
    p.paid_at,

    -- date dimensions (pre-computed for BI partition pruning)
    o.order_date,
    o.order_week,
    o.order_month,
    o.day_of_week_num,
    o.order_hour,
    o.is_weekend_order,

    -- timestamps
    o.ordered_at,
    o.delivered_at,
    o.total_delivery_minutes,
    o.updated_at,

    -- audit
    {{ add_audit_columns(hash_columns=['o.order_id']) }}

from orders as o
left join payments as p
    on o.order_id = p.order_id
