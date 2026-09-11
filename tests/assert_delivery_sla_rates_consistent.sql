-- Business rule: SLA rates should align with their underlying counts.
-- This catches aggregation drift in fct_delivery_sla or bad denominator handling.
-- Returns rows that FAIL.

select
    delivery_date,
    city_id,
    total_deliveries,
    on_time_deliveries,
    sla_breach_deliveries,
    on_time_delivery_rate,
    sla_breach_rate,
    round(on_time_deliveries / nullif(total_deliveries, 0), 4) as expected_on_time_delivery_rate,
    round(sla_breach_deliveries / nullif(total_deliveries, 0), 4) as expected_sla_breach_rate
from {{ ref('fct_delivery_sla') }}
where total_deliveries > 0
  and (
    coalesce(on_time_delivery_rate, -1) != coalesce(round(on_time_deliveries / nullif(total_deliveries, 0), 4), -1)
    or coalesce(sla_breach_rate, -1) != coalesce(round(sla_breach_deliveries / nullif(total_deliveries, 0), 4), -1)
  )
