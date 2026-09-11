with

source as (
    {% if var('use_seed_data', false) %}
        select * from {{ ref('raw_promo_redemptions') }}
    {% else %}
        select * from {{ source('zomato_promotions', 'promo_redemptions') }}
    {% endif %}
),

renamed as (
    select
        -- primary key
        redemption_id,

        -- foreign keys
        order_id,
        promo_id,
        customer_id,

        -- redemption details
        discount_amount_applied,
        lower(trim(redemption_status))              as redemption_status,
        failure_reason,

        -- timing
        redeemed_at::timestamp_ntz                  as redeemed_at,

        -- source metadata
        _fivetran_synced                            as _loaded_at

    from source
)

select
    *,
    {{ add_audit_columns(
        record_source='FIVETRAN',
        src_filename='RAW.ZOMATO_PROMOTIONS.PROMO_REDEMPTIONS',
        src_load_dts='_loaded_at',
        hash_columns=['redemption_id', 'redemption_status', 'redeemed_at']
    ) }}
from renamed
