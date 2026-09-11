{% macro generate_schema_name(custom_schema_name, node) -%}
{#
  Schema routing macro — overrides dbt's default schema naming.

  dbt default: appends custom_schema to target.schema producing names like
  "dev_sushil_marts_finance" which is messy and hard to grant access to.

  This macro routes schemas cleanly per environment:

  Target    | custom_schema   | Resulting schema
  ----------|-----------------|--------------------
  prod      | marts_finance   | MARTS_FINANCE
  prod      | staging         | STAGING
  prod+WAP  | marts_finance   | MARTS_FINANCE_CANDIDATE
  prod+WAP  | staging         | STAGING_CANDIDATE
  preprod   | marts_finance   | PREPROD_MARTS_FINANCE
  preprod   | staging         | PREPROD_STAGING
  stage     | staging         | CI_12345_STAGING
  dev       | staging         | DEV_SUSHIL_STAGING
  <other>   | staging         | DEV_<target.schema>_STAGING

  This ensures:
  1. Clean production schema names (no environment prefix)
  2. No cross-environment pollution (stage/CI schemas include run ID)
  3. Clean preprod isolation (stable PREPROD_* schemas)
  4. Per-developer isolation in dev (schema includes username)
  5. New environments are safe by default (non-prod prefix always applied)
  6. Prod WAP writes can land in candidate schemas before publish

  IMPORTANT: Do NOT use target.schema directly in this macro for prod WAP targets.
  target.schema may return the deployer's schema if called during analytics project CD.
  Always use hardcoded var defaults for WAP target schema names.
#}

{%- set default_schema = target.schema -%}
{%- set custom_schema = custom_schema_name | upper | trim if custom_schema_name is not none else none -%}
{%- set wap_stage = var('wap_stage', 'live') | lower | trim -%}

{%- if custom_schema is none -%}

    {{ default_schema }}

{%- elif target.name == 'prod' -%}

    {%- if wap_stage == 'candidate' -%}
        {{ custom_schema }}_CANDIDATE
    {%- else -%}
        {{ custom_schema }}
    {%- endif -%}

{%- elif target.name == 'preprod' -%}

    PREPROD_{{ custom_schema }}

{%- elif target.name == 'stage' -%}

    CI_{{ env_var('GITHUB_RUN_ID', 'LOCAL') }}_{{ custom_schema }}

{%- else -%}

    DEV_{{ env_var('DBT_USER', target.schema | upper) | upper | trim }}_{{ custom_schema }}

{%- endif -%}

{%- endmacro %}

