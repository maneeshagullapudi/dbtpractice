-- Small reference dimension: payment methods with gateway fee rates.
-- Rebuilt as a full table on every run (< 20 rows, negligible cost).

with

    payment_methods as (
        select * from {{ ref('stg_payments') }}
    ),

    -- Derive payment method attributes from transactional data
    -- since the source dim table has incomplete coverage
    payment_method_stats as (
        select
            payment_method,
            count(distinct payment_id)              as total_transactions,
            avg(gateway_fee / nullif(payment_amount, 0)) as avg_fee_rate,
            min(paid_at)                            as first_seen_at
        from payment_methods
        where payment_status = 'success'
        group by 1
    )

select
    {{ dbt_utils.generate_surrogate_key(['payment_method']) }}  as payment_method_key,
    payment_method,

    -- Human-readable label
    case payment_method
        when 'upi'              then 'UPI (Unified Payments Interface)'
        when 'credit_card'      then 'Credit Card'
        when 'debit_card'       then 'Debit Card'
        when 'net_banking'      then 'Net Banking'
        when 'wallet'           then 'Digital Wallet (Paytm/PhonePe)'
        when 'cash_on_delivery' then 'Cash on Delivery'
        when 'emi'              then 'EMI (No Cost / Low Cost)'
        when 'pay_later'        then 'Buy Now Pay Later'
        else payment_method
    end as payment_method_label,

    -- Grouping
    case payment_method
        when 'upi'              then 'digital'
        when 'credit_card'      then 'card'
        when 'debit_card'       then 'card'
        when 'net_banking'      then 'digital'
        when 'wallet'           then 'digital'
        when 'cash_on_delivery' then 'cash'
        when 'emi'              then 'credit'
        when 'pay_later'        then 'credit'
        else 'other'
    end as payment_method_group,

    round(avg_fee_rate, 4)                          as avg_gateway_fee_rate,
    total_transactions,
    first_seen_at,

    -- audit
    {{ add_audit_columns(hash_columns=['payment_method']) }}

from payment_method_stats
