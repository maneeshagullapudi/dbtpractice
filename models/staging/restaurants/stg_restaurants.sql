with

source as (
    {% if var('use_seed_data', false) %}
        select * from {{ ref('raw_restaurants') }}
    {% else %}
        select * from {{ source('zomato_restaurants', 'restaurants') }}
    {% endif %}
),

renamed as (
    select
        -- primary key (integer from MySQL source — cast to varchar for consistency)
        cast(restaurant_id as varchar)              as restaurant_id,

        -- restaurant profile
        restaurant_name,
        cuisine_type,
        lower(trim(restaurant_tier))                as restaurant_tier,
        is_active,
        is_verified,                                -- FSSAI license verification status
        is_purely_vegetarian,

        -- foreign keys
        cast(city_id as varchar)                    as city_id,
        cast(area_id as varchar)                    as area_id,

        -- operational attributes
        average_prep_time_minutes,
        minimum_order_amount,
        average_cost_for_two,

        -- financial relationship
        commission_rate,

        -- quality signals (aggregated at source — more detailed in fct_restaurant_ratings)
        least(greatest(overall_rating, 0), 5)       as overall_rating,
        total_ratings_count,

        -- timestamps
        created_at::timestamp_ntz                   as created_at,
        updated_at::timestamp_ntz                   as updated_at,

        -- source metadata
        _fivetran_synced                            as _loaded_at

    from source
)

select
    *,
    {{ add_audit_columns(
        record_source='FIVETRAN',
        src_filename='RAW.ZOMATO_RESTAURANTS.RESTAURANTS',
        src_load_dts='_loaded_at',
        hash_columns=['restaurant_id', 'restaurant_tier', 'commission_rate', 'is_active', 'updated_at']
    ) }}
from renamed
