-- Customer LTV model. Full refresh daily — LTV predictions change as models update.
-- Combines historical actuals with a simplified predictive LTV estimate.
-- A richer LTV model would come from the ML team via Snowpark (future iteration).

with

    customers as (
        select
            customer_id,
            customer_segment,
            acquisition_channel,
            city_id,
            created_at
        from {{ ref('dim_customers') }}
    ),

    history as (
        select * from {{ ref('int_customer_order_history') }}
    ),

    cities as (
        select city_id, city_name, city_tier
        from {{ ref('stg_cities') }}
    ),

    -- Simplified LTV calculation based on:
    -- Historical AOV × expected monthly frequency × estimated active months remaining
    -- Real production would use a Pareto/NBD or BG/NBD model output
    ltv_calculation as (
        select
            h.customer_id,
            h.lifetime_gross_revenue                            as realized_ltv,
            h.average_order_value,
            h.active_months,

            -- Monthly order rate
            round(h.total_orders / nullif(h.active_months, 0), 2) as monthly_order_rate,

            -- Expected remaining active months (simplified: based on retention curve)
            case
                when h.active_months >= 12 then 18
                when h.active_months >= 6  then 9
                when h.active_months >= 2  then 4
                else 1
            end as expected_remaining_active_months,

            -- Predicted future LTV (simplification)
            round(
                h.average_order_value
                * (h.total_orders / nullif(h.active_months, 0))
                * case
                    when h.active_months >= 12 then 18
                    when h.active_months >= 6  then 9
                    when h.active_months >= 2  then 4
                    else 1
                  end,
                2
            )                                                   as predicted_future_ltv,

            -- Total predicted LTV
            round(
                h.lifetime_gross_revenue +
                (
                    h.average_order_value
                    * (h.total_orders / nullif(h.active_months, 0))
                    * case
                        when h.active_months >= 12 then 18
                        when h.active_months >= 6  then 9
                        when h.active_months >= 2  then 4
                        else 1
                      end
                ),
                2
            )                                                   as total_predicted_ltv

        from history as h
    )

select
    -- surrogate key
    {{ dbt_utils.generate_surrogate_key(['c.customer_id']) }}   as customer_key,

    -- natural key
    c.customer_id,
    c.customer_segment,
    c.acquisition_channel,
    c.city_id,
    ci.city_name,
    ci.city_tier,

    -- LTV components
    l.realized_ltv,
    l.predicted_future_ltv,
    l.total_predicted_ltv,

    -- Supporting metrics
    l.average_order_value,
    l.monthly_order_rate,
    l.active_months,
    l.expected_remaining_active_months,

    -- Behavioural
    h.total_orders,
    h.first_order_date,
    h.last_order_date,
    h.days_since_last_order,
    h.churn_risk_tier,
    h.is_active_30d,
    h.total_promo_discounts_used,

    -- Segment
    case
        when l.total_predicted_ltv >= 20000 then 'platinum'
        when l.total_predicted_ltv >= 8000  then 'gold'
        when l.total_predicted_ltv >= 2000  then 'silver'
        else 'bronze'
    end as ltv_tier,

    -- Timestamps
    c.created_at,

    -- audit
    {{ add_audit_columns(hash_columns=['c.customer_id']) }}

from customers as c
left join history as h on c.customer_id = h.customer_id
left join ltv_calculation as l on c.customer_id = l.customer_id
left join cities as ci on c.city_id = ci.city_id

