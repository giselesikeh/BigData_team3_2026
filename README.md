# US Accident Severity Analytics and Prediction

## Big Data Technologies and Analytics — Final Project

This repository contains the implementation of an end-to-end big data analytics pipeline for analyzing and predicting road accident severity using the **U.S. Accidents March 2023 dataset**.

The project follows the **CRISP-DM methodology** and combines data collection, storage, ingestion, exploratory data analysis, distributed machine learning, and dashboard deployment. The pipeline is designed to run on the **CentOS 7.9.2009** Linux distribution used on the IU Hadoop cluster.

---

## Project Overview

Road accidents create major public-safety, transportation, and economic challenges. This project uses large-scale historical accident data to help transportation stakeholders understand where and under what conditions more severe accidents occur.

The main objective is to build a reproducible big data pipeline that supports:

1. Data collection and storage
2. Distributed ingestion into HDFS
3. Hive-based exploratory data analysis
4. Spark ML accident severity prediction
5. Apache Superset dashboard presentation

---

## Dataset

The project uses the **U.S. Accidents March 2023** dataset from Kaggle.

The dataset contains:

- More than 7.7 million accident records
- 46 original columns
- Temporal features
- Geospatial features
- Weather features
- Road-environment indicators
- Accident severity labels from 1 to 4

The prediction target is **accident severity**.

---

## Business Problem

Transportation authorities usually have limited budgets, limited staff, and limited time. They cannot improve every road segment or monitor every accident-prone area equally.

The business problem is to transform large-scale accident data into useful insights and predictive outputs that can support better road-safety planning and intervention prioritization.

The project focuses on identifying conditions associated with higher accident severity and presenting the results in a clear dashboard for stakeholders.

---

## Technologies Used

- Python
- Bash
- PostgreSQL
- Apache Sqoop
- HDFS
- Apache Hive
- Apache Spark ML
- Apache Superset
- Git and GitHub
- LaTeX / Overleaf

---

## Repository Structure

```text
BigData_team3_2026/
├── main.sh
├── stage1.sh
├── stage2.sh
├── stage3.sh
├── stage4.sh
├── scripts/
├── sql/
├── output/
├── data/
├── models/
├── logs/
├── secrets/
├── requirements.txt
├── README.md
└── .gitignore
```

---

## Folder and File Descriptions

### `data/`

This folder stores raw input data and intermediate data generated during the pipeline execution.

Main files include:

- `US_Accidents_March23.csv` — main raw dataset downloaded from Kaggle during Stage 1.
- `train.json` — preprocessed Spark ML training dataset generated in Stage 3.
- `test.json` — preprocessed Spark ML test dataset generated in Stage 3.

---

### `logs/`

This folder stores log files generated during the execution of the project scripts.

The logs are used for:

- debugging pipeline failures;
- monitoring long-running jobs;
- checking whether each stage completed successfully;
- auditing execution on the cluster.

Typical logs include Hive table creation logs, EDA query logs, and Spark model execution logs.

---

### `models/`

This folder stores trained Spark ML model artifacts produced in Stage 3.

Main model folders:

- `model1/` — weighted Random Forest Classifier.
- `model2/` — weighted Multinomial Logistic Regression.

The saved models allow reuse, comparison, and inspection without retraining.

---

### `output/`

This folder stores the main outputs generated throughout the pipeline, including benchmark files, EDA results, model predictions, evaluation files, and dashboard-support artifacts.

#### Stage 1 Outputs

Stage 1 outputs include benchmark results related to storage format selection and HDFS read performance.

Examples include:

- storage import benchmark files;
- read benchmark files;
- Stage 1 pipeline output files.

#### Stage 2 Outputs

Stage 2 outputs include EDA query results and Superset chart exports.

Main files include:

- `q1.csv` to `q5.csv` — CSV outputs for the five Hive EDA queries.
- `q1.txt` to `q5.txt` — terminal-style outputs of the same Hive queries.
- `q1.jpg` to `q5.jpg` — Apache Superset chart images for the EDA insights.
- `hive_results.txt` — output from Hive table creation and validation.
- `stage2_quality_check.txt` — Stage 2 quality-check result.
- `stage2_tables.txt` — list of Hive tables created and used during Stage 2.

#### Stage 3 Outputs

Stage 3 outputs include model predictions, evaluation results, per-class metrics, and diagnostic files.

Main files include:

