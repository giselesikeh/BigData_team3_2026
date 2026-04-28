#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "Starting main pipeline"
echo "Project: bigdata-accidents-project"
echo "=========================================="

echo
echo "[1/4] Running Stage 1..."
bash stage1.sh

echo
echo "[2/4] Running Stage 2..."
bash stage2.sh

echo
echo "[3/4] Running Stage 3..."
bash stage3.sh

echo
echo "[4/4] Running Stage 4..."
bash stage4.sh

echo
echo "=========================================="
echo "Main pipeline completed successfully."
echo "=========================================="
