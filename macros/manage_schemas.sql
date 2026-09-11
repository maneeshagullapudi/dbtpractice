{% macro drop_ci_schemas(run_id) %}
    {% if target.name != 'stage' %}
        {{ log('drop_ci_schemas skipped: target is not stage', info=True) }}
        {{ return('skipped') }}
    {% endif %}

    {% set database_name = target.database %}
    {% set prefix = 'CI_' ~ run_id ~ '_' %}

    {% set schemas_query %}
        select schema_name
        from {{ database_name }}.information_schema.schemata
        where schema_name ilike '{{ prefix }}%'
    {% endset %}

    {% set results = run_query(schemas_query) %}

    {% if execute and results is not none and (results.rows | length) > 0 %}
        {% for row in results.rows %}
            {% set schema_name = row[0] %}
            {% do run_query('drop schema if exists ' ~ adapter.quote(database_name) ~ '.' ~ adapter.quote(schema_name) ~ ' cascade') %}
            {{ log('Dropped stage/CI schema: ' ~ database_name ~ '.' ~ schema_name, info=True) }}
        {% endfor %}
    {% else %}
        {{ log('No stage/CI schemas found for run_id=' ~ run_id, info=True) }}
    {% endif %}

    {{ return('ok') }}
{% endmacro %}


{% macro swap_schemas(keep_backup=true, rollback=false) %}
    {% if target.name != 'prod' %}
        {{ exceptions.raise_compiler_error('swap_schemas can only run against the prod target') }}
    {% endif %}

    {% set managed_schemas = ['STAGING', 'MARTS_FINANCE', 'MARTS_CUSTOMERS', 'MARTS_RESTAURANTS', 'MARTS_OPERATIONS', 'SNAPSHOTS'] %}
    {% set timestamp_suffix = modules.datetime.datetime.utcnow().strftime('%Y%m%d%H%M%S') %}

    {% for schema_name in managed_schemas %}
        {% set candidate_schema = schema_name ~ '_CANDIDATE' %}
        {% set backup_schema = schema_name ~ '_BACKUP_' ~ timestamp_suffix %}

        {% if rollback %}
            {{ log('Rollback requested for schema family ' ~ schema_name ~ '. Manual backup selection is required.', info=True) }}
        {% else %}
            {% if keep_backup %}
                {% do run_query('alter schema if exists ' ~ adapter.quote(target.database) ~ '.' ~ adapter.quote(schema_name) ~ ' rename to ' ~ adapter.quote(backup_schema)) %}
                {{ log('Renamed live schema to backup: ' ~ schema_name ~ ' -> ' ~ backup_schema, info=True) }}
            {% else %}
                {% do run_query('drop schema if exists ' ~ adapter.quote(target.database) ~ '.' ~ adapter.quote(schema_name) ~ ' cascade') %}
                {{ log('Dropped live schema before publish: ' ~ schema_name, info=True) }}
            {% endif %}

            {% do run_query('alter schema if exists ' ~ adapter.quote(target.database) ~ '.' ~ adapter.quote(candidate_schema) ~ ' rename to ' ~ adapter.quote(schema_name)) %}
            {{ log('Published candidate schema: ' ~ candidate_schema ~ ' -> ' ~ schema_name, info=True) }}
        {% endif %}
    {% endfor %}

    {{ return('ok') }}
{% endmacro %}
