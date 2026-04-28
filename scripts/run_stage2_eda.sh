#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_ROOT}"

HIVE_HOST="hadoop-03.uni.innopolis.ru"
HIVE_PORT="10001"
HIVE_USER="team3"
HIVE_URL="jdbc:hive2://${HIVE_HOST}:${HIVE_PORT}"

HIVE_PASS_FILE="${PROJECT_ROOT}/secrets/.hive.pass"
PSQL_PASS_FILE="${PROJECT_ROOT}/secrets/.psql.pass"

OUTPUT_DIR="${PROJECT_ROOT}/output"
LOG_DIR="${PROJECT_ROOT}/logs"

mkdir -p "${OUTPUT_DIR}" "${LOG_DIR}"

if [[ -f "${HIVE_PASS_FILE}" ]]; then
  PASSWORD_FILE="${HIVE_PASS_FILE}"
  echo "Using password from secrets/.hive.pass"
elif [[ -f "${PSQL_PASS_FILE}" ]]; then
  PASSWORD_FILE="${PSQL_PASS_FILE}"
  echo "secrets/.hive.pass not found. Falling back to secrets/.psql.pass"
else
  echo "ERROR: No password file found."
  exit 1
fi

PASSWORD="$(head -n 1 "${PASSWORD_FILE}")"

command -v beeline >/dev/null 2>&1 || {
  echo "ERROR: beeline is not available in PATH"
  exit 1
}

declare -A RESULT_TABLES=(
  ["q1"]="q1_results"
  ["q2"]="q2_results"
  ["q3"]="q3_results"
  ["q4"]="q4_results"
  ["q5"]="q5_results"
)

QUERIES=(q1 q2 q3 q4 q5)

echo "Starting Stage 2 EDA automation..."
echo "Project root: ${PROJECT_ROOT}"
echo

for Q in "${QUERIES[@]}"; do
  HQL_FILE="sql/${Q}.hql"
  TXT_FILE="${OUTPUT_DIR}/${Q}.txt"
  CSV_FILE="${OUTPUT_DIR}/${Q}.csv"
  ERR_FILE="${LOG_DIR}/${Q}.err"
  RESULT_TABLE="${RESULT_TABLES[$Q]}"

  if [[ ! -f "${HQL_FILE}" ]]; then
    echo "ERROR: Missing query file ${HQL_FILE}"
    exit 1
  fi

  echo "Running ${HQL_FILE} ..."
  rm -f "${TXT_FILE}" "${CSV_FILE}" "${ERR_FILE}"

  set +e
  beeline \
    -u "${HIVE_URL}" \
    -n "${HIVE_USER}" \
    -p "${PASSWORD}" \
    -f "${HQL_FILE}" \
    > "${TXT_FILE}" \
    2> "${ERR_FILE}"
  STATUS=$?
  set -e

  if [[ ${STATUS} -ne 0 ]]; then
    echo "ERROR: ${Q} failed."
    echo "Check:"
    echo "  ${TXT_FILE}"
    echo "  ${ERR_FILE}"
    tail -n 20 "${ERR_FILE}" || true
    exit ${STATUS}
  fi

  beeline \
    --silent=true \
    --showHeader=true \
    --outputformat=csv2 \
    -u "${HIVE_URL}" \
    -n "${HIVE_USER}" \
    -p "${PASSWORD}" \
    -e "USE team3_projectdb; SELECT * FROM ${RESULT_TABLE};" \
    > "${CSV_FILE}" \
    2>> "${ERR_FILE}"

  echo "Finished ${Q}"
  echo "  text output: ${TXT_FILE}"
  echo "  csv output:  ${CSV_FILE}"
  echo "  error log:   ${ERR_FILE}"
  echo
done

echo "All Stage 2 EDA queries completed successfully."
