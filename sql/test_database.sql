-- Number of normalized accident records
SELECT COUNT(*) AS accident_count
FROM accidents;

-- Severity distribution (important for our classification target)
SELECT severity, COUNT(*) AS cnt
FROM accidents
GROUP BY severity
ORDER BY severity;

-- Quick join check with location data
SELECT
    a.id,
    a.severity,
    a.start_time,
    l.city,
    l.state,
    w.weather_condition
FROM accidents a
LEFT JOIN locations l ON a.location_id = l.id
LEFT JOIN weather w   ON a.weather_id = w.id
LIMIT 10;
