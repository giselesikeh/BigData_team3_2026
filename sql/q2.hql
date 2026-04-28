USE team3_projectdb;

DROP TABLE IF EXISTS q2_results;

CREATE TABLE q2_results
STORED AS PARQUET
AS
SELECT
    wb.weather_condition AS weather_condition,
    COUNT(*) AS accident_count,
    ROUND(AVG(CAST(ap.severity AS DOUBLE)), 2) AS avg_severity,
    ROUND(AVG(ap.duration_minutes), 2) AS avg_duration_minutes
FROM accidents_part ap
JOIN weather_buck wb
    ON ap.weather_id = wb.id
WHERE wb.weather_condition IS NOT NULL
GROUP BY wb.weather_condition;

SELECT *
FROM q2_results
ORDER BY accident_count DESC
LIMIT 20;
