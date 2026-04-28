DROP DATABASE IF EXISTS team3_projectdb CASCADE;
CREATE DATABASE team3_projectdb LOCATION 'project/hive/warehouse';

USE team3_projectdb;

SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;
SET hive.exec.max.dynamic.partitions = 5000;
SET hive.exec.max.dynamic.partitions.pernode = 5000;
SET hive.enforce.bucketing = true;
SET hive.exec.compress.output = true;
SET parquet.compression = SNAPPY;
SET hive.resultset.use.unique.column.names = false;

-- Keep Hive away from the Parquet vectorized timestamp path
SET hive.vectorized.execution.enabled = false;
SET hive.vectorized.execution.reduce.enabled = false;
SET hive.vectorized.execution.reduce.groupby.enabled = false;
SET hive.vectorized.use.vectorized.input.format = false;

-- ============================================================
-- Base external Hive tables over Stage 1 Parquet data
-- Raw time columns are BIGINT because Sqoop Parquet stored them
-- without the timestamp annotation Hive expects.
-- ============================================================

DROP TABLE IF EXISTS accidents;
DROP TABLE IF EXISTS locations;
DROP TABLE IF EXISTS weather;
DROP TABLE IF EXISTS twilight;
DROP TABLE IF EXISTS road_features;

CREATE EXTERNAL TABLE accidents (
    id            STRING,
    source        STRING,
    severity      INT,
    start_time    BIGINT,
    end_time      BIGINT,
    description   STRING,
    distance_mi   DOUBLE,
    location_id   INT,
    weather_id    INT,
    twilight_id   INT,
    road_feat_id  INT
)
STORED AS PARQUET
LOCATION 'project/warehouse/accidents';

CREATE EXTERNAL TABLE locations (
    id         INT,
    start_lat  DOUBLE,
    start_lng  DOUBLE,
    end_lat    DOUBLE,
    end_lng    DOUBLE,
    street     STRING,
    city       STRING,
    county     STRING,
    state      STRING,
    zipcode    STRING,
    timezone   STRING
)
STORED AS PARQUET
LOCATION 'project/warehouse/locations';

CREATE EXTERNAL TABLE weather (
    id                 INT,
    airport_code       STRING,
    weather_timestamp  BIGINT,
    temperature_f      DOUBLE,
    wind_chill_f       DOUBLE,
    humidity_pct       DOUBLE,
    pressure_in        DOUBLE,
    visibility_mi      DOUBLE,
    wind_direction     STRING,
    wind_speed_mph     DOUBLE,
    precipitation_in   DOUBLE,
    weather_condition  STRING
)
STORED AS PARQUET
LOCATION 'project/warehouse/weather';

CREATE EXTERNAL TABLE twilight (
    id                    INT,
    sunrise_sunset        STRING,
    civil_twilight        STRING,
    nautical_twilight     STRING,
    astronomical_twilight STRING
)
STORED AS PARQUET
LOCATION 'project/warehouse/twilight';

CREATE EXTERNAL TABLE road_features (
    id                INT,
    amenity           BOOLEAN,
    bump              BOOLEAN,
    crossing          BOOLEAN,
    give_way          BOOLEAN,
    junction          BOOLEAN,
    no_exit           BOOLEAN,
    railway           BOOLEAN,
    roundabout        BOOLEAN,
    station           BOOLEAN,
    stop              BOOLEAN,
    traffic_calming   BOOLEAN,
    traffic_signal    BOOLEAN,
    turning_loop      BOOLEAN
)
STORED AS PARQUET
LOCATION 'project/warehouse/road_features';

-- ============================================================
-- Smoke checks on base tables
-- ============================================================

SELECT COUNT(*) AS accidents_count FROM accidents;
SELECT COUNT(*) AS locations_count FROM locations;
SELECT COUNT(*) AS weather_count FROM weather;
SELECT COUNT(*) AS twilight_count FROM twilight;
SELECT COUNT(*) AS road_features_count FROM road_features;

-- ============================================================
-- Optimized Hive tables for Stage 2
-- ============================================================

DROP TABLE IF EXISTS locations_part;
DROP TABLE IF EXISTS weather_buck;
DROP TABLE IF EXISTS twilight_buck;
DROP TABLE IF EXISTS road_features_buck;
DROP TABLE IF EXISTS accidents_part;

CREATE EXTERNAL TABLE locations_part (
    id         INT,
    start_lat  DOUBLE,
    start_lng  DOUBLE,
    end_lat    DOUBLE,
    end_lng    DOUBLE,
    street     STRING,
    county     STRING,
    zipcode    STRING,
    timezone   STRING,
    city       STRING
)
PARTITIONED BY (state STRING)
CLUSTERED BY (city) INTO 32 BUCKETS
STORED AS PARQUET
LOCATION 'project/hive/warehouse/locations_part';

CREATE EXTERNAL TABLE weather_buck (
    id                 INT,
    airport_code       STRING,
    weather_timestamp  TIMESTAMP,
    temperature_f      DOUBLE,
    wind_chill_f       DOUBLE,
    humidity_pct       DOUBLE,
    pressure_in        DOUBLE,
    visibility_mi      DOUBLE,
    wind_direction     STRING,
    wind_speed_mph     DOUBLE,
    precipitation_in   DOUBLE,
    weather_condition  STRING
)
CLUSTERED BY (weather_condition) INTO 32 BUCKETS
STORED AS PARQUET
LOCATION 'project/hive/warehouse/weather_buck';

