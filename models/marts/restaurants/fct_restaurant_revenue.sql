{% if target.name == 'stage' %}
{{
    config(
        materialized         = 'incremental',
        incremental_strategy = 'delete+insert',
        unique_key           = ['order_date', 'restaurant_id'],
        cluster_by           = ['order_date']
    )
}}
{% else %}
{{
    config(
        materialized         = 'incremental',
        incremental_strategy = 'merge',
        unique_key           = ['order_date', 'restaurant_id'],
        cluster_by           = ['order_date']
    )
}}
{% endif %}

-- Restaurant daily revenue fact. One row per (restaurant_id, order_date).
-- Source: int_restaurant_metrics (which joins orders to ratings).

with

    restaurant_metrics as (
        select * from {{ ref('int_restaurant_metrics') }}
        {% if is_incremental() %}
        where order_date >= dateadd(day, -{{ var('incremental_buffer_hours', 3) / 24 | round(0) | int + 1 }}, current_date())
        {% endif %}
    ),

    restaurant_history as (
        select
            restaurant_id,
            restaurant_name,
            is_active,
            minimum_order_amount,
            average_prep_time_minutes,
            dbt_valid_from,
            dbt_valid_to
        from {{ ref('snp_restaurants') }}
    )

select
    -- composite primary key
    rm.order_date,
    rm.restaurant_id,

    -- restaurant attributes (denormalized)
    r.restaurant_name,
    rm.cuisine_type,
    rm.restaurant_tier,
    rm.city_id,
    rm.city_name,

    -- volume metrics
    rm.total_orders,
    rm.unique_customers,

    -- revenue metrics
    rm.gross_revenue,
    rm.platform_commission_earned,
    rm.promo_discounts_absorbed,
    rm.gross_revenue - rm.platform_commission_earned    as restaurant_net_revenue,
    rm.avg_order_value,
    rm.avg_items_per_order,

    -- quality metrics
    rm.daily_avg_rating,
    rm.daily_rating_count,
    rm.daily_negative_rating_count,

    -- operations metrics
    rm.avg_delivery_minutes,
    rm.avg_prep_minutes,
    rm.on_time_order_count,
    rm.sla_breach_order_count,
    round(
        rm.on_time_order_count / nullif(rm.total_orders, 0),
        4
    )                                                   as on_time_rate,

    -- audit
    {{ add_audit_columns(hash_columns=['rm.restaurant_id', 'rm.order_date']) }}

from restaurant_metrics as rm
left join restaurant_history as r
    on rm.restaurant_id = r.restaurant_id
    and rm.order_date >= r.dbt_valid_from::date
    and rm.order_date < r.dbt_valid_to::date
