import snowflake.snowpark.functions as F


def model(dbt, session):
    dbt.config(materialized="table", tags=["restaurants", "python"])

    restaurants = dbt.ref("dim_restaurants")

    return (
        restaurants.select(
            F.col("RESTAURANT_ID").alias("restaurant_id"),
            F.col("CITY_ID").alias("city_id"),
            F.col("CUISINE_TYPE").alias("cuisine_type"),
            F.col("RESTAURANT_TIER").alias("restaurant_tier"),
            F.col("ORDERS_LAST_30D").alias("orders_last_30d"),
            F.col("REVENUE_LAST_30D").alias("revenue_last_30d"),
            F.col("AVG_RATING_LAST_30D").alias("avg_rating_last_30d"),
            F.col("AVG_PREP_MINUTES_LAST_30D").alias("avg_prep_minutes_last_30d"),
            F.col("ON_TIME_RATE_LAST_30D").alias("on_time_rate_last_30d"),
            F.col("IS_ACTIVE").alias("is_active"),
            F.col("IS_VERIFIED").alias("is_verified"),
        )
        .with_column(
            "health_score",
            F.greatest(
                F.lit(0),
                F.least(
                    F.lit(100),
                    (F.coalesce(F.col("ORDERS_LAST_30D"), F.lit(0)) / F.lit(2))
                    + (F.coalesce(F.col("AVG_RATING_LAST_30D"), F.lit(0)) * F.lit(12))
                    + (F.coalesce(F.col("ON_TIME_RATE_LAST_30D"), F.lit(0)) * F.lit(25))
                    - (F.coalesce(F.col("AVG_PREP_MINUTES_LAST_30D"), F.lit(0)) / F.lit(3))
                    + F.when(F.col("IS_VERIFIED"), F.lit(5)).otherwise(F.lit(0)),
                ),
            ),
        )
        .with_column(
            "health_tier",
            F.when(F.col("HEALTH_SCORE") >= 85, F.lit("excellent"))
            .when(F.col("HEALTH_SCORE") >= 70, F.lit("healthy"))
            .when(F.col("HEALTH_SCORE") >= 50, F.lit("watchlist"))
            .otherwise(F.lit("at_risk")),
        )
        .with_column(
            "needs_attention",
            F.when(
                (F.col("HEALTH_SCORE") < 50)
                | (F.coalesce(F.col("ON_TIME_RATE_LAST_30D"), F.lit(0)) < F.lit(0.85))
                | (F.coalesce(F.col("AVG_RATING_LAST_30D"), F.lit(0)) < F.lit(4.0)),
                F.lit(True),
            ).otherwise(F.lit(False)),
        )
    )
