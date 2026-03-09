WITH base AS (
    SELECT
        rs.SEGMENT_ID,
        rs.INTERSTATE,
        rs.START_MILE,
        rs.END_MILE,
        rs.LANES,
        rs.SPEED_LIMIT,
        rs.GEOM,
        tc.AADT_TOTAL,
        tc.AADT_EV,
        tc.AADT_TRUCK,
        tc.PEAK_FACTOR,
        wr.RISK_SCORE AS WEATHER_RISK_SCORE,
        inc.CRASH_RATE,
        inc.INCIDENT_RATE,
        CASE
            WHEN rs.INTERSTATE = 'I-70' THEN 'STL_KC'
            ELSE 'STL_CHI'
        END AS CORRIDOR
    FROM DATA5035.SPRING26.ROAD_SEGMENTS rs
    JOIN DATA5035.SPRING26.TRAFFIC_COUNTS tc ON rs.SEGMENT_ID = tc.SEGMENT_ID
    JOIN DATA5035.SPRING26.WEATHER_RISK wr ON rs.SEGMENT_ID = wr.SEGMENT_ID
    JOIN DATA5035.SPRING26.INCIDENTS inc ON rs.SEGMENT_ID = inc.SEGMENT_ID
),

env_exclusions AS (
    SELECT DISTINCT rs.SEGMENT_ID
    FROM DATA5035.SPRING26.ROAD_SEGMENTS rs
    JOIN DATA5035.SPRING26.ENV_CONSTRAINTS ec
        ON ST_INTERSECTS(rs.GEOM, ec.GEOM)
),

power_proximity AS (
    SELECT
        rs.SEGMENT_ID,
        MIN(ST_DISTANCE(rs.GEOM, pi.GEOM)) AS min_power_dist_m,
        COUNT(CASE WHEN ST_DISTANCE(rs.GEOM, pi.GEOM) < 30000 THEN 1 END) AS power_assets_30km
    FROM DATA5035.SPRING26.ROAD_SEGMENTS rs
    CROSS JOIN DATA5035.SPRING26.POWER_INFRA pi
    GROUP BY rs.SEGMENT_ID
),

interchange_density AS (
    SELECT
        rs.SEGMENT_ID,
        COUNT(ix.INTERCHANGE_ID) AS interchange_count
    FROM DATA5035.SPRING26.ROAD_SEGMENTS rs
    LEFT JOIN DATA5035.SPRING26.INTERCHANGES ix
        ON ix.INTERSTATE = rs.INTERSTATE
        AND ST_DISTANCE(rs.GEOM, ix.GEOM) < 5000
    GROUP BY rs.SEGMENT_ID
),

scored AS (
    SELECT
        b.*,
        pp.min_power_dist_m,
        pp.power_assets_30km,
        id.interchange_count,
        PERCENT_RANK() OVER (ORDER BY b.AADT_EV)                       AS demand_pctile,
        PERCENT_RANK() OVER (ORDER BY pp.min_power_dist_m DESC)        AS power_prox_pctile,
        PERCENT_RANK() OVER (ORDER BY id.interchange_count ASC)        AS low_interchange_pctile,
        PERCENT_RANK() OVER (ORDER BY b.CRASH_RATE ASC)                AS low_crash_pctile,
        PERCENT_RANK() OVER (ORDER BY b.WEATHER_RISK_SCORE ASC)        AS low_weather_pctile,
        PERCENT_RANK() OVER (ORDER BY ABS(b.SPEED_LIMIT - 65) ASC)    AS speed_compat_pctile,
        CASE
            WHEN b.INTERSTATE IN ('I-70','I-55') THEN 1.0
            WHEN b.INTERSTATE IN ('I-64','I-80') THEN 0.7
            ELSE 0.5
        END AS corridor_importance,
        CASE
            WHEN b.AADT_TOTAL > 60000 THEN 1.0
            WHEN b.AADT_TOTAL > 40000 THEN 0.7
            ELSE 0.4
        END AS strategic_visibility
    FROM base b
    JOIN power_proximity pp ON b.SEGMENT_ID = pp.SEGMENT_ID
    JOIN interchange_density id ON b.SEGMENT_ID = id.SEGMENT_ID
    LEFT JOIN env_exclusions ee ON b.SEGMENT_ID = ee.SEGMENT_ID
    WHERE ee.SEGMENT_ID IS NULL
      AND b.LANES >= 4
),

