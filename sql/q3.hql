USE team3_projectdb;

DROP TABLE IF EXISTS q3_results;

CREATE TABLE q3_results
STORED AS PARQUET
AS
SELECT
    CASE
        WHEN ap.start_month IN (12, 1, 2) THEN 'Winter'
        WHEN ap.start_month IN (3, 4, 5) THEN 'Spring'
        WHEN ap.start_month IN (6, 7, 8) THEN 'Summer'
        WHEN ap.start_month IN (9, 10, 11) THEN 'Autumn'
        ELSE 'Unknown'
    END AS season,
    ap.severity AS severity,
    COUNT(*) AS accident_count,
    ROUND(AVG(ap.duration_minutes), 2) AS avg_duration_minutes
FROM accidents_part ap
WHERE ap.start_month IS NOT NULL
GROUP BY
    CASE
        WHEN ap.start_month IN (12, 1, 2) THEN 'Winter'
        WHEN ap.start_month IN (3, 4, 5) THEN 'Spring'
        WHEN ap.start_month IN (6, 7, 8) THEN 'Summer'
        WHEN ap.start_month IN (9, 10, 11) THEN 'Autumn'
        ELSE 'Unknown'
    END,
    ap.severity;

SELECT *
FROM q3_results
ORDER BY accident_count DESC
LIMIT 20;
