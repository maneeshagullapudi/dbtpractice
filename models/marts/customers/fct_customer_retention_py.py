import snowflake.snowpark.functions as F


def model(dbt, session):
    dbt.config(materialized="table", tags=["customers", "python"])

    orders = dbt.ref("fct_customer_orders")

    filtered = orders.filter(F.col("ORDER_STATUS").isin(["delivered", "refunded"]))

    customer_month = filtered.select(
        F.col("CUSTOMER_ID").alias("customer_id"),
        F.date_trunc("month", F.col("ORDER_DATE")).alias("order_month"),
        F.col("ACQUISITION_CHANNEL").alias("acquisition_channel"),
        F.col("CUSTOMER_ORDER_NUMBER").alias("customer_order_number"),
        F.col("DAYS_SINCE_FIRST_ORDER").alias("days_since_first_order"),
    ).group_by("customer_id", "order_month", "acquisition_channel").agg(
        F.min(F.col("customer_order_number")).alias("first_order_number_in_month"),
        F.max(F.when(F.col("customer_order_number") > 1, F.lit(1)).otherwise(F.lit(0))).alias("is_repeat_customer"),
        F.max(F.when(F.col("days_since_first_order") <= 30, F.lit(1)).otherwise(F.lit(0))).alias("is_retained_30d"),
        F.max(F.when(F.col("days_since_first_order") <= 60, F.lit(1)).otherwise(F.lit(0))).alias("is_retained_60d"),
        F.max(F.when(F.col("days_since_first_order") <= 90, F.lit(1)).otherwise(F.lit(0))).alias("is_retained_90d"),
    )

    aggregated = customer_month.group_by("order_month", "acquisition_channel").agg(
        F.count_distinct("customer_id").alias("active_customers"),
        F.sum(F.when(F.col("first_order_number_in_month") == 1, F.lit(1)).otherwise(F.lit(0))).alias("new_customers"),
        F.sum(F.col("is_repeat_customer")).alias("repeat_customers"),
        F.sum(F.col("is_retained_30d")).alias("retained_within_30d_customers"),
        F.sum(F.col("is_retained_60d")).alias("retained_within_60d_customers"),
        F.sum(F.col("is_retained_90d")).alias("retained_within_90d_customers"),
    )

    return (
        aggregated.with_column(
            "customer_retention_cohort_key",
            F.sha2(
                F.concat(
                    F.to_varchar(F.col("ORDER_MONTH")),
                    F.col("ACQUISITION_CHANNEL"),
                ),
                256,
            ),
        )
        .with_column(
            "repeat_customer_rate",
            F.coalesce(F.round(F.col("REPEAT_CUSTOMERS") / F.nullifzero(F.col("ACTIVE_CUSTOMERS")), 4), F.lit(0)),
        )
        .with_column(
            "retention_30d_rate",
            F.coalesce(F.round(F.col("RETAINED_WITHIN_30D_CUSTOMERS") / F.nullifzero(F.col("ACTIVE_CUSTOMERS")), 4), F.lit(0)),
        )
        .with_column(
            "retention_60d_rate",
            F.coalesce(F.round(F.col("RETAINED_WITHIN_60D_CUSTOMERS") / F.nullifzero(F.col("ACTIVE_CUSTOMERS")), 4), F.lit(0)),
        )
        .with_column(
            "retention_90d_rate",
            F.coalesce(F.round(F.col("RETAINED_WITHIN_90D_CUSTOMERS") / F.nullifzero(F.col("ACTIVE_CUSTOMERS")), 4), F.lit(0)),
        )
    )
