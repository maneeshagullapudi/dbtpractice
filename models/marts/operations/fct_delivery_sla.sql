{{
    config(
        materialized         = 'incremental',
        incremental_strategy = 'delete+insert',
        unique_key           = ['delivery_date', 'city_id'],
        cluster_by           = ['delivery_date']
    )
}}

-- Daily SLA summary by city. One row per (delivery_date, city_id).
-- Delete+insert strategy: reprocesses last 3 days to capture late-arriving deliveries.
-- Feeds the Operations Dashboard's SLA heatmap.

with

    delivery_performance as (
        select * from {{ ref('int_delivery_performance') }}
        {% if is_incremental() %}
        where delivery_date >= dateadd(day, -3, current_date())
        {% endif %}
    )

select
    -- composite primary key
    delivery_date,
    city_id,
    city_name,
    city_tier,

    -- volume
    total_deliveries,
    successful_deliveries,
    failed_deliveries,

    -- SLA
    on_time_deliveries,
    sla_breach_deliveries,
    very_late_deliveries,
    on_time_delivery_rate,
    sla_breach_rate,

    -- delivery time percentiles
    avg_delivery_minutes,
    p50_delivery_minutes,
    p75_delivery_minutes,
    p95_delivery_minutes,

    -- audit
    {{ add_audit_columns(hash_columns=['delivery_date', 'city_id']) }}

from delivery_performance
