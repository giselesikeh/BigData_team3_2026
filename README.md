# BigData_team3_2026: Codebase Documentation

This document provides a detailed overview of the directory structure and file purposes within the **BigData_team3_2026** project. The project implements a complete data-processing pipeline from data collection to analysis, predictive modeling, and dashboard delivery, designed to run on the **CentOS 7.9.2009** Linux distribution used on the IU cluster.

---

## Repository Structure Overview

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
Folder and File Descriptions
1. data/ Folder

Purpose: This directory serves as the primary storage for both raw input data and intermediate data generated during the pipeline’s execution.

Contents:

US_Accidents_March23.csv
This is the main raw dataset for the project. It is downloaded from Kaggle as the initial step of the pipeline during Stage 1.
train.json and test.json
These JSON files store the preprocessed Spark ML datasets generated in Stage 3 after the feature-engineering and train-test split steps. Saving these files allows the prepared data to be preserved for inspection and reuse without repeating the full preprocessing workflow.
2. logs/ Folder

Purpose: This directory stores log files generated during the execution of the various project scripts.

Contents:
Log files primarily capture standard output, error messages, Beeline execution details, and Spark run logs. These logs are crucial for:

debugging pipeline failures,
monitoring progress of long-running jobs,
checking whether a stage completed successfully,
and auditing execution on the cluster.

Typical examples include:

Hive table creation error logs,
EDA query error logs,
Spark model run logs.
3. models/ Folder

Purpose: This directory is dedicated to storing trained machine-learning models.

Contents:
Serialized Spark ML model artifacts produced in Stage 3.

model1/
Stores the first trained model artifact.
model2/
Stores the second trained model artifact.

In the final project version:

model1 corresponds to the weighted Random Forest Classifier,
model2 corresponds to the weighted Multinomial Logistic Regression model.

These saved models allow later reuse, comparison, and inspection without retraining.

4. output/ Folder

Purpose: This directory acts as the main repository for outputs generated throughout the pipeline, including analytical query results, model predictions, benchmark files, evaluation files, and Stage 4 dashboard-support artifacts.

Contents:

Stage 1 Outputs

These include the benchmark results related to storage format selection and HDFS read performance, such as:

storage import benchmark files,
read benchmark files,
and other Stage 1 pipeline outputs.
Stage 2 Outputs
q1.csv - q5.csv
These CSV files contain the results of the analytical insights generated from Hive. Each file corresponds to one HiveQL query stored in the sql/ folder.
q1.txt - q5.txt
These text files contain terminal-style outputs of the same Hive queries.
q1.jpg - q5.jpg
These image files are exported Apache Superset charts corresponding to the Stage 2 EDA insights.
hive_results.txt
Contains output from the Hive table creation and validation steps.
stage2_quality_check.txt
Contains the results of the Stage 2 quality-check script.
stage2_tables.txt
Contains the list of Hive tables created and used during Stage 2.
Stage 3 Outputs
model1_predictions.csv
model2_predictions.csv
These files store the predictions produced by the trained Spark ML models on the test dataset.
evaluation.csv
Stores the final comparison metrics for the candidate models.
model1_per_class_metrics.csv
model2_per_class_metrics.csv
Store precision, recall, and F1 values for each severity class.
model1_confusion_matrix.csv
model2_confusion_matrix.csv
Store confusion-matrix counts for both models.
train_label_distribution.csv
test_label_distribution.csv
Store the class distribution in the train and test datasets.
model1_prediction_distribution.csv
model2_prediction_distribution.csv
Store the prediction count distribution for each model.
stage3_quality_check.txt
Contains the results of the Stage 3 quality-check script.
Stage 4 Outputs
stage4_tables.txt
Output related to creation and validation of dashboard-ready Hive tables.
stage4_data_description.txt
Output containing the data-description summary tables prepared for the dashboard.
stage4_hive_table_list.txt
Stores the list of Stage 4 Hive tables and views created for Apache Superset delivery.

Overall, the output/ folder is the main local destination for the final reproducible artifacts of the project.

5. scripts/ Folder

Purpose: This central directory houses the Bash and Python scripts that automate and execute the various parts of the pipeline.

Contents:

