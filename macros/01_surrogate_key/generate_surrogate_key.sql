{% macro generate_surrogate_key_safe(field_list) %}
{#
  Generates a stable MD5 surrogate key from one or more fields.
  Coalesces each field to 'UNKNOWN' before hashing to prevent NULL propagation.
  A NULL in any input field would produce a NULL surrogate key, which breaks
  not_null tests on primary keys.

  Use dbt_utils.generate_surrogate_key for the standard case (no NULLable inputs).
  Use this macro when any input field can legitimately be NULL.

  Usage:
    -- Single field
    {{ generate_surrogate_key_safe(['order_id']) }} as order_key

    -- Composite key (e.g., order_items — no single-column PK in source)
    {{ generate_surrogate_key_safe(['order_id', 'item_id']) }} as order_item_key

    -- Cross-system composite key
    {{ generate_surrogate_key_safe(['source_system', 'entity_id']) }} as entity_key
#}

  md5(
    concat_ws(
      '|',
      {% for field in field_list -%}
        coalesce(cast({{ field }} as varchar), 'UNKNOWN')
        {%- if not loop.last %}, {% endif %}
      {%- endfor %}
    )
  )

{% endmacro %}
