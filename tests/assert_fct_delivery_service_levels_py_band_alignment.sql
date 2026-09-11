select *
from {{ ref('fct_delivery_service_levels_py') }}
where
    (avg_delivery_minutes <= 30 and speed_band != 'fast')
    or (avg_delivery_minutes > 30 and avg_delivery_minutes <= 45 and speed_band != 'standard')
    or (avg_delivery_minutes > 45 and avg_delivery_minutes <= 60 and speed_band != 'slow')
    or (avg_delivery_minutes > 60 and speed_band != 'severely_slow')
