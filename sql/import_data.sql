BEGIN;

-- 1. Populate locations dimension
INSERT INTO locations (
    location_key, start_lat, start_lng, end_lat, end_lng,
    street, city, county, state, zipcode, country, timezone
)
SELECT DISTINCT
    md5(
        concat_ws('||',
            coalesce(start_lat::text, '<NULL>'),
            coalesce(start_lng::text, '<NULL>'),
            coalesce(end_lat::text, '<NULL>'),
            coalesce(end_lng::text, '<NULL>'),
            coalesce(street, '<NULL>'),
            coalesce(city, '<NULL>'),
            coalesce(county, '<NULL>'),
            coalesce(state, '<NULL>'),
            coalesce(zipcode, '<NULL>'),
            coalesce(country, '<NULL>'),
            coalesce(timezone, '<NULL>')
        )
    ) AS location_key,
    start_lat, start_lng, end_lat, end_lng,
    street, city, county, state, zipcode, country, timezone
FROM staging_raw
ON CONFLICT (location_key) DO NOTHING;

-- 2. Populate weather dimension
INSERT INTO weather (
    weather_key, airport_code, weather_timestamp,
    temperature_f, wind_chill_f, humidity_pct,
    pressure_in, visibility_mi, wind_direction,
    wind_speed_mph, precipitation_in, weather_condition
)
SELECT DISTINCT
    md5(
        concat_ws('||',
            coalesce(airport_code, '<NULL>'),
            coalesce(weather_timestamp::text, '<NULL>'),
            coalesce(temperature_f::text, '<NULL>'),
            coalesce(wind_chill_f::text, '<NULL>'),
            coalesce(humidity_pct::text, '<NULL>'),
            coalesce(pressure_in::text, '<NULL>'),
            coalesce(visibility_mi::text, '<NULL>'),
            coalesce(wind_direction, '<NULL>'),
            coalesce(wind_speed_mph::text, '<NULL>'),
            coalesce(precipitation_in::text, '<NULL>'),
            coalesce(weather_condition, '<NULL>')
        )
    ) AS weather_key,
    airport_code, weather_timestamp,
    temperature_f, wind_chill_f, humidity_pct,
    pressure_in, visibility_mi, wind_direction,
    wind_speed_mph, precipitation_in, weather_condition
FROM staging_raw
ON CONFLICT (weather_key) DO NOTHING;

-- 3. Populate twilight dimension
INSERT INTO twilight (
    twilight_key, sunrise_sunset, civil_twilight,
    nautical_twilight, astronomical_twilight
)
SELECT DISTINCT
    md5(
        concat_ws('||',
            coalesce(sunrise_sunset, '<NULL>'),
            coalesce(civil_twilight, '<NULL>'),
            coalesce(nautical_twilight, '<NULL>'),
            coalesce(astronomical_twilight, '<NULL>')
        )
    ) AS twilight_key,
    sunrise_sunset, civil_twilight,
    nautical_twilight, astronomical_twilight
FROM staging_raw
ON CONFLICT (twilight_key) DO NOTHING;

-- 4. Populate road_features dimension
INSERT INTO road_features (
    road_feat_key, amenity, bump, crossing, give_way, junction,
    no_exit, railway, roundabout, station, stop,
    traffic_calming, traffic_signal, turning_loop
)
SELECT DISTINCT
    md5(
        concat_ws('||',
            coalesce(amenity::text, '<NULL>'),
            coalesce(bump::text, '<NULL>'),
            coalesce(crossing::text, '<NULL>'),
            coalesce(give_way::text, '<NULL>'),
            coalesce(junction::text, '<NULL>'),
            coalesce(no_exit::text, '<NULL>'),
            coalesce(railway::text, '<NULL>'),
            coalesce(roundabout::text, '<NULL>'),
            coalesce(station::text, '<NULL>'),
            coalesce(stop::text, '<NULL>'),
            coalesce(traffic_calming::text, '<NULL>'),
            coalesce(traffic_signal::text, '<NULL>'),
            coalesce(turning_loop::text, '<NULL>')
        )
    ) AS road_feat_key,
    amenity, bump, crossing, give_way, junction,
    no_exit, railway, roundabout, station, stop,
    traffic_calming, traffic_signal, turning_loop
