#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

DATA_DIR="./data"
ZIP_NAME="us-accidents.zip"
DATASET_ID="sobhanmoosavi/us-accidents"

echo "Starting data collection..."

# Clean old data directory so reruns work
if [[ -d "$DATA_DIR" ]]; then
  echo "Removing existing $DATA_DIR ..."
  rm -rf "$DATA_DIR"
fi

# Recreate fresh data directory
mkdir -p "$DATA_DIR"

# Check Kaggle token exists
if [[ ! -f "$HOME/.kaggle/kaggle.json" ]]; then
  echo "ERROR: Kaggle API token not found at $HOME/.kaggle/kaggle.json"
  exit 1
fi

# Download dataset
echo "Downloading dataset from Kaggle..."
kaggle datasets download -d "$DATASET_ID" -p "$DATA_DIR"

# Unzip dataset
echo "Unzipping dataset..."
unzip -q "$DATA_DIR"/*.zip -d "$DATA_DIR"

# Remove zip after extraction
rm -f "$DATA_DIR"/*.zip

echo "Dataset ready in $DATA_DIR"
ls -lh "$DATA_DIR"
