with

source as (
    {% if var('use_seed_data', false) %}
        select * from {{ ref('raw_deliveries') }}
    {% else %}
        select * from {{ source('zomato_delivery', 'deliveries') }}
    {% endif %}
),

renamed as (
    select
        -- primary key
        delivery_id,

        -- foreign keys
        order_id,
        delivery_partner_id,

        -- status
        lower(trim(delivery_status))                as delivery_status,
        failure_reason,

        -- timestamps (all UTC)
        assigned_at::timestamp_ntz                  as assigned_at,
        en_route_restaurant_at::timestamp_ntz       as en_route_restaurant_at,
        arrived_restaurant_at::timestamp_ntz        as arrived_restaurant_at,
        picked_up_at::timestamp_ntz                 as picked_up_at,
        delivered_at::timestamp_ntz                 as delivered_at,

        -- geospatial (distances in km, not raw GPS coordinates)
        delivery_distance_km,
        route_distance_km,                          -- actual route vs straight-line

        -- source metadata
        _fivetran_synced                            as _loaded_at,
        updated_at::timestamp_ntz                   as updated_at

    from source
)

select
    *,
    {{ add_audit_columns(
        record_source='FIVETRAN_MONGODB',
        src_filename='RAW.ZOMATO_DELIVERY.DELIVERIES',
        src_load_dts='_loaded_at',
        hash_columns=['delivery_id', 'delivery_status', 'delivered_at', 'updated_at']
    ) }}
from renamed
