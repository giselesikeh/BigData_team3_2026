USE team3_projectdb;

DROP TABLE IF EXISTS q5_results;

CREATE TABLE q5_results
STORED AS PARQUET
AS
SELECT
    CASE
        WHEN rf.traffic_signal = true THEN 'Signal Present'
        WHEN rf.traffic_signal = false THEN 'No Signal'
        ELSE 'Unknown'
    END AS traffic_signal_status,
    CASE
        WHEN rf.junction = true THEN 'Junction'
        WHEN rf.junction = false THEN 'Not Junction'
        ELSE 'Unknown'
    END AS junction_status,
    COUNT(*) AS accident_count,
    ROUND(AVG(CAST(ap.severity AS DOUBLE)), 2) AS avg_severity,
    ROUND(AVG(ap.duration_minutes), 2) AS avg_duration_minutes
FROM accidents_part ap
JOIN road_features_buck rf
    ON ap.road_feat_id = rf.id
GROUP BY
    CASE
        WHEN rf.traffic_signal = true THEN 'Signal Present'
        WHEN rf.traffic_signal = false THEN 'No Signal'
        ELSE 'Unknown'
    END,
    CASE
        WHEN rf.junction = true THEN 'Junction'
        WHEN rf.junction = false THEN 'Not Junction'
        ELSE 'Unknown'
    END;

SELECT *
FROM q5_results
ORDER BY accident_count DESC;
