with failing_rows as (
    select
        'snp_restaurants' as snapshot_name,
        cast(restaurant_id as varchar) as business_key,
        count(*) as current_row_count
    from {{ ref('snp_restaurants') }}
    where dbt_valid_to = to_timestamp_ntz('9999-12-31 23:59:59')
    group by 1, 2
    having count(*) > 1

    union all

    select
        'snp_customers' as snapshot_name,
        cast(customer_id as varchar) as business_key,
        count(*) as current_row_count
    from {{ ref('snp_customers') }}
    where dbt_valid_to = to_timestamp_ntz('9999-12-31 23:59:59')
    group by 1, 2
    having count(*) > 1

    union all

    select
        'snp_delivery_partners' as snapshot_name,
        cast(delivery_partner_id as varchar) as business_key,
        count(*) as current_row_count
    from {{ ref('snp_delivery_partners') }}
    where dbt_valid_to = to_timestamp_ntz('9999-12-31 23:59:59')
    group by 1, 2
    having count(*) > 1

    union all

    select
        'snp_payments_check' as snapshot_name,
        cast(payment_id as varchar) as business_key,
        count(*) as current_row_count
    from {{ ref('snp_payments_check') }}
    where dbt_valid_to = to_timestamp_ntz('9999-12-31 23:59:59')
    group by 1, 2
    having count(*) > 1

    union all

    select
        'snp_payments_ingestion_backfill' as snapshot_name,
        cast(payment_id as varchar) as business_key,
        count(*) as current_row_count
    from {{ ref('snp_payments_ingestion_backfill') }}
    where dbt_valid_to = to_timestamp_ntz('9999-12-31 23:59:59')
    group by 1, 2
    having count(*) > 1

    union all

    select
        'snp_support_tickets' as snapshot_name,
        cast(ticket_id as varchar) as business_key,
        count(*) as current_row_count
    from {{ ref('snp_support_tickets') }}
    where dbt_valid_to = to_timestamp_ntz('9999-12-31 23:59:59')
    group by 1, 2
    having count(*) > 1
)

select *
from failing_rows
