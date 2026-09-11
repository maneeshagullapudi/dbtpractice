with

source as (
    {% if var('use_seed_data', false) %}
        select * from {{ ref('raw_customers') }}
    {% else %}
        select * from {{ source('zomato_customers', 'customers') }}
    {% endif %}
),

renamed as (
    select
        -- primary key
        customer_id,

        -- attributes (PII masked in non-prod via macro)
        customer_name,
        {{ mask_pii('customer_email') }}        as customer_email,
        {{ mask_pii('customer_phone') }}        as customer_phone,

        -- foreign keys
        city_id,

        -- customer profile
        acquisition_channel,
        customer_segment,
        is_active,
        is_pro_subscriber,                      -- Zomato Pro subscription flag

        -- account timestamps
        created_at::timestamp_ntz               as created_at,
        last_login_at::timestamp_ntz            as last_login_at,

        -- source metadata
        _fivetran_synced                        as _loaded_at,
        updated_at::timestamp_ntz               as updated_at

    from source
)

select
    *,
    {{ add_audit_columns(
        record_source='FIVETRAN_POSTGRESQL',
        src_filename='RAW.ZOMATO_CUSTOMERS.CUSTOMERS',
        src_load_dts='_loaded_at',
        hash_columns=['customer_id', 'customer_segment', 'is_active', 'is_pro_subscriber', 'updated_at']
    ) }}
from renamed
