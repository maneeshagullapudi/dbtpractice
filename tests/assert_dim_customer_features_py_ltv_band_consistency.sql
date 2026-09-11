select *
from {{ ref('dim_customer_features_py') }}
where
    (total_predicted_ltv >= 20000 and ltv_band != 'platinum')
    or (total_predicted_ltv >= 8000 and total_predicted_ltv < 20000 and ltv_band != 'gold')
    or (total_predicted_ltv >= 2000 and total_predicted_ltv < 8000 and ltv_band != 'silver')
    or (total_predicted_ltv < 2000 and ltv_band != 'bronze')
