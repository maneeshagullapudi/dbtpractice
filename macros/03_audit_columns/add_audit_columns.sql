{% macro add_audit_columns(
    record_source='dbt_transformation',
    src_filename=none,
    src_load_dts=none,
    hash_columns=[]
) %}
{#
  Appends standardized audit and source-lineage columns to any SELECT.

  Parameters:
    record_source  : source system name (e.g. 'FIVETRAN_POSTGRESQL', 'AIRBYTE', 'KAFKA')
    src_filename   : fully-qualified source table path (e.g. 'RAW.ZOMATO_CUSTOMERS.CUSTOMERS')
    src_load_dts   : SQL expression for the source load timestamp; defaults to current_timestamp()
    hash_columns   : list of column names to hash for SRC_HASH

  Adds eight columns:
    _dbt_loaded_at      TIMESTAMP_NTZ  - when dbt wrote this row
    _dbt_invocation_id  VARCHAR        - unique ID of the dbt run
    _dbt_run_started_at TIMESTAMP_NTZ  - when the overall dbt run started
    _dbt_model_id       VARCHAR        - fully qualified dbt model node ID
    src_load_dts        TIMESTAMP_NTZ  - source system load timestamp
    src_filename        VARCHAR        - source table/file path
    src_record_source   VARCHAR        - source system identifier
    src_batch_id        VARCHAR        - dbt invocation ID (batch reference)
    src_hash            VARCHAR        - surrogate key hash of key columns

  Usage in staging (with source metadata):
    {{ add_audit_columns(
        record_source='FIVETRAN_POSTGRESQL',
        src_filename='RAW.ZOMATO_CUSTOMERS.CUSTOMERS',
        src_load_dts='_loaded_at',
        hash_columns=['customer_id', 'updated_at']
    ) }}

  Usage in marts (defaults):
    {{ add_audit_columns(hash_columns=['order_id']) }}
#}

    current_timestamp()::timestamp_ntz                  as _dbt_loaded_at,
    '{{ invocation_id }}'::varchar                      as _dbt_invocation_id,
    cast('{{ run_started_at }}' as timestamp_ntz)       as _dbt_run_started_at,
    '{{ model.unique_id }}'::varchar                    as _dbt_model_id,

    {% if src_load_dts %}
    {{ src_load_dts }}::timestamp_ntz                   as src_load_dts,
    {% else %}
    current_timestamp()::timestamp_ntz                  as src_load_dts,
    {% endif %}
    '{{ src_filename if src_filename else model.unique_id }}'::varchar   as src_filename,
    '{{ record_source }}'::varchar                      as src_record_source,
    '{{ invocation_id }}'::varchar                      as src_batch_id,
    {% if hash_columns %}
    {{ dbt_utils.generate_surrogate_key(hash_columns) }} as src_hash
    {% else %}
    cast(null as varchar)                               as src_hash
    {% endif %}

{% endmacro %}