FROM staging_raw
ON CONFLICT (road_feat_key) DO NOTHING;

-- 5. Populate accidents fact table
INSERT INTO accidents (
    id, source, severity, start_time, end_time,
    distance_mi, description, location_id, weather_id,
    twilight_id, road_feat_id
)
SELECT
    s.id,
    s.source,
    s.severity,
    s.start_time,
    s.end_time,
    s.distance_mi,
    s.description,
    l.id AS location_id,
    w.id AS weather_id,
    t.id AS twilight_id,
    rf.id AS road_feat_id
FROM staging_raw s
LEFT JOIN locations l
    ON l.location_key = md5(
        concat_ws('||',
            coalesce(s.start_lat::text, '<NULL>'),
            coalesce(s.start_lng::text, '<NULL>'),
            coalesce(s.end_lat::text, '<NULL>'),
            coalesce(s.end_lng::text, '<NULL>'),
            coalesce(s.street, '<NULL>'),
            coalesce(s.city, '<NULL>'),
            coalesce(s.county, '<NULL>'),
            coalesce(s.state, '<NULL>'),
            coalesce(s.zipcode, '<NULL>'),
            coalesce(s.country, '<NULL>'),
            coalesce(s.timezone, '<NULL>')
        )
    )
LEFT JOIN weather w
    ON w.weather_key = md5(
        concat_ws('||',
            coalesce(s.airport_code, '<NULL>'),
            coalesce(s.weather_timestamp::text, '<NULL>'),
            coalesce(s.temperature_f::text, '<NULL>'),
            coalesce(s.wind_chill_f::text, '<NULL>'),
            coalesce(s.humidity_pct::text, '<NULL>'),
            coalesce(s.pressure_in::text, '<NULL>'),
            coalesce(s.visibility_mi::text, '<NULL>'),
            coalesce(s.wind_direction, '<NULL>'),
            coalesce(s.wind_speed_mph::text, '<NULL>'),
            coalesce(s.precipitation_in::text, '<NULL>'),
            coalesce(s.weather_condition, '<NULL>')
        )
    )
LEFT JOIN twilight t
    ON t.twilight_key = md5(
        concat_ws('||',
            coalesce(s.sunrise_sunset, '<NULL>'),
            coalesce(s.civil_twilight, '<NULL>'),
            coalesce(s.nautical_twilight, '<NULL>'),
            coalesce(s.astronomical_twilight, '<NULL>')
        )
    )
LEFT JOIN road_features rf
    ON rf.road_feat_key = md5(
        concat_ws('||',
            coalesce(s.amenity::text, '<NULL>'),
            coalesce(s.bump::text, '<NULL>'),
            coalesce(s.crossing::text, '<NULL>'),
            coalesce(s.give_way::text, '<NULL>'),
            coalesce(s.junction::text, '<NULL>'),
            coalesce(s.no_exit::text, '<NULL>'),
            coalesce(s.railway::text, '<NULL>'),
            coalesce(s.roundabout::text, '<NULL>'),
            coalesce(s.station::text, '<NULL>'),
            coalesce(s.stop::text, '<NULL>'),
            coalesce(s.traffic_calming::text, '<NULL>'),
            coalesce(s.traffic_signal::text, '<NULL>'),
            coalesce(s.turning_loop::text, '<NULL>')
        )
    )
ON CONFLICT (id) DO NOTHING;

-- 6. Drop staging table after normalization
DROP TABLE staging_raw CASCADE;

-- 7. Indexes for severity-focused analytics
CREATE INDEX IF NOT EXISTS ix_locations_state_city
    ON locations (state, city);

CREATE INDEX IF NOT EXISTS ix_weather_timestamp
    ON weather (weather_timestamp);

CREATE INDEX IF NOT EXISTS ix_accidents_start_time
    ON accidents (start_time);

CREATE INDEX IF NOT EXISTS ix_accidents_severity
    ON accidents (severity);

CREATE INDEX IF NOT EXISTS ix_accidents_severity_time
    ON accidents (severity, start_time DESC);

COMMIT;
