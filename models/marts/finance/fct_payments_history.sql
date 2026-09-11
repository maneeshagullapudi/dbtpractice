with payment_snapshot as (
    select *
    from {{ ref('snp_payments_ingestion_backfill') }}
),

renamed as (
    select
        -- business keys
        payment_id,
        order_id,

        -- payment attributes
        payment_status,
        payment_method,
        payment_amount,
        gateway_fee,
        payment_amount - coalesce(gateway_fee, 0) as net_amount,
        paid_at,
        settlement_date,

        -- source metadata carried from raw landing
        _loaded_at,

        -- snapshot validity
        dbt_valid_from,
        dbt_valid_to,
        dbt_updated_at,
        dbt_scd_id,

        case
            when dbt_valid_to = to_timestamp_ntz('9999-12-31 23:59:59') then true
            else false
        end as is_current_record,

        -- convenient business-date projections
        dbt_valid_from::date as valid_from_date,
        dbt_valid_to::date as valid_to_date

    from payment_snapshot
)

select
    *,
    {{ add_audit_columns(hash_columns=['payment_id', 'dbt_valid_from']) }}
from renamed
