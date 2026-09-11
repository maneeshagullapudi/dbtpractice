select *
from {{ ref('dim_restaurant_health_py') }}
where
    needs_attention = true
    and health_tier in ('excellent', 'healthy')
    and coalesce(avg_rating_last_30d, 5) >= 4.0
    and coalesce(on_time_rate_last_30d, 1) >= 0.85
