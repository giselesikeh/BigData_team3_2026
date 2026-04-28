BEGIN;

DROP TABLE IF EXISTS accidents CASCADE;
DROP TABLE IF EXISTS road_features CASCADE;
DROP TABLE IF EXISTS twilight CASCADE;
DROP TABLE IF EXISTS weather CASCADE;
DROP TABLE IF EXISTS locations CASCADE;
DROP TABLE IF EXISTS staging_raw CASCADE;

-- Raw staging table: same column order as the CSV file
CREATE TABLE staging_raw (
    id                     TEXT PRIMARY KEY,
    source                 TEXT,
    severity               SMALLINT CHECK (severity BETWEEN 1 AND 4),
    start_time             TIMESTAMP,
    end_time               TIMESTAMP,
    start_lat              DOUBLE PRECISION,
    start_lng              DOUBLE PRECISION,
    end_lat                DOUBLE PRECISION,
    end_lng                DOUBLE PRECISION,
    distance_mi            DOUBLE PRECISION,
    description            TEXT,
    street                 TEXT,
    city                   TEXT,
    county                 TEXT,
    state                  CHAR(2),
    zipcode                TEXT,
    country                TEXT,
    timezone               TEXT,
    airport_code           TEXT,
    weather_timestamp      TIMESTAMP,
    temperature_f          DOUBLE PRECISION,
    wind_chill_f           DOUBLE PRECISION,
    humidity_pct           DOUBLE PRECISION,
    pressure_in            DOUBLE PRECISION,
    visibility_mi          DOUBLE PRECISION,
    wind_direction         TEXT,
    wind_speed_mph         DOUBLE PRECISION,
    precipitation_in       DOUBLE PRECISION,
    weather_condition      TEXT,
    amenity                BOOLEAN,
    bump                   BOOLEAN,
    crossing               BOOLEAN,
    give_way               BOOLEAN,
    junction               BOOLEAN,
    no_exit                BOOLEAN,
    railway                BOOLEAN,
    roundabout             BOOLEAN,
    station                BOOLEAN,
    stop                   BOOLEAN,
    traffic_calming        BOOLEAN,
    traffic_signal         BOOLEAN,
    turning_loop           BOOLEAN,
    sunrise_sunset         TEXT,
    civil_twilight         TEXT,
    nautical_twilight      TEXT,
    astronomical_twilight  TEXT
);

-- Location dimension
CREATE TABLE locations (
    id            BIGSERIAL PRIMARY KEY,
    location_key  TEXT UNIQUE NOT NULL,
    start_lat     DOUBLE PRECISION,
    start_lng     DOUBLE PRECISION,
    end_lat       DOUBLE PRECISION,
    end_lng       DOUBLE PRECISION,
    street        TEXT,
    city          TEXT,
    county        TEXT,
    state         CHAR(2),
    zipcode       TEXT,
    country       TEXT,
    timezone      TEXT
);

-- Weather dimension
CREATE TABLE weather (
    id                 BIGSERIAL PRIMARY KEY,
    weather_key        TEXT UNIQUE NOT NULL,
    airport_code       TEXT,
    weather_timestamp  TIMESTAMP,
    temperature_f      DOUBLE PRECISION,
    wind_chill_f       DOUBLE PRECISION,
    humidity_pct       DOUBLE PRECISION,
    pressure_in        DOUBLE PRECISION,
    visibility_mi      DOUBLE PRECISION,
    wind_direction     TEXT,
    wind_speed_mph     DOUBLE PRECISION,
    precipitation_in   DOUBLE PRECISION,
    weather_condition  TEXT
);

-- Twilight dimension
CREATE TABLE twilight (
    id                     SERIAL PRIMARY KEY,
    twilight_key           TEXT UNIQUE NOT NULL,
    sunrise_sunset         TEXT,
    civil_twilight         TEXT,
    nautical_twilight      TEXT,
    astronomical_twilight  TEXT
);

-- Road-features dimension
CREATE TABLE road_features (
    id                  SERIAL PRIMARY KEY,
    road_feat_key       TEXT UNIQUE NOT NULL,
    amenity             BOOLEAN,
    bump                BOOLEAN,
    crossing            BOOLEAN,
    give_way            BOOLEAN,
    junction            BOOLEAN,
    no_exit             BOOLEAN,
    railway             BOOLEAN,
    roundabout          BOOLEAN,
    station             BOOLEAN,
    stop                BOOLEAN,
    traffic_calming     BOOLEAN,
    traffic_signal      BOOLEAN,
    turning_loop        BOOLEAN
);

-- Accident fact table centered on severity (our target)
CREATE TABLE accidents (
    id             TEXT PRIMARY KEY,
    source         TEXT,
    severity       SMALLINT CHECK (severity BETWEEN 1 AND 4),
    start_time     TIMESTAMP,
    end_time       TIMESTAMP,
    distance_mi    DOUBLE PRECISION,
    description    TEXT,

    location_id    BIGINT REFERENCES locations(id),
    weather_id     BIGINT REFERENCES weather(id),
    twilight_id    INTEGER REFERENCES twilight(id),
    road_feat_id   INTEGER REFERENCES road_features(id)
);

COMMIT;