final_scores AS (
    SELECT
        s.*,
        (s.demand_pctile) * 0.25 AS demand_score,
        (s.power_prox_pctile * 0.50 + s.low_interchange_pctile * 0.30) * 0.25 AS feasibility_score,
        (s.low_crash_pctile * 0.40 + s.low_weather_pctile * 0.35 + s.speed_compat_pctile * 0.25) * 0.25 AS safety_score,
        (s.strategic_visibility * 0.40 + s.corridor_importance * 0.60) * 0.25 AS pilot_value_score,
        (s.demand_pctile) * 0.25
        + (s.power_prox_pctile * 0.50 + s.low_interchange_pctile * 0.30) * 0.25
        + (s.low_crash_pctile * 0.40 + s.low_weather_pctile * 0.35 + s.speed_compat_pctile * 0.25) * 0.25
        + (s.strategic_visibility * 0.40 + s.corridor_importance * 0.60) * 0.25 AS composite_score
    FROM scored s
),

ranked_per_corridor AS (
    SELECT
        fs.*,
        ROW_NUMBER() OVER (
            PARTITION BY fs.CORRIDOR
            ORDER BY fs.composite_score DESC
        ) AS corridor_rank
    FROM final_scores fs
),

pick1 AS (
    SELECT * FROM ranked_per_corridor WHERE corridor_rank = 1
),

pick2_stl_chi AS (
    SELECT r.*
    FROM ranked_per_corridor r
    CROSS JOIN (SELECT * FROM pick1 WHERE CORRIDOR = 'STL_CHI') p1
    WHERE r.CORRIDOR = 'STL_CHI'
      AND r.corridor_rank > 1
      AND (r.INTERSTATE != p1.INTERSTATE
           OR ABS(r.START_MILE - p1.START_MILE) >= 50)
    ORDER BY r.composite_score DESC
    LIMIT 1
),

pick2_stl_kc AS (
    SELECT r.*
    FROM ranked_per_corridor r
    CROSS JOIN (SELECT * FROM pick1 WHERE CORRIDOR = 'STL_KC') p1
    WHERE r.CORRIDOR = 'STL_KC'
      AND r.corridor_rank > 1
      AND (r.INTERSTATE != p1.INTERSTATE
           OR ABS(r.START_MILE - p1.START_MILE) >= 50)
    ORDER BY r.composite_score DESC
    LIMIT 1
),

final_picks AS (
    SELECT * FROM pick1
    UNION ALL
    SELECT * FROM pick2_stl_chi
    UNION ALL
    SELECT * FROM pick2_stl_kc
)

SELECT
    fp.SEGMENT_ID,
    fp.INTERSTATE,
    fp.CORRIDOR,
    fp.START_MILE || ' - ' || fp.END_MILE AS MILE_RANGE,
    fp.LANES,
    fp.SPEED_LIMIT,
    fp.AADT_TOTAL,
    fp.AADT_EV,
    fp.AADT_TRUCK,
    fp.PEAK_FACTOR,
    fp.WEATHER_RISK_SCORE,
    fp.CRASH_RATE,
    fp.INCIDENT_RATE,
    ROUND(fp.min_power_dist_m / 1000, 1) AS NEAREST_POWER_KM,
    fp.power_assets_30km AS POWER_ASSETS_WITHIN_30KM,
    fp.interchange_count AS INTERCHANGES_NEARBY,
    ROUND(fp.demand_score, 4) AS DEMAND_SCORE,
    ROUND(fp.feasibility_score, 4) AS FEASIBILITY_SCORE,
    ROUND(fp.safety_score, 4) AS SAFETY_SCORE,
    ROUND(fp.pilot_value_score, 4) AS PILOT_VALUE_SCORE,
    ROUND(fp.composite_score, 4) AS COMPOSITE_SCORE,
    fp.corridor_rank AS RANK_IN_CORRIDOR
FROM final_picks fp
ORDER BY fp.CORRIDOR, fp.corridor_rank;