CREATE EXTERNAL TABLE twilight_buck (
    id                    INT,
    sunrise_sunset        STRING,
    civil_twilight        STRING,
    nautical_twilight     STRING,
    astronomical_twilight STRING
)
CLUSTERED BY (sunrise_sunset) INTO 4 BUCKETS
STORED AS PARQUET
LOCATION 'project/hive/warehouse/twilight_buck';

CREATE EXTERNAL TABLE road_features_buck (
    id                INT,
    amenity           BOOLEAN,
    bump              BOOLEAN,
    crossing          BOOLEAN,
    give_way          BOOLEAN,
    junction          BOOLEAN,
    no_exit           BOOLEAN,
    railway           BOOLEAN,
    roundabout        BOOLEAN,
    station           BOOLEAN,
    stop              BOOLEAN,
    traffic_calming   BOOLEAN,
    traffic_signal    BOOLEAN,
    turning_loop      BOOLEAN
)
CLUSTERED BY (traffic_signal) INTO 4 BUCKETS
STORED AS PARQUET
LOCATION 'project/hive/warehouse/road_features_buck';

CREATE EXTERNAL TABLE accidents_part (
    id                STRING,
    source            STRING,
    start_time        TIMESTAMP,
    end_time          TIMESTAMP,
    description       STRING,
    distance_mi       DOUBLE,
    location_id       INT,
    weather_id        INT,
    twilight_id       INT,
    road_feat_id      INT,
    duration_minutes  DOUBLE,
    start_month       INT
)
PARTITIONED BY (severity INT, year INT)
CLUSTERED BY (start_month) INTO 12 BUCKETS
STORED AS PARQUET
LOCATION 'project/hive/warehouse/accidents_part';

-- ============================================================
-- Load optimized tables
-- ============================================================

INSERT OVERWRITE TABLE locations_part PARTITION (state)
SELECT
    id,
    start_lat,
    start_lng,
    end_lat,
    end_lng,
    street,
    county,
    zipcode,
    timezone,
    city,
    state
FROM locations;

INSERT OVERWRITE TABLE weather_buck
SELECT
    id,
    airport_code,
    CASE
        WHEN weather_timestamp IS NOT NULL
        THEN CAST(from_unixtime(CAST(weather_timestamp / 1000 AS BIGINT)) AS TIMESTAMP)
        ELSE NULL
    END AS weather_timestamp,
    temperature_f,
    wind_chill_f,
    humidity_pct,
    pressure_in,
    visibility_mi,
    wind_direction,
    wind_speed_mph,
    precipitation_in,
    weather_condition
FROM weather;

INSERT OVERWRITE TABLE twilight_buck
SELECT
    id,
    sunrise_sunset,
    civil_twilight,
    nautical_twilight,
    astronomical_twilight
FROM twilight;

INSERT OVERWRITE TABLE road_features_buck
SELECT
    id,
    amenity,
    bump,
    crossing,
    give_way,
    junction,
    no_exit,
    railway,
    roundabout,
    station,
    stop,
    traffic_calming,
    traffic_signal,
    turning_loop
FROM road_features;

INSERT OVERWRITE TABLE accidents_part PARTITION (severity, year)
SELECT
    id,
    source,
    CASE
        WHEN start_time IS NOT NULL
        THEN CAST(from_unixtime(CAST(start_time / 1000 AS BIGINT)) AS TIMESTAMP)
        ELSE NULL
    END AS start_time,
    CASE
        WHEN end_time IS NOT NULL
        THEN CAST(from_unixtime(CAST(end_time / 1000 AS BIGINT)) AS TIMESTAMP)
        ELSE NULL
    END AS end_time,
    description,
    distance_mi,
    location_id,
    weather_id,
    twilight_id,
    road_feat_id,
    CASE
        WHEN start_time IS NOT NULL AND end_time IS NOT NULL
        THEN (end_time - start_time) / 60000.0
        ELSE NULL
    END AS duration_minutes,
    month(CAST(from_unixtime(CAST(start_time / 1000 AS BIGINT)) AS TIMESTAMP)) AS start_month,
    severity,
    year(CAST(from_unixtime(CAST(start_time / 1000 AS BIGINT)) AS TIMESTAMP)) AS year
FROM accidents;

-- ============================================================
-- Delete the unpartitioned/unbucketed base Hive tables
-- EDA must use only optimized tables.
-- ============================================================

DROP TABLE IF EXISTS accidents;
DROP TABLE IF EXISTS locations;
DROP TABLE IF EXISTS weather;
DROP TABLE IF EXISTS twilight;
DROP TABLE IF EXISTS road_features;

-- ============================================================
-- Final checks
-- ============================================================

SHOW TABLES;

DESCRIBE FORMATTED accidents_part;
DESCRIBE FORMATTED locations_part;
DESCRIBE FORMATTED weather_buck;
DESCRIBE FORMATTED road_features_buck;

SELECT COUNT(*) AS accidents_part_count FROM accidents_part;
SELECT COUNT(*) AS locations_part_count FROM locations_part;
SELECT COUNT(*) AS weather_buck_count FROM weather_buck;
SELECT COUNT(*) AS road_features_buck_count FROM road_features_buck;

SELECT
    severity,
    COUNT(*) AS accident_count
FROM accidents_part
GROUP BY severity
ORDER BY severity;

SELECT
    year,
    ROUND(AVG(duration_minutes), 2) AS avg_duration_minutes
FROM accidents_part
GROUP BY year
ORDER BY year;

SELECT
    state,
    COUNT(*) AS accident_count
FROM locations_part
GROUP BY state
ORDER BY accident_count DESC
LIMIT 10;

SELECT
    weather_condition,
    COUNT(*) AS weather_rows
FROM weather_buck
GROUP BY weather_condition
ORDER BY weather_rows DESC
LIMIT 10;
