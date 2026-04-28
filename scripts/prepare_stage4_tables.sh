#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_ROOT}"

mkdir -p output logs

HIVE_HOST="hadoop-03.uni.innopolis.ru"
HIVE_PORT="10001"
HIVE_USER="team3"
HIVE_URL="jdbc:hive2://${HIVE_HOST}:${HIVE_PORT}"

HIVE_PASS_FILE="${PROJECT_ROOT}/secrets/.hive.pass"
PSQL_PASS_FILE="${PROJECT_ROOT}/secrets/.psql.pass"

echo "=========================================="
echo "Stage 4: Preparing Hive tables for dashboard"
echo "Project root: ${PROJECT_ROOT}"
echo "Hive database: team3_projectdb"
echo "Beeline URL: ${HIVE_URL}"
echo "=========================================="

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
echo "[1/5] Checking required Stage 3 HDFS output directories"

REQUIRED_HDFS_DIRS=(
  "/user/team3/project/output/evaluation"
  "/user/team3/project/output/train_label_distribution"
  "/user/team3/project/output/test_label_distribution"
  "/user/team3/project/output/model1_prediction_distribution"
  "/user/team3/project/output/model2_prediction_distribution"
  "/user/team3/project/output/model1_per_class_metrics"
  "/user/team3/project/output/model2_per_class_metrics"
  "/user/team3/project/output/model1_confusion_matrix"
  "/user/team3/project/output/model2_confusion_matrix"
  "/user/team3/project/output/model1_predictions"
  "/user/team3/project/output/model2_predictions"
)

for path in "${REQUIRED_HDFS_DIRS[@]}"; do
  if hdfs dfs -test -d "${path}"; then
    echo "[OK] ${path}"
  else
    echo "[ERROR] Missing HDFS directory: ${path}"
    exit 1
  fi
done

echo
echo "[2/5] Creating Stage 4 external Hive tables and views"

rm -f output/stage4_tables.txt logs/stage4_tables.err

set +e
beeline \
  -u "${HIVE_URL}" \
  -n "${HIVE_USER}" \
  -p "${PASSWORD}" \
  -f sql/stage4_tables.hql \
  > output/stage4_tables.txt \
  2> logs/stage4_tables.err
STATUS=$?
set -e

if [[ ${STATUS} -ne 0 ]]; then
  echo "[ERROR] Stage 4 Hive table creation failed with exit code ${STATUS}"
  echo "Error log: logs/stage4_tables.err"
  echo "Output file: output/stage4_tables.txt"
  tail -n 40 logs/stage4_tables.err || true
  tail -n 40 output/stage4_tables.txt || true
  exit "${STATUS}"
fi

echo "[OK] Stage 4 external tables created"

echo
echo "[3/5] Creating Stage 4 data-description tables"

rm -f output/stage4_data_description.txt logs/stage4_data_description.err

set +e
beeline \
  -u "${HIVE_URL}" \
  -n "${HIVE_USER}" \
  -p "${PASSWORD}" \
  -f sql/stage4_data_description.hql \
  > output/stage4_data_description.txt \
  2> logs/stage4_data_description.err
STATUS=$?
set -e

if [[ ${STATUS} -ne 0 ]]; then
  echo "[ERROR] Stage 4 data-description table creation failed with exit code ${STATUS}"
  echo "Error log: logs/stage4_data_description.err"
  echo "Output file: output/stage4_data_description.txt"
  tail -n 40 logs/stage4_data_description.err || true
  tail -n 40 output/stage4_data_description.txt || true
  exit "${STATUS}"
fi

echo "[OK] Stage 4 data-description tables created"

echo
echo "[4/5] Exporting PostgreSQL data-description information"

if ! command -v psql >/dev/null 2>&1; then
  echo "[WARN] psql command not found on this node. Skipping PostgreSQL exports."
  echo "table_name,row_count" > output/stage4_psql_table_counts.csv
  echo "psql_not_available,0" >> output/stage4_psql_table_counts.csv
  echo "table_name,column_name,data_type" > output/stage4_psql_column_datatypes.csv
  echo "psql_not_available,psql_not_available,psql_not_available" >> output/stage4_psql_column_datatypes.csv
  echo "note" > output/stage4_psql_accident_samples.csv
  echo "psql command not available on this node; Hive data-description tables were created instead." >> output/stage4_psql_accident_samples.csv
elif [[ -f "${PSQL_PASS_FILE}" ]]; then
  export PGPASSWORD
  PGPASSWORD="$(head -n 1 "${PSQL_PASS_FILE}")"

  psql -h hadoop-04 -U team3 -d team3_projectdb -Atc "
SELECT table_name || ',' || row_count
FROM (
  SELECT 'accidents' AS table_name, COUNT(*) AS row_count FROM accidents
  UNION ALL
  SELECT 'locations' AS table_name, COUNT(*) AS row_count FROM locations
  UNION ALL
  SELECT 'weather' AS table_name, COUNT(*) AS row_count FROM weather
  UNION ALL
  SELECT 'twilight' AS table_name, COUNT(*) AS row_count FROM twilight
  UNION ALL
  SELECT 'road_features' AS table_name, COUNT(*) AS row_count FROM road_features
) s
ORDER BY table_name;
" > output/stage4_psql_table_counts.csv

  sed -i '1itable_name,row_count' output/stage4_psql_table_counts.csv

  psql -h hadoop-04 -U team3 -d team3_projectdb -Atc "
SELECT table_name || ',' || column_name || ',' || data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('accidents','locations','weather','twilight','road_features')
ORDER BY table_name, ordinal_position;
" > output/stage4_psql_column_datatypes.csv

  sed -i '1itable_name,column_name,data_type' output/stage4_psql_column_datatypes.csv

  psql -h hadoop-04 -U team3 -d team3_projectdb -c "
COPY (
  SELECT id, severity, start_time, distance_mi, location_id, weather_id, twilight_id, road_feat_id
  FROM accidents
  LIMIT 20
) TO STDOUT WITH CSV HEADER;
" > output/stage4_psql_accident_samples.csv

  echo "[OK] PostgreSQL data-description exports created"
else
  echo "[WARN] secrets/.psql.pass not found. Skipping PostgreSQL exports."
fi

echo
echo "[5/5] Showing Stage 4 Hive tables"

rm -f output/stage4_hive_table_list.txt logs/stage4_hive_table_list.err

beeline \
  -u "${HIVE_URL}" \
  -n "${HIVE_USER}" \
  -p "${PASSWORD}" \
  -e "USE team3_projectdb; SHOW TABLES LIKE 'stage4*';" \
  > output/stage4_hive_table_list.txt \
  2> logs/stage4_hive_table_list.err

cat output/stage4_hive_table_list.txt

echo
echo "=========================================="
echo "Stage 4 table preparation completed."
echo "Outputs:"
echo "  output/stage4_tables.txt"
echo "  output/stage4_data_description.txt"
echo "  output/stage4_hive_table_list.txt"
echo "  output/stage4_psql_table_counts.csv"
echo "  output/stage4_psql_column_datatypes.csv"
echo "  output/stage4_psql_accident_samples.csv"
echo "=========================================="
