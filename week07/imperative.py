from snowflake.snowpark import Session
from snowflake.snowpark.functions import (
    col, when, lit, min as sp_min, count, abs as sp_abs,
    round as sp_round, row_number, percent_rank,
    call_function,
)
from snowflake.snowpark.window import Window


def create_session():
    session = Session.builder.configs({
        "account": "phb65663",
        "user": "COYOTE",
        "role": "TRAINING_ROLE",
        "warehouse": "SNOWFLAKE_LEARNING_WH",
        "database": "DATA5035",
        "schema": "SPRING26",
    }).create()
    return session


def load_tables(session):
    tables = {}
    tables["road_segments"] = session.table("DATA5035.SPRING26.ROAD_SEGMENTS")
    tables["traffic_counts"] = session.table("DATA5035.SPRING26.TRAFFIC_COUNTS")
    tables["weather_risk"] = session.table("DATA5035.SPRING26.WEATHER_RISK")
    tables["incidents"] = session.table("DATA5035.SPRING26.INCIDENTS")
    tables["env_constraints"] = session.table("DATA5035.SPRING26.ENV_CONSTRAINTS")
    tables["power_infra"] = session.table("DATA5035.SPRING26.POWER_INFRA")
    tables["interchanges"] = session.table("DATA5035.SPRING26.INTERCHANGES")
    return tables


def build_base(tables):
    rs = tables["road_segments"]
    tc = tables["traffic_counts"]
    wr = tables["weather_risk"]
    inc = tables["incidents"]

    base = rs.join(tc, rs["SEGMENT_ID"] == tc["SEGMENT_ID"]).drop(tc["SEGMENT_ID"])
    base = base.join(wr, base["SEGMENT_ID"] == wr["SEGMENT_ID"]).drop(wr["SEGMENT_ID"])
    base = base.join(inc, base["SEGMENT_ID"] == inc["SEGMENT_ID"]).drop(inc["SEGMENT_ID"])

    base = base.with_column(
        "WEATHER_RISK_SCORE", col("RISK_SCORE")
    )

    base = base.with_column(
        "CORRIDOR",
        when(col("INTERSTATE") == lit("I-70"), lit("STL_KC")).otherwise(lit("STL_CHI"))
    )

    base = base.select(
        "SEGMENT_ID", "INTERSTATE", "START_MILE", "END_MILE",
        "LANES", "SPEED_LIMIT", "GEOM",
        "AADT_TOTAL", "AADT_EV", "AADT_TRUCK", "PEAK_FACTOR",
        "WEATHER_RISK_SCORE", "CRASH_RATE", "INCIDENT_RATE", "CORRIDOR"
    )
    return base


def find_env_exclusions(tables):
    rs = tables["road_segments"]
    ec = tables["env_constraints"]

    crossed = rs.cross_join(ec)
    intersecting = crossed.filter(
        call_function("ST_INTERSECTS", rs["GEOM"], ec["GEOM"])
    )
    excluded_ids = intersecting.select(rs["SEGMENT_ID"]).distinct()
    return excluded_ids


def compute_power_proximity(tables):
    rs = tables["road_segments"]
    pi = tables["power_infra"]

    crossed = rs.select(
        col("SEGMENT_ID"), col("GEOM").alias("RS_GEOM")
    ).cross_join(
        pi.select(col("GEOM").alias("PI_GEOM"))
    )

    crossed = crossed.with_column(
        "dist", call_function("ST_DISTANCE", col("RS_GEOM"), col("PI_GEOM"))
    )

    power_prox = crossed.group_by("SEGMENT_ID").agg(
        sp_min("dist").alias("min_power_dist_m"),
        count(when(col("dist") < lit(30000), lit(1))).alias("power_assets_30km"),
    )
    return power_prox