build_hive_tables.sh
A Bash script responsible for creating the main Hive tables used in Stage 2. It executes the HiveQL in sql/db.hql.
run_stage2_eda.sh
A Bash script that automates the Stage 2 EDA workflow. It executes the Stage 2 HiveQL query files, stores the results in Hive result tables, and exports them to the output/ folder.
model.py
The main Python script for the Spark ML pipeline in Stage 3. It:
reads the prepared Hive tables,
joins them into a modeling dataframe,
performs preprocessing and feature engineering,
creates training and test sets,
trains and evaluates two Spark ML classifiers,
saves the trained models,
and exports predictions and evaluation outputs.
run_model_yarn.sh
A Bash wrapper used to run model.py on Spark YARN with the required environment settings for the cluster.
prepare_stage4_tables.sh
A Bash script for Stage 4. It creates dashboard-ready Hive tables and views from the outputs of earlier stages.
check_stage2_quality.sh
Checks Stage 2 scripts, required files, Bash syntax, and expected outputs.
check_stage3_quality.sh
Checks Stage 3 scripts, required files, Bash syntax, Python linting, and expected outputs.
check_stage4_quality.sh
Checks Stage 4 scripts, required files, and dashboard-support outputs.

This folder contains the core execution logic behind the stage wrappers.

6. sql/ Folder

Purpose: Contains HiveQL scripts used for Hive warehouse creation, analytical query execution, and dashboard-table preparation.

Contents:

db.hql
HiveQL script used to create the main Hive database objects and optimized tables for Stage 2.
q1.hql - q5.hql
HiveQL scripts used to generate the five exploratory data-analysis insights required for Stage 2. Each script:
creates a Hive result table,
inserts the query result,
and supports export of that result to the output/ folder.
stage4_tables.hql
HiveQL script used in Stage 4 to create external Hive tables over the Stage 3 model outputs.
stage4_data_description.hql
HiveQL script used to create the data-description and project-summary tables displayed in the final dashboard.

This folder contains the declarative SQL/Hive logic required by the project.

7. secrets/ Folder

Purpose: Stores sensitive configuration files, mainly credentials used for PostgreSQL, Hive, and related services.

Contents may include:

.psql.pass
A plain-text file containing the PostgreSQL password.
.hive.pass
A plain-text file containing the Hive password, when needed.

This folder should remain excluded from public version control and is used only for project execution on the cluster.

Root Directory Files
main.sh

Purpose: The main entry point for executing the entire data pipeline.

Functionality:
This Bash script orchestrates the execution of the individual stage scripts in the correct order:

stage1.sh
stage2.sh
stage3.sh
stage4.sh

Usage:

cd /home/team3/project/bigdata-accidents-project
bash main.sh

This script is the main script that the project evaluator is expected to run.

stage1.sh

Purpose: Runs the full Stage 1 pipeline.

Functionality:
Stage 1 performs:

data collection from Kaggle,
relational storage and normalization in PostgreSQL,
ingestion into HDFS using Sqoop,
and storage benchmarking.
stage2.sh

Purpose: Runs the full Stage 2 pipeline.

Functionality:
Stage 2 performs:

Hive table creation,
execution of EDA queries,
export of query results,
and generation of local output files for the five analytical insights.
stage3.sh

Purpose: Runs the full Stage 3 pipeline.

Functionality:
Stage 3 performs:

Spark ML preprocessing,
model training on YARN,
hyperparameter tuning and model comparison,
prediction generation,
and export of evaluation files.
stage4.sh

Purpose: Runs the full Stage 4 pipeline.

Functionality:
Stage 4 performs:

creation of dashboard-ready Hive tables,
output validation for presentation artifacts,
and support for final Apache Superset dashboard delivery.
requirements.txt

Purpose: Lists all Python package dependencies required to run the Python scripts used in the project.

Usage:

pip install -r requirements.txt
README.md

Purpose: The primary documentation file for the project. It provides an overview of the repository, directory structure, file purposes, and execution workflow.

.gitignore

Purpose: Specifies files and folders that should not be committed to version control, especially temporary files, cache files, and secrets.

Project Execution Notes

The project is designed to be reproducible and rerunnable.
For example:

rerunning stage1.sh should not fail because old objects are cleared before recreation,
later stages are written to regenerate outputs cleanly,
helper scripts are designed to be executed from the project root.

The main path of the project on the cluster is:

/home/team3/project/bigdata-accidents-project

The required path of the main entry-point script is:

/home/team3/project/bigdata-accidents-project/main.sh
Final Outputs and Dashboard

The final project includes:

a complete data-processing pipeline,
Hive-based analytical outputs,
Spark ML predictive outputs,
saved trained models,
and a published Apache Superset dashboard.

The published dashboard is titled:

US Accident Severity Analytics and Prediction Dashboard

It presents:

data-description outputs,
EDA insights,
machine-learning modeling results,
and business-facing recommendations.

This makes the repository suitable not only for technical reruns, but also for final project presentation and stakeholder communication.
