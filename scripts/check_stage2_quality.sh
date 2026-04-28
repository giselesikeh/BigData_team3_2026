#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_ROOT}"

OUTPUT_FILE="${PROJECT_ROOT}/output/stage2_quality_check.txt"

STAGE2_BASH_FILES=(
  "stage2.sh"
  "scripts/build_hive_tables.sh"
  "scripts/run_stage2_eda.sh"
  "scripts/check_stage2_quality.sh"
)

STAGE2_HQL_FILES=(
  "sql/db.hql"
  "sql/q1.hql"
  "sql/q2.hql"
  "sql/q3.hql"
  "sql/q4.hql"
  "sql/q5.hql"
)

rm -f "${OUTPUT_FILE}"

{
  echo "Stage 2 Quality Check"
  echo "Project root: ${PROJECT_ROOT}"
  echo

  echo "1. Checking required Stage 2 files exist"
  for file in "${STAGE2_BASH_FILES[@]}" "${STAGE2_HQL_FILES[@]}"; do
    if [[ -f "${file}" ]]; then
      echo "[OK] ${file}"
    else
      echo "[ERROR] Missing file: ${file}"
      exit 1
    fi
  done
  echo

  echo "2. Bash syntax check with bash -n"
  for file in "${STAGE2_BASH_FILES[@]}"; do
    bash -n "${file}"
    echo "[OK] bash -n ${file}"
  done
  echo

  echo "3. Pylint availability check"
  python3 -m pylint --version
  echo

  echo "4. Stage 2 Python lint note"
  echo "Stage 2 automation in this project uses Bash and HiveQL."
  echo "There are no dedicated Stage 2 Python scripts to lint."
  echo "Pylint command availability was verified above as required."
  echo

  echo "Stage 2 quality check completed successfully."
} | tee "${OUTPUT_FILE}"

echo
echo "Quality report saved to: ${OUTPUT_FILE}"