- `model1_predictions.csv`
- `model2_predictions.csv`
- `evaluation.csv`
- `model1_per_class_metrics.csv`
- `model2_per_class_metrics.csv`
- `model1_confusion_matrix.csv`
- `model2_confusion_matrix.csv`
- `train_label_distribution.csv`
- `test_label_distribution.csv`
- `model1_prediction_distribution.csv`
- `model2_prediction_distribution.csv`
- `stage3_quality_check.txt`

#### Stage 4 Outputs

Stage 4 outputs support the final Apache Superset dashboard delivery.

Main files include:

- `stage4_tables.txt`
- `stage4_data_description.txt`
- `stage4_hive_table_list.txt`

Overall, the `output/` folder is the main local destination for the final reproducible artifacts of the project.

---

### `scripts/`

This folder contains the Bash and Python scripts that automate and execute the main parts of the pipeline.

Main scripts include:

- `build_hive_tables.sh` — creates the main Hive tables used in Stage 2 by executing `sql/db.hql`.
- `run_stage2_eda.sh` — runs the Stage 2 EDA HiveQL queries and exports results to the `output/` folder.
- `model.py` — main Spark ML script for Stage 3.
- `run_model_yarn.sh` — runs `model.py` on Spark YARN with the required cluster settings.
- `prepare_stage4_tables.sh` — creates dashboard-ready Hive tables and views for Stage 4.
- `check_stage2_quality.sh` — checks Stage 2 scripts, required files, Bash syntax, and expected outputs.
- `check_stage3_quality.sh` — checks Stage 3 scripts, required files, Python syntax, and expected outputs.
- `check_stage4_quality.sh` — checks Stage 4 scripts, required files, and dashboard-support outputs.

The `scripts/` folder contains the core execution logic behind the stage wrapper scripts.

---

### `sql/`

This folder contains HiveQL scripts used for Hive warehouse creation, analytical query execution, and dashboard-table preparation.

Main files include:

- `db.hql` — creates the main Hive database objects and optimized tables for Stage 2.
- `q1.hql` to `q5.hql` — generate the five exploratory data-analysis insights required for Stage 2.
- `stage4_tables.hql` — creates external Hive tables over Stage 3 model outputs.
- `stage4_data_description.hql` — creates data-description and project-summary tables used in the final dashboard.

This folder contains the declarative SQL/Hive logic required by the project.

---

### `secrets/`

This folder stores sensitive configuration files used for project execution on the cluster.

Possible files include:

- `.psql.pass` — PostgreSQL password file.
- `.hive.pass` — Hive password file, when needed.

This folder should remain excluded from public version control and should not be exposed in the public repository.

---

## Pipeline Stages

### Stage 1: Data Collection, Storage, and Ingestion

Stage 1 downloads the dataset, loads it into PostgreSQL, normalizes the schema, exports the tables to HDFS using Sqoop, and benchmarks storage formats.

The tested storage formats were:

1. Parquet + Snappy
2. Avro + Snappy

The final selected storage format was:

**Parquet + Snappy**

This format was selected because it gave faster import time, smaller HDFS size, and slightly better read performance compared with Avro + Snappy.

---

### Stage 2: Hive Warehouse and Exploratory Data Analysis

Stage 2 creates Hive external tables and optimized analytical tables. It also runs exploratory data analysis queries to study accident patterns.

The EDA includes insights about:

1. Accident counts by state and severity
2. Weather conditions and accident patterns
3. Seasonal accident distribution
4. Top cities by accident count and severity
5. Road-context indicators such as junctions and traffic signals

The EDA results are exported for reporting and dashboarding.

---

### Stage 3: Spark ML Modeling

Stage 3 trains and evaluates machine learning models using Spark ML on YARN.

The original accident severity labels are 1, 2, 3, and 4. For Spark ML compatibility, they are transformed into labels 0, 1, 2, and 3.

The models compared are:

1. Random Forest Classifier
2. Multinomial Logistic Regression

Class weighting was introduced to handle the strong imbalance in the severity labels.

The final approved model is:

**Weighted Multinomial Logistic Regression**

It was selected because it gave a better balance between overall predictive performance and minority-class recall than the weighted Random Forest model.

---

### Stage 4: Superset Dashboard Deployment

Stage 4 prepares dashboard-ready Hive tables and supports the final Apache Superset dashboard.

The dashboard is titled:

**US Accident Severity Analytics and Prediction Dashboard**

