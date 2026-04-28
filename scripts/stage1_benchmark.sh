#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Stage 1 benchmark:
#   - Parquet + Snappy
#   - Avro + Snappy
#
# Measures:
#   1. Total Sqoop import time
#   2. Total HDFS storage size
#   3. Raw HDFS read time (cat to /dev/null)
# ============================================================

PROJECT_ROOT="/home/team3/project/bigdata-accidents-project"
cd "${PROJECT_ROOT}"

PASSWORD_FILE="${PROJECT_ROOT}/secrets/.psql.pass"

DB_HOST="hadoop-04.uni.innopolis.ru"
DB_PORT="5432"
DB_NAME="team3_projectdb"
DB_USER="team3"

JDBC_URL="jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}"

TABLES=(
  accidents
  locations
  road_features
  twilight
  weather
)

BENCH_BASE="project/benchmark_stage1"
LOCAL_OUTPUT_DIR="${PROJECT_ROOT}/output"
IMPORT_CSV="${LOCAL_OUTPUT_DIR}/stage1_import_benchmark.csv"
READ_CSV="${LOCAL_OUTPUT_DIR}/stage1_read_benchmark.csv"

mkdir -p "${LOCAL_OUTPUT_DIR}"

if [[ ! -f "${PASSWORD_FILE}" ]]; then
  echo "ERROR: Password file not found: ${PASSWORD_FILE}"
  exit 1
fi

PASSWORD="$(head -n 1 "${PASSWORD_FILE}")"

# Reset result files
rm -f "${IMPORT_CSV}" "${READ_CSV}"
echo "label,format,total_import_seconds,total_hdfs_size_bytes" > "${IMPORT_CSV}"
echo "label,format,table,read_seconds,status,error" > "${READ_CSV}"

get_total_hdfs_size_bytes() {
  local base_dir="$1"
  local total=0
  for table in "${TABLES[@]}"; do
    local size
    size=$(hdfs dfs -du -s "${base_dir}/${table}" 2>/dev/null | awk '{print $1}')
    size=${size:-0}
    total=$((total + size))
  done
  echo "${total}"
}

benchmark_raw_hdfs_read() {
  local label="$1"
  local fmt="$2"
  local base_dir="$3"

  for table in "${TABLES[@]}"; do
    echo
    echo "Benchmarking HDFS read for ${label} / ${table} ..."

    local start_ts
    local end_ts
    local elapsed
    local err_file

    err_file=$(mktemp)

    start_ts=$(date +%s)

    if hdfs dfs -cat "${base_dir}/${table}/part-*" > /dev/null 2>"${err_file}"; then
      end_ts=$(date +%s)
      elapsed=$((end_ts - start_ts))
      echo "  OK: ${table} read in ${elapsed} sec"
      echo "${label},${fmt},${table},${elapsed},OK," >> "${READ_CSV}"
    else
      end_ts=$(date +%s)
      elapsed=$((end_ts - start_ts))
      local err_msg
      err_msg=$(tr '\n' ' ' < "${err_file}" | sed 's/"/'\''/g' | cut -c1-500)
      echo "  ERROR: ${table} read failed"
      echo "${label},${fmt},${table},${elapsed},ERROR,\"${err_msg}\"" >> "${READ_CSV}"
    fi

    rm -f "${err_file}"
  done
}

import_one_format() {
  local label="$1"
  local sqoop_format_flag="$2"
  local fmt="$3"
  local target_base="${BENCH_BASE}/${label}"

  echo
  echo "======================================================"
  echo "Benchmarking ${label}"
  echo "Target HDFS directory: /user/${DB_USER}/${target_base}"
  echo "======================================================"

  # Clean old benchmark output
  echo "Cleaning old HDFS benchmark directory for ${label} ..."
  hdfs dfs -rm -r -f -skipTrash "${target_base}" 2>/dev/null || true
  hdfs dfs -mkdir -p "${target_base}"

  # Import benchmark
  local start_ts
  local end_ts
  local import_seconds
  start_ts=$(date +%s)

  for table in "${TABLES[@]}"; do
    echo
    echo "Importing ${table} as ${label} ..."
    sqoop import \
      --connect "${JDBC_URL}" \
      --username "${DB_USER}" \
      --password "${PASSWORD}" \
      --table "${table}" \
      ${sqoop_format_flag} \
      --compression-codec=snappy \
      --compress \
      --target-dir "${target_base}/${table}" \
      -m 1
  done

  end_ts=$(date +%s)
  import_seconds=$((end_ts - start_ts))

  local total_size_bytes
  total_size_bytes=$(get_total_hdfs_size_bytes "${target_base}")

  echo "${label},${fmt},${import_seconds},${total_size_bytes}" >> "${IMPORT_CSV}"

  echo
  echo "Import benchmark for ${label}:"
  echo "  Total import seconds : ${import_seconds}"
  echo "  Total HDFS size bytes: ${total_size_bytes}"

  # Raw HDFS read benchmark
  benchmark_raw_hdfs_read "${label}" "${fmt}" "${target_base}"

  echo
  echo "HDFS contents for ${label}:"
  hdfs dfs -ls "${target_base}"
}

echo "Starting Stage 1 benchmark comparison..."

import_one_format "parquet_snappy" "--as-parquetfile" "parquet"
import_one_format "avro_snappy" "--as-avrodatafile" "avro"

echo
echo "======================================================"
echo "Benchmark complete."
echo "Import results saved to: ${IMPORT_CSV}"
echo "Read results saved to  : ${READ_CSV}"
echo "======================================================"

echo
echo "Import benchmark summary:"
cat "${IMPORT_CSV}"

echo
echo "Read benchmark summary:"
cat "${READ_CSV}"
