#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${PROJECT_ROOT}"

echo "=========================================="
echo "Stage 3: Predictive Data Analytics"
echo "Project root: ${PROJECT_ROOT}"
echo "=========================================="
echo

mkdir -p logs output data models

REQUIRED_FILES=(
  "scripts/model.py"
  "scripts/run_model_yarn.sh"
)

echo "[1/3] Checking required Stage 3 files..."
for FILE in "${REQUIRED_FILES[@]}"; do
  if [[ -f "${FILE}" ]]; then
    echo "[OK] ${FILE}"
  else
    echo "[ERROR] Missing required file: ${FILE}"
    exit 1
  fi
done
echo

echo "[2/3] Running Stage 3 Spark ML pipeline..."
bash scripts/run_model_yarn.sh
echo

echo "[3/3] Verifying Stage 3 outputs..."

REQUIRED_OUTPUTS=(
  "data/train.json"
  "data/test.json"
  "models/model1"
  "models/model2"
  "output/model1_predictions.csv"
  "output/model2_predictions.csv"
  "output/evaluation.csv"
  "output/train_label_distribution.csv"
  "output/test_label_distribution.csv"
  "output/model1_prediction_distribution.csv"
  "output/model2_prediction_distribution.csv"
  "output/model1_per_class_metrics.csv"
  "output/model2_per_class_metrics.csv"
  "output/model1_confusion_matrix.csv"
  "output/model2_confusion_matrix.csv"
)

for ITEM in "${REQUIRED_OUTPUTS[@]}"; do
  if [[ -e "${ITEM}" ]]; then
    echo "[OK] ${ITEM}"
  else
    echo "[ERROR] Missing Stage 3 output: ${ITEM}"
    exit 1
  fi
done
echo

echo "Stage 3 completed successfully."
echo "Key evaluation file:"
echo "  output/evaluation.csv"
echo
echo "Evaluation preview:"
cat output/evaluation.csv
