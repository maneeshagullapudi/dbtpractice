with

source as (
    {% if var('use_seed_data', false) %}
        select * from {{ ref('seed_city_tiers') }}
    {% else %}
        select * from {{ source('zomato_geography', 'cities') }}
    {% endif %}
),

renamed as (
    select
        -- primary key
        cast(city_id as varchar)                    as city_id,

        -- city details
        city_name,
        state,
        case cast(tier as varchar)
            when '1' then 'tier_1'
            when '2' then 'tier_2'
            when '3' then 'tier_3'
            else cast(tier as varchar)
        end                                         as city_tier,

        is_metro,
        {% if var('use_seed_data', false) %}
        true                                        as is_active,
        null::date                                  as launch_date,
        current_timestamp()::timestamp_ntz          as _loaded_at
        {% else %}
        is_active,
        launch_date::date                           as launch_date,
        _fivetran_synced                            as _loaded_at
        {% endif %}

    from source
    {% if not var('use_seed_data', false) %}
    where is_active = true
    {% endif %}
)

select
    *,
    {{ add_audit_columns(
        record_source='FIVETRAN',
        src_filename='RAW.ZOMATO_GEOGRAPHY.CITIES',
        src_load_dts='_loaded_at',
        hash_columns=['city_id', 'city_tier', 'is_metro']
    ) }}
from renamed
