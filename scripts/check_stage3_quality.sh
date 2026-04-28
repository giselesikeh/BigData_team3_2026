#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_ROOT}"

mkdir -p output logs

REPORT_FILE="output/stage3_quality_check.txt"
PYLINT_REPORT="output/stage3_pylint.txt"

exec > >(tee "${REPORT_FILE}") 2>&1

echo "Stage 3 Quality Check"
echo "Project root: ${PROJECT_ROOT}"
echo

echo "1. Checking required Stage 3 files exist"
REQUIRED_FILES=(
  "stage3.sh"
  "scripts/model.py"
  "scripts/run_model_yarn.sh"
  "scripts/check_stage3_quality.sh"
)

for FILE in "${REQUIRED_FILES[@]}"; do
  if [[ -f "${FILE}" ]]; then
    echo "[OK] ${FILE}"
  else
    echo "[ERROR] Missing required file: ${FILE}"
    exit 1
  fi
done
echo

echo "2. Bash syntax check with bash -n"
BASH_FILES=(
  "stage3.sh"
  "scripts/run_model_yarn.sh"
  "scripts/check_stage3_quality.sh"
)

for FILE in "${BASH_FILES[@]}"; do
  bash -n "${FILE}"
  echo "[OK] bash -n ${FILE}"
done
echo

echo "3. Pylint availability check"
pylint --version
echo

echo "4. Running pylint on scripts/model.py"
set +e
pylint scripts/model.py \
  --disable=import-error,no-name-in-module \
  > "${PYLINT_REPORT}" 2>&1
PYLINT_EXIT=$?
set -e

echo "pylint exit code: ${PYLINT_EXIT}"
echo "pylint report saved to: ${PYLINT_REPORT}"
echo

echo "Last 20 lines of pylint report:"
tail -n 20 "${PYLINT_REPORT}" || true
echo

echo "5. Checking expected Stage 3 outputs exist"
EXPECTED_OUTPUTS=(
  "output/evaluation.csv"
  "output/model1_predictions.csv"
  "output/model2_predictions.csv"
  "output/model1_per_class_metrics.csv"
  "output/model2_per_class_metrics.csv"
  "output/model1_confusion_matrix.csv"
  "output/model2_confusion_matrix.csv"
  "output/train_label_distribution.csv"
  "output/test_label_distribution.csv"
)

for FILE in "${EXPECTED_OUTPUTS[@]}"; do
  if [[ -e "${FILE}" ]]; then
    echo "[OK] ${FILE}"
  else
    echo "[WARN] Missing output: ${FILE}"
  fi
done
echo

echo "Stage 3 quality check completed."
echo "Quality report saved to: ${REPORT_FILE}"O

