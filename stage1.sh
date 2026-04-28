#!/usr/bin/env bash
set -euo pipefail

echo "======================================"
echo "Starting Stage 1: Data Collection and Ingestion"
echo "Project root: $(pwd)"
echo "======================================"

echo
echo "[1/3] Running data collection..."
bash scripts/data_collection.sh

echo
echo "[2/3] Building PostgreSQL database..."
python3 scripts/build_projectdb.py

echo
echo "[3/3] Importing PostgreSQL tables into HDFS..."
bash scripts/data_storage.sh

echo
echo "======================================"
echo "Stage 1 completed successfully."
echo "======================================"
