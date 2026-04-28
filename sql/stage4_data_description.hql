USE team3_projectdb;

DROP TABLE IF EXISTS stage4_dataset_counts;
DROP TABLE IF EXISTS stage4_project_summary;
DROP TABLE IF EXISTS stage4_feature_engineering_summary;

CREATE TABLE stage4_dataset_counts AS
SELECT 'accidents_part' AS table_name, COUNT(*) AS record_count
FROM accidents_part
UNION ALL
SELECT 'locations_part' AS table_name, COUNT(*) AS record_count
FROM locations_part
UNION ALL
SELECT 'weather_buck' AS table_name, COUNT(*) AS record_count
FROM weather_buck
UNION ALL
SELECT 'twilight_buck' AS table_name, COUNT(*) AS record_count
FROM twilight_buck
UNION ALL
SELECT 'road_features_buck' AS table_name, COUNT(*) AS record_count
FROM road_features_buck
UNION ALL
SELECT 'stage4_evaluation' AS table_name, COUNT(*) AS record_count
FROM stage4_evaluation
UNION ALL
SELECT 'stage4_model1_predictions' AS table_name, COUNT(*) AS record_count
FROM stage4_model1_predictions
UNION ALL
SELECT 'stage4_model2_predictions' AS table_name, COUNT(*) AS record_count
FROM stage4_model2_predictions;

CREATE TABLE stage4_project_summary AS
SELECT
    'Project title' AS item,
    'US Accident Severity Analytics and Prediction' AS description
UNION ALL
SELECT
    'Business objective' AS item,
    'Predict accident severity and identify conditions associated with higher accident risk.' AS description
UNION ALL
SELECT
    'Dataset' AS item,
    'US Accidents dataset from Kaggle, containing traffic accident records from 2016 to 2023.' AS description
UNION ALL
SELECT
    'Target column' AS item,
    'severity' AS description
UNION ALL
SELECT
    'ML task' AS item,
    'Multiclass classification with severity labels 1, 2, 3, and 4.' AS description
UNION ALL
SELECT
    'Selected storage format' AS item,
    'Parquet with Snappy compression, selected after Stage 1 benchmarking.' AS description
UNION ALL
SELECT
    'Best overall model' AS item,
    'Unweighted Multinomial Logistic Regression from the baseline run.' AS description
UNION ALL
SELECT
    'Best imbalance-aware model' AS item,
    'Weighted Multinomial Logistic Regression using inverse-frequency class weights.' AS description;

CREATE TABLE stage4_feature_engineering_summary AS
SELECT
    'Temporal features' AS feature_group,
    'Extracted year, month, day, day of week, hour, minute, and second from start_time. Cyclical sine/cosine encoding was applied.' AS description
UNION ALL
SELECT
    'Geospatial features' AS feature_group,
    'Latitude and longitude were transformed into ECEF coordinates: ecef_x, ecef_y, and ecef_z.' AS description
UNION ALL
SELECT
    'Weather features' AS feature_group,
    'Temperature, wind chill, humidity, pressure, visibility, wind speed, precipitation, wind direction, and weather condition were included.' AS description
UNION ALL
SELECT
    'Road context features' AS feature_group,
    'Road indicators such as crossing, junction, railway, stop, traffic signal, bump, amenity, and roundabout were included.' AS description
UNION ALL
SELECT
    'Categorical processing' AS feature_group,
    'StringIndexer and OneHotEncoder were used for categorical fields with invalid values kept safely.' AS description
UNION ALL
SELECT
    'Missing values' AS feature_group,
    'Categorical missing values were filled with unknown values, and numeric missing values were handled using median imputation.' AS description
UNION ALL
SELECT
    'Scaling' AS feature_group,
    'Numeric and encoded features were assembled and scaled using StandardScaler.' AS description
UNION ALL
SELECT
    'Class imbalance' AS feature_group,
    'Inverse-frequency class weights were computed from the training set and applied fairly to both weighted models.' AS description;

SELECT * FROM stage4_dataset_counts;
SELECT * FROM stage4_project_summary;
SELECT * FROM stage4_feature_engineering_summary;
