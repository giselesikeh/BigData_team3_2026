USE team3_projectdb;

DROP TABLE IF EXISTS q4_results;

CREATE TABLE q4_results
STORED AS PARQUET
AS
SELECT
    lp.state AS state,
    lp.city AS city,
    ap.severity AS severity,
    COUNT(*) AS accident_count,
    ROUND(AVG(ap.duration_minutes), 2) AS avg_duration_minutes
FROM accidents_part ap
JOIN locations_part lp
    ON ap.location_id = lp.id
WHERE lp.state IS NOT NULL
  AND lp.city IS NOT NULL
GROUP BY lp.state, lp.city, ap.severity;

SELECT *
FROM q4_results
ORDER BY accident_count DESC
LIMIT 20;
