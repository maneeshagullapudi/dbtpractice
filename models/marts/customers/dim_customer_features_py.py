import snowflake.snowpark.functions as F


def model(dbt, session):
    dbt.config(materialized="table", tags=["customers", "python"])

    customers = dbt.ref("dim_customers")
    ltv = dbt.ref("fct_customer_lifetime_value")

    joined = customers.join(
        ltv,
        customers["CUSTOMER_ID"] == ltv["CUSTOMER_ID"],
        how="left",
    ).select(
        customers["CUSTOMER_ID"].alias("customer_id"),
        customers["CITY_ID"].alias("city_id"),
        customers["CUSTOMER_SEGMENT"].alias("customer_segment"),
        customers["CHURN_RISK_TIER"].alias("churn_risk_tier"),
        customers["TOTAL_ORDERS"].alias("total_orders"),
        customers["DISTINCT_CUISINES_ORDERED"].alias("distinct_cuisines_ordered"),
        customers["DAYS_SINCE_LAST_ORDER"].alias("days_since_last_order"),
        ltv["TOTAL_PREDICTED_LTV"].alias("total_predicted_ltv"),
        ltv["MONTHLY_ORDER_RATE"].alias("monthly_order_rate"),
        ltv["EXPECTED_REMAINING_ACTIVE_MONTHS"].alias("expected_remaining_active_months"),
    )

    return (
        joined.with_column(
            "recency_bucket",
            F.when(F.col("DAYS_SINCE_LAST_ORDER") <= 7, F.lit("active_7d"))
            .when(F.col("DAYS_SINCE_LAST_ORDER") <= 30, F.lit("active_30d"))
            .when(F.col("DAYS_SINCE_LAST_ORDER") <= 90, F.lit("active_90d"))
            .otherwise(F.lit("dormant")),
        )
        .with_column(
            "frequency_band",
            F.when(F.col("MONTHLY_ORDER_RATE") >= 8, F.lit("power"))
            .when(F.col("MONTHLY_ORDER_RATE") >= 4, F.lit("core"))
            .when(F.col("MONTHLY_ORDER_RATE") >= 1, F.lit("casual"))
            .otherwise(F.lit("rare")),
        )
        .with_column(
            "ltv_band",
            F.when(F.col("TOTAL_PREDICTED_LTV") >= 20000, F.lit("platinum"))
            .when(F.col("TOTAL_PREDICTED_LTV") >= 8000, F.lit("gold"))
            .when(F.col("TOTAL_PREDICTED_LTV") >= 2000, F.lit("silver"))
            .otherwise(F.lit("bronze")),
        )
        .with_column(
            "engagement_score",
            F.greatest(
                F.lit(0),
                F.least(
                    F.lit(100),
                    (F.coalesce(F.col("MONTHLY_ORDER_RATE"), F.lit(0)) * F.lit(8))
                    + (F.coalesce(F.col("DISTINCT_CUISINES_ORDERED"), F.lit(0)) * F.lit(2))
                    + F.when(F.col("DAYS_SINCE_LAST_ORDER") <= 30, F.lit(20)).otherwise(F.lit(0))
                    + F.when(F.col("CHURN_RISK_TIER") == F.lit("low"), F.lit(10)).otherwise(F.lit(0)),
                ),
            ),
        )
    )
