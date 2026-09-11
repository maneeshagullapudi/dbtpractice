select *
from {{ ref('dim_dates_py') }}
where date_key != to_char(date_day, 'YYYYMMDD')