The dashboard contains four main sections:

1. Data Description
2. EDA Insights
3. ML Modeling Results
4. Business Recommendations

This dashboard presents both descriptive analytics and machine learning results in a stakeholder-friendly format.

---

## How to Run the Project

The full project can be executed from the repository root using:

```bash
bash main.sh
```

The main script runs all project stages in sequence:

```bash
bash stage1.sh
bash stage2.sh
bash stage3.sh
bash stage4.sh
```

---

## Cluster Location

The project was executed on the IU Hadoop cluster.

Main project path on the cluster:

```bash
/home/team3/project/bigdata-accidents-project/main.sh
```

To run the full pipeline on the cluster:

```bash
cd /home/team3/project/bigdata-accidents-project
bash main.sh
```

---

## Root Directory Files

### `main.sh`

The main entry point for executing the entire data pipeline. This script orchestrates the execution of:

1. `stage1.sh`
2. `stage2.sh`
3. `stage3.sh`
4. `stage4.sh`

This is the main script that the project evaluator is expected to run.

---

### `stage1.sh`

Runs the full Stage 1 pipeline.

Stage 1 performs:

- data collection from Kaggle;
- relational storage and normalization in PostgreSQL;
- ingestion into HDFS using Sqoop;
- storage benchmarking.

---

### `stage2.sh`

Runs the full Stage 2 pipeline.

Stage 2 performs:

- Hive table creation;
- execution of EDA queries;
- export of query results;
- generation of local output files for the five analytical insights.

---

### `stage3.sh`

Runs the full Stage 3 pipeline.

Stage 3 performs:

- Spark ML preprocessing;
- model training on YARN;
- hyperparameter tuning and model comparison;
- prediction generation;
- export of evaluation files.

---

### `stage4.sh`

Runs the full Stage 4 pipeline.

Stage 4 performs:

- creation of dashboard-ready Hive tables;
- output validation for presentation artifacts;
- support for final Apache Superset dashboard delivery.

---

### `requirements.txt`

Lists the Python package dependencies required to run the Python scripts used in the project.

Usage:

```bash
pip install -r requirements.txt
```

---

### `.gitignore`

Specifies files and folders that should not be committed to version control, especially temporary files, cache files, large raw data, and secret files.

---

## Main Outputs

The project generates the following outputs:

- HDFS-ingested Parquet tables
- Hive analytical tables
- EDA query results
- Superset dashboard charts
- Train and test datasets
- Trained Spark ML models
- Model predictions
- Evaluation metrics
- Confusion matrices
- Per-class performance reports
- Stage 4 dashboard-ready tables

---

## Model Evaluation Summary

The final evaluation showed that the weighted Logistic Regression model outperformed the weighted Random Forest model in the most important business-aware metrics.

The weighted Logistic Regression model improved recall for less frequent severity classes. However, this came with lower precision for minority classes.

Therefore, the final model is best used as a **decision-support tool** rather than as a fully automated operational system.

---

## Deployment

The project is deployed as a reproducible analytical pipeline and dashboard-ready reporting system.

It does not expose a real-time prediction API. Instead, it provides a complete batch-processing workflow that can be rerun from the repository root.

The final deployment output includes the Apache Superset dashboard and the saved analytical/modeling artifacts.

---

## Project Execution Notes

The project is designed to be reproducible and rerunnable.

For example:

- rerunning `stage1.sh` should not fail because old objects are cleared before recreation;
- later stages are written to regenerate outputs cleanly;
- helper scripts are designed to be executed from the project root.

The main path of the project on the cluster is:

```bash
/home/team3/project/bigdata-accidents-project
```

The required path of the main entry-point script is:

```bash
/home/team3/project/bigdata-accidents-project/main.sh
```

---

## Project Artifacts

The final project submission includes:

- GitHub repository
- Detailed project report
- Pitch presentation
- Recorded presentation

---

## Team Members

- **Gisele Wiykiynyuy Sikeh**
- **Tivdzua Lubem Noah**

---

## Course

**Big Data Technologies and Analytics**  
**Innopolis University**  
**Spring 2026**

---

## Final Dashboard

The published Apache Superset dashboard is titled:

**US Accident Severity Analytics and Prediction Dashboard**

It presents:

- data-description outputs;
- EDA insights;
- machine-learning modeling results;
- business-facing recommendations.

This makes the repository suitable not only for technical reruns, but also for final project presentation and stakeholder communication.
