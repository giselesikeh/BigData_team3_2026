USE team3_projectdb;

DROP VIEW IF EXISTS stage4_label_distribution_all;
DROP VIEW IF EXISTS stage4_prediction_distribution_all;
DROP VIEW IF EXISTS stage4_per_class_metrics_all;
DROP VIEW IF EXISTS stage4_confusion_matrix_all;
DROP VIEW IF EXISTS stage4_prediction_samples_all;
DROP VIEW IF EXISTS stage4_modeling_summary;

DROP TABLE IF EXISTS stage4_evaluation;
DROP TABLE IF EXISTS stage4_train_label_distribution;
DROP TABLE IF EXISTS stage4_test_label_distribution;
DROP TABLE IF EXISTS stage4_model1_prediction_distribution;
DROP TABLE IF EXISTS stage4_model2_prediction_distribution;
DROP TABLE IF EXISTS stage4_model1_per_class_metrics;
DROP TABLE IF EXISTS stage4_model2_per_class_metrics;
DROP TABLE IF EXISTS stage4_model1_confusion_matrix;
DROP TABLE IF EXISTS stage4_model2_confusion_matrix;
DROP TABLE IF EXISTS stage4_model1_predictions;
DROP TABLE IF EXISTS stage4_model2_predictions;

CREATE EXTERNAL TABLE stage4_evaluation (
    model STRING,
    imbalance_strategy STRING,
    accuracy DOUBLE,
    weighted_precision DOUBLE,
    weighted_recall DOUBLE,
    weighted_f1 DOUBLE,
    macro_precision DOUBLE,
    macro_recall DOUBLE,
    macro_f1 DOUBLE
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
    "separatorChar" = ",",
    "quoteChar" = "\""
)
STORED AS TEXTFILE
LOCATION '/user/team3/project/output/evaluation'
TBLPROPERTIES ("skip.header.line.count"="1");

CREATE EXTERNAL TABLE stage4_train_label_distribution (
    severity INT,
    record_count BIGINT
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
    "separatorChar" = ",",
    "quoteChar" = "\""
)
STORED AS TEXTFILE
LOCATION '/user/team3/project/output/train_label_distribution'
TBLPROPERTIES ("skip.header.line.count"="1");

CREATE EXTERNAL TABLE stage4_test_label_distribution (
    severity INT,
    record_count BIGINT
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
    "separatorChar" = ",",
    "quoteChar" = "\""
)
STORED AS TEXTFILE
LOCATION '/user/team3/project/output/test_label_distribution'
TBLPROPERTIES ("skip.header.line.count"="1");

CREATE EXTERNAL TABLE stage4_model1_prediction_distribution (
    severity INT,
    record_count BIGINT
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
    "separatorChar" = ",",
    "quoteChar" = "\""
)
STORED AS TEXTFILE
LOCATION '/user/team3/project/output/model1_prediction_distribution'
TBLPROPERTIES ("skip.header.line.count"="1");

CREATE EXTERNAL TABLE stage4_model2_prediction_distribution (
    severity INT,
    record_count BIGINT
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
    "separatorChar" = ",",
    "quoteChar" = "\""
)
STORED AS TEXTFILE
LOCATION '/user/team3/project/output/model2_prediction_distribution'
TBLPROPERTIES ("skip.header.line.count"="1");

CREATE EXTERNAL TABLE stage4_model1_per_class_metrics (
    severity INT,
    precision_score DOUBLE,
    recall_score DOUBLE,
    f1_score DOUBLE
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
    "separatorChar" = ",",
    "quoteChar" = "\""
)
STORED AS TEXTFILE
LOCATION '/user/team3/project/output/model1_per_class_metrics'
TBLPROPERTIES ("skip.header.line.count"="1");

CREATE EXTERNAL TABLE stage4_model2_per_class_metrics (
    severity INT,
    precision_score DOUBLE,
    recall_score DOUBLE,
    f1_score DOUBLE
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
    "separatorChar" = ",",
    "quoteChar" = "\""
)
STORED AS TEXTFILE
LOCATION '/user/team3/project/output/model2_per_class_metrics'
TBLPROPERTIES ("skip.header.line.count"="1");

