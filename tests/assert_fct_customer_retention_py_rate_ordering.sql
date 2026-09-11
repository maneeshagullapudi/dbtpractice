select *
from {{ ref('fct_customer_retention_py') }}
where
    retention_30d_rate > retention_60d_rate
    or retention_60d_rate > retention_90d_rate
