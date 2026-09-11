-- Business rule: net_revenue should equal gross_revenue minus promo_discount_amount.
-- Failures usually mean a modeling regression in finance logic or unexpected null handling.
-- Returns rows that FAIL.

select
    order_id,
    gross_revenue,
    promo_discount_amount,
    net_revenue,
    gross_revenue - promo_discount_amount as expected_net_revenue
from {{ ref('fct_revenue') }}
where coalesce(net_revenue, 0) != coalesce(gross_revenue - promo_discount_amount, 0)
