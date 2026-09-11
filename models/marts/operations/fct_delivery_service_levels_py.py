import snowflake.snowpark.functions as F


def model(dbt, session):
    dbt.config(materialized="table", tags=["operations", "python"])

    deliveries = dbt.ref("fct_deliveries")

    base = deliveries.select(
        F.to_date(F.col("ORDER_DATE")).alias("delivery_date"),
        F.col("CITY_ID").alias("city_id"),
        F.col("DELIVERY_PARTNER_ID").alias("delivery_partner_id"),
        F.col("DELIVERY_STATUS").alias("delivery_status"),
        F.col("IS_ON_TIME_DELIVERY").alias("is_on_time_delivery"),
        F.col("TOTAL_DELIVERY_MINUTES").alias("total_delivery_minutes"),
        F.col("DELIVERY_DISTANCE_KM").alias("delivery_distance_km"),
    )

    aggregated = base.group_by("delivery_date", "city_id", "delivery_partner_id").agg(
        F.count(F.lit(1)).alias("total_deliveries"),
        F.sum(F.when(F.col("delivery_status") == F.lit("delivered"), F.lit(1)).otherwise(F.lit(0))).alias("successful_deliveries"),
        F.sum(F.when(F.col("is_on_time_delivery"), F.lit(1)).otherwise(F.lit(0))).alias("on_time_deliveries"),
        F.avg(F.col("total_delivery_minutes")).alias("avg_delivery_minutes"),
        F.avg(F.col("delivery_distance_km")).alias("avg_delivery_distance_km"),
    )

    return (
        aggregated.with_column(
            "on_time_delivery_rate",
            F.coalesce(F.round(F.col("ON_TIME_DELIVERIES") / F.nullifzero(F.col("SUCCESSFUL_DELIVERIES")), 4), F.lit(0)),
        )
        .with_column(
            "service_level_band",
            F.when(F.col("ON_TIME_DELIVERY_RATE") >= 0.95, F.lit("elite"))
            .when(F.col("ON_TIME_DELIVERY_RATE") >= 0.90, F.lit("strong"))
            .when(F.col("ON_TIME_DELIVERY_RATE") >= 0.80, F.lit("watch"))
            .otherwise(F.lit("critical")),
        )
        .with_column(
            "speed_band",
            F.when(F.col("AVG_DELIVERY_MINUTES") <= 30, F.lit("fast"))
            .when(F.col("AVG_DELIVERY_MINUTES") <= 45, F.lit("standard"))
            .when(F.col("AVG_DELIVERY_MINUTES") <= 60, F.lit("slow"))
            .otherwise(F.lit("severely_slow")),
        )
    )
