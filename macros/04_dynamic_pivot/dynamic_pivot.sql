{% macro dynamic_pivot(
    relation,
    pivot_column,
    value_column,
    agg_function='sum',
    group_by_columns=[],
    then_value=0,
    quote_identifiers=false
) %}
{#
  Dynamically pivots a relation without hardcoding column values.
  Discovers distinct pivot values via a database query at COMPILE TIME.

  IMPORTANT: Because this runs a query at compile time, it adds to compilation
  latency. Cache the compiled SQL if compilation speed is critical.

  WARNING: New pivot values (e.g., a new payment method added next month) will
  NOT automatically appear — must run dbt compile or dbt build to refresh.

  Usage:
    {{ dynamic_pivot(
        relation=ref('stg_payments'),
        pivot_column='payment_method',
        value_column='payment_amount',
        agg_function='sum',
        group_by_columns=['order_date', 'city_id']
    ) }}

  Arguments:
    relation          — dbt ref() or source() to pivot
    pivot_column      — column whose distinct values become column headers
    value_column      — column to aggregate
    agg_function      — SQL aggregate function (sum, count, avg, max)
    group_by_columns  — columns to group by (non-pivot dimensions)
    then_value        — default when pivot_column != this value (usually 0 or null)
    quote_identifiers — whether to quote generated column names
#}

{%- set pivot_values_query %}
    select distinct cast({{ pivot_column }} as varchar) as pivot_val
    from {{ relation }}
    where {{ pivot_column }} is not null
    order by 1
{%- endset %}

{%- if execute %}
    {%- set results = run_query(pivot_values_query) %}
    {%- set pivot_values = results.columns[0].values() %}
{%- else %}
    {%- set pivot_values = [] %}
{%- endif %}

select
    {% for col in group_by_columns %}
        {{ col }},
    {% endfor %}

    {% for value in pivot_values %}
        {{ agg_function }}(
            case
                when {{ pivot_column }} = '{{ value }}'
                then {{ value_column }}
                else {{ then_value }}
            end
        ) as {% if quote_identifiers %}"{{ value }}"{% else %}{{ value | replace(' ', '_') | replace('-', '_') | lower }}{% endif %}
        {%- if not loop.last %},{% endif %}
    {% endfor %}

from {{ relation }}

{% if group_by_columns | length > 0 %}
group by
    {% for col in group_by_columns %}
        {{ col }}{% if not loop.last %},{% endif %}
    {% endfor %}
{% endif %}

{% endmacro %}
