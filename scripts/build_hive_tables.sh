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

OUTPUT_FILE="${PROJECT_ROOT}/output/hive_results.txt"
ERROR_FILE="${PROJECT_ROOT}/logs/build_hive_tables.err"

REQUIRED_STAGE1_DIRS=(
  "project/warehouse/accidents"
  "project/warehouse/locations"
  "project/warehouse/weather"
  "project/warehouse/twilight"
  "project/warehouse/road_features"
)

echo "Starting Stage 2 Hive table build..."
echo "Project root: ${PROJECT_ROOT}"

mkdir -p "${PROJECT_ROOT}/output" "${PROJECT_ROOT}/logs"

if [[ -f "${HIVE_PASS_FILE}" ]]; then
  PASSWORD_FILE="${HIVE_PASS_FILE}"
  echo "Using password from secrets/.hive.pass"
elif [[ -f "${PSQL_PASS_FILE}" ]]; then
  PASSWORD_FILE="${PSQL_PASS_FILE}"
  echo "secrets/.hive.pass not found. Falling back to secrets/.psql.pass"
else
  echo "ERROR: No password file found."
  echo "Expected one of:"
  echo "  ${HIVE_PASS_FILE}"
  echo "  ${PSQL_PASS_FILE}"
  exit 1
fi

PASSWORD="$(head -n 1 "${PASSWORD_FILE}")"

command -v beeline >/dev/null 2>&1 || {
  echo "ERROR: beeline is not available in PATH"
  exit 1
}

command -v hdfs >/dev/null 2>&1 || {
  echo "ERROR: hdfs is not available in PATH"
  exit 1
}

echo
echo "Checking Stage 1 HDFS directories..."
for path in "${REQUIRED_STAGE1_DIRS[@]}"; do
  if hdfs dfs -test -d "${path}"; then
    echo "[OK] ${path}"
  else
    echo "[ERROR] Missing required Stage 1 HDFS directory: ${path}"
    exit 1
  fi
done

echo
echo "Cleaning old Stage 2 Hive warehouse path for reruns..."
if hdfs dfs -test -d "project/hive/warehouse"; then
  hdfs dfs -rm -r -skipTrash "project/hive/warehouse"
fi

rm -f "${OUTPUT_FILE}" "${ERROR_FILE}"

echo
echo "Running sql/db.hql with beeline..."
set +e
beeline \
  -u "${HIVE_URL}" \
  -n "${HIVE_USER}" \
  -p "${PASSWORD}" \
  -f sql/db.hql \
  > "${OUTPUT_FILE}" \
  2> "${ERROR_FILE}"
STATUS=$?
set -e

if [[ ${STATUS} -ne 0 ]]; then
  echo
  echo "Hive build failed with exit code ${STATUS}."
  echo "Error log: ${ERROR_FILE}"
  echo "Output file: ${OUTPUT_FILE}"
  echo
  echo "Last 30 lines of error log:"
  tail -n 30 "${ERROR_FILE}" || true
  echo
  echo "Last 30 lines of beeline output:"
  tail -n 30 "${OUTPUT_FILE}" || true
  exit ${STATUS}
fi

echo
echo "Hive table build finished successfully."
echo "Output file: ${OUTPUT_FILE}"
echo "Error log:   ${ERROR_FILE}"

echo
echo "Last 40 lines of Hive output:"
tail -n 40 "${OUTPUT_FILE}"