def compute_interchange_density(tables):
    rs = tables["road_segments"]
    ix = tables["interchanges"]

    rs_sub = rs.select(
        col("SEGMENT_ID"), col("INTERSTATE").alias("RS_INTERSTATE"),
        col("GEOM").alias("RS_GEOM")
    )
    ix_sub = ix.select(
        col("INTERCHANGE_ID"), col("INTERSTATE").alias("IX_INTERSTATE"),
        col("GEOM").alias("IX_GEOM")
    )

    joined = rs_sub.join(
        ix_sub,
        (col("IX_INTERSTATE") == col("RS_INTERSTATE"))
        & (call_function("ST_DISTANCE", col("RS_GEOM"), col("IX_GEOM")) < lit(5000)),
        "left"
    )

    density = joined.group_by("SEGMENT_ID").agg(
        count("INTERCHANGE_ID").alias("interchange_count")
    )
    return density


def apply_filters_and_score(base, env_exclusions, power_prox, interchange_dens):
    merged = base.join(power_prox, "SEGMENT_ID")
    merged = merged.join(interchange_dens, "SEGMENT_ID")

    excluded_ids = env_exclusions.with_column_renamed("SEGMENT_ID", "EXCL_ID")
    merged = merged.join(excluded_ids, merged["SEGMENT_ID"] == excluded_ids["EXCL_ID"], "left")
    merged = merged.filter(col("EXCL_ID").is_null())
    merged = merged.drop("EXCL_ID")

    merged = merged.filter(col("LANES") >= 4)

    w_aadt_ev = Window.order_by(col("AADT_EV").asc())
    w_power_dist = Window.order_by(col("min_power_dist_m").desc())
    w_interchange = Window.order_by(col("interchange_count").asc())
    w_crash = Window.order_by(col("CRASH_RATE").asc())
    w_weather = Window.order_by(col("WEATHER_RISK_SCORE").asc())
    w_speed = Window.order_by(sp_abs(col("SPEED_LIMIT") - lit(65)).asc())

    merged = merged.with_column("demand_pctile", percent_rank().over(w_aadt_ev))
    merged = merged.with_column("power_prox_pctile", percent_rank().over(w_power_dist))
    merged = merged.with_column("low_interchange_pctile", percent_rank().over(w_interchange))
    merged = merged.with_column("low_crash_pctile", percent_rank().over(w_crash))
    merged = merged.with_column("low_weather_pctile", percent_rank().over(w_weather))
    merged = merged.with_column("speed_compat_pctile", percent_rank().over(w_speed))

    merged = merged.with_column(
        "corridor_importance",
        when(col("INTERSTATE").isin(lit("I-70"), lit("I-55")), lit(1.0))
        .when(col("INTERSTATE").isin(lit("I-64"), lit("I-80")), lit(0.7))
        .otherwise(lit(0.5))
    )

    merged = merged.with_column(
        "strategic_visibility",
        when(col("AADT_TOTAL") > lit(60000), lit(1.0))
        .when(col("AADT_TOTAL") > lit(40000), lit(0.7))
        .otherwise(lit(0.4))
    )
    return merged


def compute_final_scores(scored):
    scored = scored.with_column(
        "demand_score",
        col("demand_pctile") * lit(0.25)
    )
    scored = scored.with_column(
        "feasibility_score",
        (col("power_prox_pctile") * lit(0.50) + col("low_interchange_pctile") * lit(0.30)) * lit(0.25)
    )
    scored = scored.with_column(
        "safety_score",
        (col("low_crash_pctile") * lit(0.40) + col("low_weather_pctile") * lit(0.35) + col("speed_compat_pctile") * lit(0.25)) * lit(0.25)
    )
    scored = scored.with_column(
        "pilot_value_score",
        (col("strategic_visibility") * lit(0.40) + col("corridor_importance") * lit(0.60)) * lit(0.25)
    )
    scored = scored.with_column(
        "composite_score",
        col("demand_score") + col("feasibility_score") + col("safety_score") + col("pilot_value_score")
    )
    return scored


def rank_per_corridor(scored):
    w_corridor = Window.partition_by("CORRIDOR").order_by(col("composite_score").desc())
    ranked = scored.with_column("corridor_rank", row_number().over(w_corridor))
    return ranked


