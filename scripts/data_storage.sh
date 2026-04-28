#!/usr/bin/env bash
set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────────
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASSWORD_FILE="${PROJECT_ROOT}/secrets/.psql.pass"

DB_HOST="hadoop-04.uni.innopolis.ru"
DB_PORT="5432"
DB_NAME="team3_projectdb"
DB_USER="team3"

# HDFS paths relative to /user/team3
HDFS_WAREHOUSE_DIR="project/warehouse"

# Final normalized tables to import
TABLES=(
  accidents
  locations
  road_features
  twilight
  weather
)

# Sqoop format/compression choice
FILE_FORMAT="--as-parquetfile"
COMPRESSION="--compression-codec org.apache.hadoop.io.compress.SnappyCodec --compress"
MAPPERS="1"

# ── CHECKS ────────────────────────────────────────────────────────
echo "Starting HDFS data storage step..."

if [[ ! -f "${PASSWORD_FILE}" ]]; then
  echo "ERROR: PostgreSQL password file not found at ${PASSWORD_FILE}"
  exit 1
fi

PASSWORD="$(head -n 1 "${PASSWORD_FILE}")"
JDBC_URL="jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}"

echo "Using JDBC URL: ${JDBC_URL}"
echo "Target HDFS warehouse: /user/${DB_USER}/${HDFS_WAREHOUSE_DIR}"

# ── CLEAN OLD HDFS OUTPUT ─────────────────────────────────────────
echo "Cleaning old HDFS warehouse directory if it exists..."
hdfs dfs -rm -r -f -skipTrash "${HDFS_WAREHOUSE_DIR}" 2>/dev/null || true

echo "Creating fresh HDFS warehouse parent directory..."
hdfs dfs -mkdir -p "${HDFS_WAREHOUSE_DIR}"

# ── OPTIONAL: SHOW TABLES VISIBLE TO SQOOP ────────────────────────
echo "Listing PostgreSQL tables visible to Sqoop..."
sqoop list-tables \
  --connect "${JDBC_URL}" \
  --username "${DB_USER}" \
  --password "${PASSWORD}"

# ── IMPORT TABLES ONE BY ONE ──────────────────────────────────────
for TABLE in "${TABLES[@]}"; do
  echo
  echo "Importing table: ${TABLE}"

  sqoop import \
    --connect "${JDBC_URL}" \
    --username "${DB_USER}" \
    --password "${PASSWORD}" \
    --table "${TABLE}" \
    ${FILE_FORMAT} \
    ${COMPRESSION} \
    --target-dir "${HDFS_WAREHOUSE_DIR}/${TABLE}" \
    -m "${MAPPERS}"

  echo "Imported ${TABLE} successfully."
done

# ── VERIFY OUTPUT ─────────────────────────────────────────────────
echo
echo "HDFS warehouse contents:"
hdfs dfs -ls "${HDFS_WAREHOUSE_DIR}"

echo
for TABLE in "${TABLES[@]}"; do
  if hdfs dfs -test -d "${HDFS_WAREHOUSE_DIR}/${TABLE}"; then
    echo "[OK] ${TABLE} directory exists in HDFS."
    hdfs dfs -ls "${HDFS_WAREHOUSE_DIR}/${TABLE}"
    echo
  else
    echo "[ERROR] ${TABLE} directory is missing in HDFS."
    exit 1
  fi
done

echo "Data storage step completed successfully."
