with

source as (
    {% if var('use_seed_data', false) %}
        select * from {{ ref('raw_promotions') }}
    {% else %}
        select * from {{ source('zomato_promotions', 'promotions') }}
    {% endif %}
),

renamed as (
    select
        -- primary key
        promo_id,

        -- promo details
        upper(trim(promo_code))                     as promo_code,
        promo_name,
        promo_description,
        lower(trim(discount_type))                  as discount_type,
        discount_value,
        lower(trim(promo_funder))                   as promo_funder,

        -- eligibility rules
        min_order_value,
        max_redemptions,
        max_redemptions_per_customer,
        is_new_customer_only,
        {% if var('use_seed_data', false) %}
        null::variant                               as eligible_cuisine_types,
        {% else %}
        eligible_cuisine_types,
        {% endif %}

        -- validity window (UTC dates)
        valid_from::date                            as valid_from,
        valid_to::date                              as valid_to,
        is_active,

        -- source metadata
        _fivetran_synced                            as _loaded_at,
        updated_at::timestamp_ntz                   as updated_at

    from source
)

select
    *,
    {{ add_audit_columns(
        record_source='FIVETRAN',
        src_filename='RAW.ZOMATO_PROMOTIONS.PROMOTIONS',
        src_load_dts='_loaded_at',
        hash_columns=['promo_id', 'is_active', 'discount_value', 'updated_at']
    ) }}
from renamed
