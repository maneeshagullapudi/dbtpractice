{% test not_negative(model, column_name) %}
{#
  Generic test: fails if any value in column_name is strictly less than 0.

  Usage in schema.yml:
    columns:
      - name: total_amount
        tests:
          - not_negative

      - name: delivery_fee
        tests:
          - not_negative

  Use when: a column should always be non-negative (zero is allowed).
  For strictly positive values, combine with not_null and a range test:
    - dbt_expectations.expect_column_values_to_be_between:
        min_value: 0
        strictly: true

  Returns rows that fail — any result = test failure.
#}

select
    {{ column_name }},
    count(*) as failing_row_count
from {{ model }}
where {{ column_name }} < 0
group by 1
having count(*) > 0

{% endtest %}
