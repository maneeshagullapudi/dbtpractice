with

source as (
    {% if var('use_seed_data', false) %}
        select * from {{ ref('raw_orders') }}
    {% else %}
        select * from {{ source('zomato_transactional', 'orders') }}
    {% endif %}
),

renamed as (
    select
        -- primary key
        order_id,

        -- foreign keys
        customer_id,
        restaurant_id,
        delivery_partner_id,
        city_id,
        promo_id,

        -- order amounts (source stores in paise; already converted to rupees by Fivetran transform)
        coalesce(subtotal_amount, 0)        as subtotal_amount,
        coalesce(delivery_fee, 0)           as delivery_fee,
        coalesce(platform_fee, 0)           as platform_fee,
        coalesce(promo_discount_amount, 0)  as promo_discount_amount,
        coalesce(tax_amount, 0)             as gst_amount,
        total_amount,

        -- order status & cancellation
        lower(trim(order_status))           as order_status,
        cancellation_reason,
        is_contactless_delivery,

        -- order lifecycle timestamps (all UTC)
        ordered_at::timestamp_ntz           as ordered_at,
        accepted_at::timestamp_ntz          as accepted_at,
        prepared_at::timestamp_ntz          as prepared_at,
        picked_up_at::timestamp_ntz         as picked_up_at,
        delivered_at::timestamp_ntz         as delivered_at,
        cancelled_at::timestamp_ntz         as cancelled_at,

        -- source metadata
        _fivetran_synced                    as _loaded_at,
        updated_at::timestamp_ntz           as updated_at

    from source
)

select
    *,
    {{ add_audit_columns(
        record_source='FIVETRAN_CDC',
        src_filename='RAW.ZOMATO_TRANSACTIONAL.ORDERS',
        src_load_dts='_loaded_at',
        hash_columns=['order_id', 'order_status', 'total_amount', 'updated_at']
    ) }}
from renamed
