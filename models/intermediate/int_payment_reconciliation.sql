-- Payment reconciliation: joins payments to orders and flags mismatches.
-- Used by Finance team for daily reconciliation reporting.
-- Mismatch tolerance: ₹1 (accounting for rounding in gateway fee calculations).

with

    payments as (
        select
            payment_id,
            order_id,
            payment_status,
            payment_method,
            payment_amount,
            gateway_fee,
            net_amount,
            paid_at,
            settlement_date
        from {{ ref('stg_payments') }}
        where payment_status = 'success'
    ),

    orders as (
        select
            order_id,
            customer_id,
            restaurant_id,
            total_amount                            as order_total_amount,
            order_status,
            ordered_at,
            order_date
        from {{ ref('int_orders_enriched') }}
    ),

    -- One successful payment per order (should be the case — tests verify this)
    reconciled as (
        select
            p.payment_id,
            p.order_id,
            o.customer_id,
            o.restaurant_id,

            -- amounts
            p.payment_amount,
            p.gateway_fee,
            p.net_amount,
            o.order_total_amount,

            -- reconciliation variance
            p.payment_amount - o.order_total_amount     as amount_variance,
            abs(p.payment_amount - o.order_total_amount) as abs_amount_variance,
            abs(p.payment_amount - o.order_total_amount) <= 1.0 as is_reconciled,

            -- payment details
            p.payment_method,
            p.paid_at,
            p.settlement_date,

            -- order details
            o.order_status,
            o.ordered_at,
            o.order_date,

            -- flags for Finance reporting
            case
                when abs(p.payment_amount - o.order_total_amount) > 1.0 then 'mismatch'
                when o.order_total_amount is null then 'orphan_payment'
                else 'reconciled'
            end as reconciliation_status

        from payments as p
        left join orders as o
            on p.order_id = o.order_id
    )

select * from reconciled
