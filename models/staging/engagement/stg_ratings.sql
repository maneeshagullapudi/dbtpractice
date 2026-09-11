with

source as (
    {% if var('use_seed_data', false) %}
        select * from {{ ref('raw_ratings') }}
    {% else %}
        select * from {{ source('zomato_engagement', 'ratings') }}
    {% endif %}
),

renamed as (
    select
        -- primary key
        rating_id,

        -- foreign keys
        order_id,
        customer_id,
        restaurant_id,
        delivery_partner_id,

        -- ratings (1-5 scale)
        food_rating,
        delivery_rating,
        overall_rating,

        -- derived flags
        overall_rating >= 4                         as is_positive,
        overall_rating < 3                          as is_negative,

        -- timing
        rated_at::timestamp_ntz                     as rated_at,

        -- source metadata
        _airbyte_extracted_at::timestamp_ntz        as _loaded_at

    from source
)

select
    *,
    {{ add_audit_columns(
        record_source='AIRBYTE',
        src_filename='RAW.ZOMATO_ENGAGEMENT.RATINGS',
        src_load_dts='_loaded_at',
        hash_columns=['rating_id', 'food_rating', 'delivery_rating', 'overall_rating']
    ) }}
from renamed
