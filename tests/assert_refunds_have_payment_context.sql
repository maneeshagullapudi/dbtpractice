-- Business rule: refunded orders should retain payment context for reconciliation.
-- If a refunded order is missing payment_id or payment_method, finance reporting loses
-- the ability to tie the refund back to the original transaction.
-- Returns rows that FAIL.

select
    order_id,
    refund_date,
    refunded_amount,
    payment_id,
    payment_method,
    refund_reason
from {{ ref('fct_refunds') }}
where refunded_amount > 0
  and (payment_id is null or payment_method is null)
