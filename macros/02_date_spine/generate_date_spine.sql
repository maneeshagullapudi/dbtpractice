{% macro generate_date_spine(
    start_date=var('date_spine_start', '2020-01-01'),
    end_date=var('date_spine_end', '2030-12-31'),
    datepart='day'
) %}
{#
  Generates a continuous series of dates (or months/weeks/hours) from start to end.
  Wraps dbt_utils.date_spine with project-default date ranges configurable via vars.

  Usage:
    -- Full project range (configured in dbt_project.yml)
    {{ generate_date_spine() }}

    -- Custom range
    {{ generate_date_spine('2024-01-01', '2024-12-31') }}

    -- Monthly spine (for monthly aggregations)
    {{ generate_date_spine(datepart='month') }}

    -- Override via CLI for dev runs
    -- dbt run --vars '{"date_spine_start": "2024-01-01", "date_spine_end": "2024-03-31"}'

  Returns: a column named date_day (or date_month etc.) of type DATE
#}

{{ dbt_utils.date_spine(
    datepart=datepart,
    start_date="cast('" ~ start_date ~ "' as date)",
    end_date="cast('" ~ end_date ~ "' as date)"
) }}

{% endmacro %}
