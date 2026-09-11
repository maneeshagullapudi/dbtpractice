with

source as (
    {% if var('use_seed_data', false) %}
        select * from {{ ref('raw_payments') }}
    {% else %}
        select * from {{ source('zomato_payments', 'payments') }}
    {% endif %}
),

renamed as (
    select
        -- primary key
        payment_id,

        -- foreign keys
        order_id,

        -- payment details
        lower(trim(payment_status))                 as payment_status,
        lower(trim(payment_method))                 as payment_method,

        -- amounts (in rupees)
        payment_amount,
        coalesce(gateway_fee, 0)                    as gateway_fee,
        payment_amount - coalesce(gateway_fee, 0)   as net_amount,

        -- timing (UTC)
        paid_at::timestamp_ntz                      as paid_at,
        settlement_date::date                       as settlement_date,

        -- source metadata
        _loaded_at::timestamp_ntz                   as _loaded_at

    from source
)

select
    *,
    {{ add_audit_columns(
        record_source='KAFKA',
        src_filename='RAW.ZOMATO_PAYMENTS.PAYMENTS',
        src_load_dts='_loaded_at',
        hash_columns=['payment_id', 'payment_status', 'payment_amount']
    ) }}
from renamed
