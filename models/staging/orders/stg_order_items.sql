with

source as (
    {% if var('use_seed_data', false) %}
        select * from {{ ref('raw_order_items') }}
    {% else %}
        select * from {{ source('zomato_transactional', 'order_items') }}
    {% endif %}
),

renamed as (
    select
        -- primary key
        order_item_id,

        -- foreign keys
        order_id,
        menu_item_id,
        restaurant_id,

        -- item details
        item_name,
        item_category,
        is_vegetarian,

        -- quantities and pricing
        quantity,
        unit_price,
        quantity * unit_price                   as item_subtotal,
        customization_price_delta,

        -- source metadata
        _fivetran_synced                        as _loaded_at,
        created_at::timestamp_ntz               as created_at

    from source
)

select
    *,
    {{ add_audit_columns(
        record_source='FIVETRAN_CDC',
        src_filename='RAW.ZOMATO_TRANSACTIONAL.ORDER_ITEMS',
        src_load_dts='_loaded_at',
        hash_columns=['order_item_id', 'quantity', 'unit_price', 'item_subtotal']
    ) }}
from renamed
