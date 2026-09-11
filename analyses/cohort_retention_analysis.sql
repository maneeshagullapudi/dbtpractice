-- Ad-hoc cohort retention analysis.
-- NOT deployed via dbt build — run manually or via dbt compile + Snowflake.
-- Used by the Product team for monthly retention reports.

-- Computes D30, D60, D90 retention by acquisition month.
-- Retention = % of cohort members who placed at least one order in the target window.

with

    cohorts as (
        select
            customer_id,
            first_order_month
        from {{ ref('int_customer_order_history') }}
    ),

    monthly_orders as (
        select
            customer_id,
            date_trunc('month', ordered_at)::date as order_month
        from {{ ref('stg_orders') }}
        where order_status = 'delivered'
        group by 1, 2
    ),

    retention_base as (
        select
            c.first_order_month                                 as cohort_month,
            mo.order_month,
            count(distinct c.customer_id)                       as active_customers,
            datediff('month', c.first_order_month, mo.order_month) as months_since_acquisition
        from cohorts as c
        inner join monthly_orders as mo
            on c.customer_id = mo.customer_id
        where mo.order_month >= c.first_order_month
        group by 1, 2, 4
    ),

    cohort_sizes as (
        select
            first_order_month as cohort_month,
            count(distinct customer_id) as cohort_size
        from cohorts
        group by 1
    )

select
    rb.cohort_month,
    cs.cohort_size,
    rb.months_since_acquisition,
    rb.active_customers,
    round(rb.active_customers / cs.cohort_size, 4)     as retention_rate,

    -- Convenience columns for pivot reports
    case
        when rb.months_since_acquisition = 0 then 'M0 (Acquisition)'
        when rb.months_since_acquisition = 1 then 'M1 (D30 window)'
        when rb.months_since_acquisition = 2 then 'M2 (D60 window)'
        when rb.months_since_acquisition = 3 then 'M3 (D90 window)'
        when rb.months_since_acquisition = 6 then 'M6 (6-month)'
        when rb.months_since_acquisition = 12 then 'M12 (12-month)'
        else 'M' || rb.months_since_acquisition
    end as retention_window_label

from retention_base as rb
inner join cohort_sizes as cs
    on rb.cohort_month = cs.cohort_month
where rb.months_since_acquisition <= 12
order by
    rb.cohort_month,
    rb.months_since_acquisition