def pick_best_segments(ranked):
    pick1 = ranked.filter(col("corridor_rank") == 1)

    pick1_stl_chi = pick1.filter(col("CORRIDOR") == lit("STL_CHI")).select(
        col("INTERSTATE").alias("P1_INTERSTATE"),
        col("START_MILE").alias("P1_START_MILE"),
    )
    candidates_chi = ranked.filter(
        (col("CORRIDOR") == lit("STL_CHI")) & (col("corridor_rank") > 1)
    )
    pick2_chi = candidates_chi.cross_join(pick1_stl_chi).filter(
        (col("INTERSTATE") != col("P1_INTERSTATE"))
        | (sp_abs(col("START_MILE") - col("P1_START_MILE")) >= lit(50))
    ).drop("P1_INTERSTATE", "P1_START_MILE")
    pick2_chi = pick2_chi.sort(col("composite_score").desc()).limit(1)

    pick1_stl_kc = pick1.filter(col("CORRIDOR") == lit("STL_KC")).select(
        col("INTERSTATE").alias("P1_INTERSTATE"),
        col("START_MILE").alias("P1_START_MILE"),
    )
    candidates_kc = ranked.filter(
        (col("CORRIDOR") == lit("STL_KC")) & (col("corridor_rank") > 1)
    )
    pick2_kc = candidates_kc.cross_join(pick1_stl_kc).filter(
        (col("INTERSTATE") != col("P1_INTERSTATE"))
        | (sp_abs(col("START_MILE") - col("P1_START_MILE")) >= lit(50))
    ).drop("P1_INTERSTATE", "P1_START_MILE")
    pick2_kc = pick2_kc.sort(col("composite_score").desc()).limit(1)

    final_picks = pick1.union_all(pick2_chi).union_all(pick2_kc)
    return final_picks


def format_output(final_picks):
    result = final_picks.select(
        col("SEGMENT_ID"),
        col("INTERSTATE"),
        col("CORRIDOR"),
        (col("START_MILE").cast("string") + lit(" - ") + col("END_MILE").cast("string")).alias("MILE_RANGE"),
        col("LANES"),
        col("SPEED_LIMIT"),
        col("AADT_TOTAL"),
        col("AADT_EV"),
        col("AADT_TRUCK"),
        col("PEAK_FACTOR"),
        col("WEATHER_RISK_SCORE"),
        col("CRASH_RATE"),
        col("INCIDENT_RATE"),
        sp_round(col("min_power_dist_m") / lit(1000), lit(1)).alias("NEAREST_POWER_KM"),
        col("power_assets_30km").alias("POWER_ASSETS_WITHIN_30KM"),
        col("interchange_count").alias("INTERCHANGES_NEARBY"),
        sp_round(col("demand_score"), lit(4)).alias("DEMAND_SCORE"),
        sp_round(col("feasibility_score"), lit(4)).alias("FEASIBILITY_SCORE"),
        sp_round(col("safety_score"), lit(4)).alias("SAFETY_SCORE"),
        sp_round(col("pilot_value_score"), lit(4)).alias("PILOT_VALUE_SCORE"),
        sp_round(col("composite_score"), lit(4)).alias("COMPOSITE_SCORE"),
        col("corridor_rank").alias("RANK_IN_CORRIDOR"),
    )
    result = result.sort("CORRIDOR", "RANK_IN_CORRIDOR")
    return result


def main():
    session = create_session()
    tables = load_tables(session)

    base = build_base(tables)
    env_excl = find_env_exclusions(tables)
    power_prox = compute_power_proximity(tables)
    interchange_dens = compute_interchange_density(tables)

    scored = apply_filters_and_score(base, env_excl, power_prox, interchange_dens)
    scored = compute_final_scores(scored)
    ranked = rank_per_corridor(scored)

    final_picks = pick_best_segments(ranked)
    result = format_output(final_picks)

    pdf = result.to_pandas()
    pdf.to_csv("week07/SEGMENTS.csv", index=False)
    print(f"Saved {len(pdf)} rows to week07/SEGMENTS.csv")
    print(pdf.to_string(index=False))

    session.close()


if __name__ == "__main__":
    main()
