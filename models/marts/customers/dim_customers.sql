-- Customer dimension sourced from the SCD Type 2 snapshot.
-- Selects the current row to provide the current customer state.
-- Use this for current-state BI reporting. For history, query snp_customers directly.

with

    snapshot as (
        select * from {{ ref('snp_customers') }}
        where dbt_valid_to = to_timestamp_ntz('9999-12-31 23:59:59')
    ),

    customer_history as (
        select * from {{ ref('int_customer_order_history') }}
    ),

    final as (
        select
            -- surrogate key
            {{ dbt_utils.generate_surrogate_key(['s.customer_id']) }}   as customer_key,

            -- natural key
            s.customer_id,

            -- PII (still masked via macro — snapshot preserves masking from staging)
            s.customer_name,
            s.customer_email,
            s.customer_phone,

            -- profile
            s.city_id,
            s.acquisition_channel,
            s.customer_segment,
            s.is_active,
            s.is_pro_subscriber,

            -- behavioural attributes from order history
            h.first_order_date,
            h.first_order_month,
            h.last_order_date,
            h.days_since_last_order,
            h.total_orders,
            h.lifetime_gross_revenue,
            h.average_order_value,
            h.churn_risk_tier,
            h.is_active_30d,
            h.is_active_60d,
            h.distinct_cuisines_ordered,
            h.distinct_restaurants_ordered,

            -- account dates
            s.created_at,

            -- SCD2 metadata
            s.dbt_scd_id,
            s.dbt_updated_at

        from snapshot as s
        left join customer_history as h
            on s.customer_id = h.customer_id
    )

select
    *,
    {{ add_audit_columns(hash_columns=['customer_id']) }}
from final

