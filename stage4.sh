#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/team3/project/bigdata-accidents-project"
cd "$PROJECT_ROOT"

echo "=========================================="
echo "Running Stage 4: Presentation and Delivery"
echo "Project root: $PROJECT_ROOT"
echo "=========================================="

echo
echo "[1/3] Preparing Hive tables for Stage 4 dashboard"
bash scripts/prepare_stage4_tables.sh

echo
echo "[2/3] Running Stage 4 quality check"
bash scripts/check_stage4_quality.sh

echo
echo "[3/3] Stage 4 manual Superset dashboard reminder"
echo "Create/publish the dashboard in Apache Superset using:"
echo "  - Stage 2 EDA result tables: q1_results ... q5_results"
echo "  - Stage 4 data-description tables: stage4_dataset_counts, stage4_project_summary, stage4_feature_engineering_summary"
echo "  - Stage 4 ML tables/views: stage4_evaluation, stage4_modeling_summary, stage4_label_distribution_all,"
echo "    stage4_prediction_distribution_all, stage4_per_class_metrics_all, stage4_confusion_matrix_all"
echo
echo "Recommended dashboard title:"
echo "  US Accident Severity Analytics and Prediction Dashboard"

echo
echo "=========================================="
echo "Stage 4 automation completed successfully."
echo "Now finish the manual dashboard layout and publishing in Superset."
echo "=========================================="
