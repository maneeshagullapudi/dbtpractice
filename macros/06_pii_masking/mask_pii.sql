{% macro mask_pii(column_name, mask_value='***REDACTED***') %}
{#
  Returns the column value unmasked in production, redacted in all other environments.

  DESIGN INTENT: The masking logic is INVERTED — production is the whitelist, not a blacklist.
  This means any new target added to CI/CD is safe by default without opt-in configuration.
  If we masked only in 'dev' and 'staging', forgetting to add 'test' or 'ci2' to the list
  would silently expose PII. The inversion prevents this class of error.

  Usage:
    {{ mask_pii('customer_email') }}
    {{ mask_pii('customer_phone') }}
    {{ mask_pii('delivery_address', 'ADDRESS REDACTED') }}

  In a model:
    select
        customer_id,
        {{ mask_pii('customer_email') }}        as customer_email,
        {{ mask_pii('customer_phone') }}        as customer_phone,
        city_id
    from source

  Behavior:
    target = prod → returns column_name AS-IS (unmasked)
    any other target → returns the mask_value literal

  Production access to unmasked data is further governed by Snowflake RBAC
  (ZOMATO_PII_ANALYST_ROLE is required to query the STAGING schema in prod).

  Audit: grep for PII column names not wrapped in mask_pii():
    grep -rn "customer_email\|customer_phone\|delivery_address" models/staging/ \
      | grep -v "mask_pii" | grep -v ".yml"
    # Should return no results
#}

{%- if target.name == 'prod' -%}
    {{ column_name }}
{%- else -%}
    cast('{{ mask_value }}' as varchar)
{%- endif -%}

{% endmacro %}