CREATE EXTERNAL TABLE stage4_model1_confusion_matrix (
    true_severity INT,
    predicted_severity INT,
    record_count BIGINT
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
    "separatorChar" = ",",
    "quoteChar" = "\""
)
STORED AS TEXTFILE
LOCATION '/user/team3/project/output/model1_confusion_matrix'
TBLPROPERTIES ("skip.header.line.count"="1");

CREATE EXTERNAL TABLE stage4_model2_confusion_matrix (
    true_severity INT,
    predicted_severity INT,
    record_count BIGINT
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
    "separatorChar" = ",",
    "quoteChar" = "\""
)
STORED AS TEXTFILE
LOCATION '/user/team3/project/output/model2_confusion_matrix'
TBLPROPERTIES ("skip.header.line.count"="1");

CREATE EXTERNAL TABLE stage4_model1_predictions (
    true_severity INT,
    predicted_severity INT
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
    "separatorChar" = ",",
    "quoteChar" = "\""
)
STORED AS TEXTFILE
LOCATION '/user/team3/project/output/model1_predictions'
TBLPROPERTIES ("skip.header.line.count"="1");

CREATE EXTERNAL TABLE stage4_model2_predictions (
    true_severity INT,
    predicted_severity INT
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
    "separatorChar" = ",",
    "quoteChar" = "\""
)
STORED AS TEXTFILE
LOCATION '/user/team3/project/output/model2_predictions'
TBLPROPERTIES ("skip.header.line.count"="1");

CREATE VIEW stage4_label_distribution_all AS
SELECT 'Train set' AS dataset_split, severity, record_count
FROM stage4_train_label_distribution
UNION ALL
SELECT 'Test set' AS dataset_split, severity, record_count
FROM stage4_test_label_distribution;

CREATE VIEW stage4_prediction_distribution_all AS
SELECT 'Weighted Random Forest' AS model, severity, record_count
FROM stage4_model1_prediction_distribution
UNION ALL
SELECT 'Weighted Multinomial Logistic Regression' AS model, severity, record_count
FROM stage4_model2_prediction_distribution;

CREATE VIEW stage4_per_class_metrics_all AS
SELECT
    'Weighted Random Forest' AS model,
    severity,
    precision_score,
    recall_score,
    f1_score
FROM stage4_model1_per_class_metrics
UNION ALL
SELECT
    'Weighted Multinomial Logistic Regression' AS model,
    severity,
    precision_score,
    recall_score,
    f1_score
FROM stage4_model2_per_class_metrics;

CREATE VIEW stage4_confusion_matrix_all AS
SELECT
    'Weighted Random Forest' AS model,
    true_severity,
    predicted_severity,
    record_count
FROM stage4_model1_confusion_matrix
UNION ALL
SELECT
    'Weighted Multinomial Logistic Regression' AS model,
    true_severity,
    predicted_severity,
    record_count
FROM stage4_model2_confusion_matrix;

CREATE VIEW stage4_prediction_samples_all AS
SELECT
    'Weighted Random Forest' AS model,
    true_severity,
    predicted_severity
FROM stage4_model1_predictions
UNION ALL
SELECT
    'Weighted Multinomial Logistic Regression' AS model,
    true_severity,
    predicted_severity
FROM stage4_model2_predictions;

CREATE VIEW stage4_modeling_summary AS
SELECT
    model,
    imbalance_strategy,
    accuracy,
    weighted_precision,
    weighted_recall,
    weighted_f1,
    macro_precision,
    macro_recall,
    macro_f1,
    CASE
        WHEN model = 'WeightedMultinomialLogisticRegression'
        THEN 'Best imbalance-aware model. Higher accuracy and F1 than weighted Random Forest.'
        WHEN model = 'WeightedRandomForestClassifier'
        THEN 'Lower overall performance. It overcompensated toward minority classes.'
        ELSE 'Model result'
    END AS conclusion
FROM stage4_evaluation;

SHOW TABLES LIKE 'stage4*';
