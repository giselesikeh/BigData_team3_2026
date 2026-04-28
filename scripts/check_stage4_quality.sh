#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/team3/project/bigdata-accidents-project"
cd "$PROJECT_ROOT"

mkdir -p output logs

REPORT="output/stage4_quality_check.txt"
: > "$REPORT"

log() {
  echo "$1" | tee -a "$REPORT"
}

log "Stage 4 Quality Check"
log "Project root: $PROJECT_ROOT"
log ""

log "1. Checking required Stage 4 files exist"

REQUIRED_FILES=(
  "stage4.sh"
  "scripts/prepare_stage4_tables.sh"
  "scripts/check_stage4_quality.sh"
  "sql/stage4_tables.hql"
  "sql/stage4_data_description.hql"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    log "[OK] $file"
  else
    log "[ERROR] Missing $file"
    exit 1
  fi
done

log ""
log "2. Bash syntax check"

BASH_FILES=(
  "stage4.sh"
  "scripts/prepare_stage4_tables.sh"
  "scripts/check_stage4_quality.sh"
)

for file in "${BASH_FILES[@]}"; do
  if bash -n "$file"; then
    log "[OK] bash -n $file"
  else
    log "[ERROR] bash syntax failed: $file"
    exit 1
  fi
done

log ""
log "3. Pylint availability check"

if command -v pylint >/dev/null 2>&1; then
  pylint --version | tee -a "$REPORT"
else
  log "[WARN] pylint is not available on this node."
fi

log ""
log "4. Stage 4 output existence check"

EXPECTED_OUTPUTS=(
  "output/stage4_tables.txt"
  "output/stage4_data_description.txt"
  "output/stage4_hive_table_list.txt"
)

for file in "${EXPECTED_OUTPUTS[@]}"; do
  if [[ -f "$file" ]]; then
    log "[OK] $file"
  else
    log "[WARN] Missing $file. Run: bash scripts/prepare_stage4_tables.sh"
  fi
done

log ""
log "5. Dashboard manual checklist reminder"
log "[INFO] Apache Superset dashboard creation is manual according to the Stage 4 instructions."
log "[INFO] Required dashboard parts: data description, Stage 2 EDA insights, Stage 3 ML modeling results, conclusions, and publication."

log ""
log "Stage 4 quality check completed."
