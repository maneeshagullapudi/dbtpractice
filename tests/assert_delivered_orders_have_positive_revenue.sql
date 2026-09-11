-- Business rule: delivered orders must have positive gross_revenue.
-- Zero or negative revenue on a delivered order = pricing bug or accounting error.
-- This is not a refund — refunded orders have order_status = 'refunded'.

select
    order_id,
    gross_revenue,
    order_status,
    ordered_at
from {{ ref('fct_revenue') }}
where order_status = 'delivered'
  and gross_revenue <= 0
