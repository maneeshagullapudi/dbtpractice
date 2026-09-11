-- Business rule: delivered orders must have delivery times between 1 and 180 minutes.
-- Failures indicate: timestamp bugs (timezone offset applied twice), CDC ordering issues,
-- or data entry errors (delivered_at before ordered_at).
-- Returns rows that FAIL.

select
    order_id,
    ordered_at,
    delivered_at,
    datediff('minute', ordered_at, delivered_at)    as delivery_minutes,
    case
        when datediff('minute', ordered_at, delivered_at) < 1
        then 'delivered_before_ordered'
        when datediff('minute', ordered_at, delivered_at) > 180
        then 'over_3_hours'
    end as failure_reason
from {{ ref('stg_orders') }}
where order_status = 'delivered'
  and delivered_at is not null
  and ordered_at is not null
  and (
    datediff('minute', ordered_at, delivered_at) < 1
    or datediff('minute', ordered_at, delivered_at) > 180
  )
