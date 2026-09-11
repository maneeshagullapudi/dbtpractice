-- Business rule: each order must have exactly one successful payment.
-- Multiple successful payments = billing bug or gateway double-confirmation.
-- This test fires an alert to Finance team when any orders are double-charged.

select
    order_id,
    count(*) as successful_payment_count,
    sum(payment_amount) as total_charged
from {{ ref('stg_payments') }}
where payment_status = 'success'
group by 1
having count(*) > 1
