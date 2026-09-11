-- Restaurant dimension sourced from SCD Type 2 snapshot.
-- Current-state restaurant attributes with embedded aggregated performance signals.

with

    snapshot as (
        select * from {{ ref('snp_restaurants') }}
        where dbt_valid_to = to_timestamp_ntz('9999-12-31 23:59:59')
    ),

    -- Rolling 30-day performance signals (for BI filtering without joins)
    recent_performance as (
        select
            restaurant_id,
            sum(total_orders)                       as orders_last_30d,
            sum(gross_revenue)                      as revenue_last_30d,
            avg(daily_avg_rating)                   as avg_rating_last_30d,
            avg(avg_prep_minutes)                   as avg_prep_minutes_last_30d,
            avg(on_time_rate)                       as on_time_rate_last_30d
        from {{ ref('fct_restaurant_revenue') }}
        where order_date >= dateadd(day, -30, current_date())
        group by 1
    ),

    cities as (
        select city_id, city_name, city_tier
        from {{ ref('stg_cities') }}
    )

select
    -- surrogate key
    {{ dbt_utils.generate_surrogate_key(['s.restaurant_id']) }}     as restaurant_key,

    -- natural key
    s.restaurant_id,
    s.restaurant_name,

    -- classification
    s.cuisine_type,
    s.restaurant_tier,
    s.is_active,
    s.is_verified,
    s.is_purely_vegetarian,

    -- geography
    s.city_id,
    ci.city_name,
    ci.city_tier,

    -- operational attributes
    s.average_prep_time_minutes,
    s.minimum_order_amount,
    s.average_cost_for_two,
    s.commission_rate,

    -- performance signals (30-day rolling)
    rp.orders_last_30d,
    rp.revenue_last_30d,
    rp.avg_rating_last_30d,
    rp.avg_prep_minutes_last_30d,
    rp.on_time_rate_last_30d,
    rp.avg_rating_last_30d >= 4.2                       as is_high_rated,

    -- onboarding date
    s.created_at,

    -- SCD2 metadata
    s.dbt_scd_id,
    s.dbt_updated_at,

    -- audit
    {{ add_audit_columns(hash_columns=['s.restaurant_id']) }}

from snapshot as s
left join recent_performance as rp
    on s.restaurant_id = rp.restaurant_id
left join cities as ci
    on s.city_id = ci.city_id

