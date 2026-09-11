with

source as (
    {% if var('use_seed_data', false) %}
        select * from {{ ref('raw_support_tickets') }}
    {% else %}
        select * from {{ source('zomato_support', 'support_tickets') }}
    {% endif %}
),

renamed as (
    select
        -- primary key
        ticket_id,

        -- foreign keys
        customer_id,
        order_id,                   -- NULL for non-order tickets
        assigned_agent_id,

        -- ticket details
        lower(trim(ticket_category))                as ticket_category,
        lower(trim(ticket_status))                  as ticket_status,
        lower(trim(priority))                       as priority,
        lower(trim(resolution_code))                as resolution_code,

        -- satisfaction
        csat_score,
        csat_score >= 4                             as is_positive_csat,

        -- timing (UTC)
        created_at::timestamp_ntz                   as created_at,
        first_response_at::timestamp_ntz            as first_response_at,
        resolved_at::timestamp_ntz                  as resolved_at,

        -- derived SLA metrics (minutes)
        datediff('minute', created_at, first_response_at)   as minutes_to_first_response,
        datediff('minute', created_at, resolved_at)         as minutes_to_resolution,

        -- source metadata
        _airbyte_extracted_at::timestamp_ntz        as _loaded_at,
        updated_at::timestamp_ntz                   as updated_at

    from source
)

select
    *,
    {{ add_audit_columns(
        record_source='AIRBYTE',
        src_filename='RAW.ZOMATO_SUPPORT.SUPPORT_TICKETS',
        src_load_dts='_loaded_at',
        hash_columns=['ticket_id', 'ticket_status', 'csat_score', 'resolved_at', 'updated_at']
    ) }}
from renamed
