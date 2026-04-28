#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${PROJECT_ROOT}"

echo "=========================================="
echo "Stage 2: Data Storage Preparation and EDA"
echo "Project root: ${PROJECT_ROOT}"
echo "=========================================="
echo

echo "[1/2] Building Hive tables..."
bash scripts/build_hive_tables.sh

echo
echo "[2/2] Running EDA queries and exporting results..."
bash scripts/run_stage2_eda.sh

echo
echo "Stage 2 completed successfully."
echo "Generated outputs:"
echo "  output/hive_results.txt"
echo "  output/q1.txt ... output/q5.txt"
echo "  output/q1.csv ... output/q5.csv"
