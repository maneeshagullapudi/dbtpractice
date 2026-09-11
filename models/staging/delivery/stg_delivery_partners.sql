with

source as (
    {% if var('use_seed_data', false) %}
        select * from {{ ref('raw_delivery_partners') }}
    {% else %}
        select * from {{ source('zomato_delivery', 'delivery_partners') }}
    {% endif %}
),

renamed as (
    select
        -- primary key
        delivery_partner_id,

        -- PII
        {{ mask_pii('partner_name') }}              as partner_name,
        {{ mask_pii('partner_phone') }}             as partner_phone,

        -- attributes
        lower(trim(vehicle_type))                   as vehicle_type,
        is_verified,
        is_active,

        -- geography
        home_city_id,

        -- performance signals
        total_deliveries_completed,
        least(greatest(average_rating, 0), 5)       as average_rating,
        acceptance_rate,

        -- timestamps
        onboarded_at::timestamp_ntz                 as onboarded_at,
        updated_at::timestamp_ntz                   as updated_at,

        -- source metadata
        _fivetran_synced                            as _loaded_at

    from source
)

select
    *,
    {{ add_audit_columns(
        record_source='FIVETRAN_MONGODB',
        src_filename='RAW.ZOMATO_DELIVERY.DELIVERY_PARTNERS',
        src_load_dts='_loaded_at',
        hash_columns=['delivery_partner_id', 'vehicle_type', 'is_active', 'average_rating', 'updated_at']
    ) }}
from renamed
