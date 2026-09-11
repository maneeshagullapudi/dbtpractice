-- Delivery partner dimension. One row per delivery partner.
-- Current-state attributes sourced from the SCD Type 2 partner snapshot,
-- enriched with rolling 30-day performance metrics.

with

    partners as (
        select *
        from {{ ref('snp_delivery_partners') }}
        where dbt_valid_to = to_timestamp_ntz('9999-12-31 23:59:59')
    ),

    recent_deliveries as (
        select
            delivery_partner_id,
            count(distinct delivery_id)                         as deliveries_last_30d,
            count_if(is_on_time_delivery = true)                as on_time_deliveries_last_30d,
            avg(total_delivery_minutes)                         as avg_delivery_minutes_last_30d,
            round(
                count_if(is_on_time_delivery = true) /
                nullif(count_if(delivery_status = 'delivered'), 0),
                4
            )                                                   as on_time_rate_last_30d
        from {{ ref('fct_deliveries') }}
        where order_date >= dateadd(day, -30, current_date())
        group by 1
    ),

    cities as (
        select city_id, city_name
        from {{ ref('stg_cities') }}
    )

select
    -- surrogate key
    {{ dbt_utils.generate_surrogate_key(['p.delivery_partner_id']) }} as delivery_partner_key,

    -- natural key
    p.delivery_partner_id,

    -- profile (PII masked via staging before snapshotting)
    p.partner_name,
    p.vehicle_type,
    p.is_verified,
    p.is_active,

    -- geography
    p.home_city_id,
    ci.city_name                                                as home_city_name,

    -- lifetime stats
    p.total_deliveries_completed,
    p.average_rating                                            as lifetime_avg_rating,
    p.acceptance_rate                                           as lifetime_acceptance_rate,

    -- 30-day rolling stats
    coalesce(rd.deliveries_last_30d, 0)                        as deliveries_last_30d,
    rd.on_time_rate_last_30d,
    rd.avg_delivery_minutes_last_30d,

    -- onboarding
    p.onboarded_at,

    -- audit
    {{ add_audit_columns(hash_columns=['p.delivery_partner_id']) }}

from partners as p
left join recent_deliveries as rd
    on p.delivery_partner_id = rd.delivery_partner_id
left join cities as ci
    on p.home_city_id = ci.city_id

