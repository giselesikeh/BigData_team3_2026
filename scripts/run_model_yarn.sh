#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_ROOT}"

mkdir -p logs data models output

detect_conf_dir() {
  if [[ -n "${HADOOP_CONF_DIR:-}" && -d "${HADOOP_CONF_DIR}" ]]; then
    echo "${HADOOP_CONF_DIR}"
    return 0
  fi

  if [[ -n "${YARN_CONF_DIR:-}" && -d "${YARN_CONF_DIR}" ]]; then
    echo "${YARN_CONF_DIR}"
    return 0
  fi

  for d in \
    /etc/hadoop/conf \
    /etc/alternatives/hadoop-conf \
    /etc/hadoop \
    /usr/local/hadoop/etc/hadoop
  do
    if [[ -d "${d}" ]]; then
      echo "${d}"
      return 0
    fi
  done

  FOUND="$(find /etc /usr/local -maxdepth 4 -type d \( -name conf -o -name '*hadoop*conf*' -o -name '*yarn*conf*' \) 2>/dev/null | head -n 1 || true)"
  if [[ -n "${FOUND}" && -d "${FOUND}" ]]; then
    echo "${FOUND}"
    return 0
  fi

  return 1
}

CONF_DIR="$(detect_conf_dir || true)"

if [[ -z "${CONF_DIR}" ]]; then
  echo "ERROR: Could not detect Hadoop/YARN configuration directory."
  exit 1
fi

export HADOOP_CONF_DIR="${CONF_DIR}"
export YARN_CONF_DIR="${CONF_DIR}"
export PYSPARK_PYTHON=python3

echo "Using HADOOP_CONF_DIR=${HADOOP_CONF_DIR}"
echo "Using YARN_CONF_DIR=${YARN_CONF_DIR}"
echo "Project root: ${PROJECT_ROOT}"
echo

spark-submit \
  --master yarn \
  --conf "spark.yarn.appMasterEnv.HADOOP_CONF_DIR=${HADOOP_CONF_DIR}" \
  --conf "spark.executorEnv.HADOOP_CONF_DIR=${HADOOP_CONF_DIR}" \
  scripts/model.py 2>&1 | tee logs/stage3_model_run.log

echo
echo "Spark job finished. Syncing outputs from HDFS to repository..."

rm -f data/train.json data/test.json
rm -f output/model1_predictions.csv output/model2_predictions.csv output/evaluation.csv
rm -f output/train_label_distribution.csv output/test_label_distribution.csv
rm -f output/model1_prediction_distribution.csv output/model2_prediction_distribution.csv
rm -f output/model1_per_class_metrics.csv output/model2_per_class_metrics.csv
rm -f output/model1_confusion_matrix.csv output/model2_confusion_matrix.csv
rm -rf models/model1 models/model2

hdfs dfs -cat project/data/train/*.json > data/train.json
hdfs dfs -cat project/data/test/*.json > data/test.json

hdfs dfs -get -f project/models/model1 models/model1
hdfs dfs -get -f project/models/model2 models/model2

hdfs dfs -cat project/output/model1_predictions/*.csv > output/model1_predictions.csv
hdfs dfs -cat project/output/model2_predictions/*.csv > output/model2_predictions.csv
hdfs dfs -cat project/output/evaluation/*.csv > output/evaluation.csv

hdfs dfs -cat project/output/train_label_distribution/*.csv > output/train_label_distribution.csv
hdfs dfs -cat project/output/test_label_distribution/*.csv > output/test_label_distribution.csv
hdfs dfs -cat project/output/model1_prediction_distribution/*.csv > output/model1_prediction_distribution.csv
hdfs dfs -cat project/output/model2_prediction_distribution/*.csv > output/model2_prediction_distribution.csv
hdfs dfs -cat project/output/model1_per_class_metrics/*.csv > output/model1_per_class_metrics.csv
hdfs dfs -cat project/output/model2_per_class_metrics/*.csv > output/model2_per_class_metrics.csv
hdfs dfs -cat project/output/model1_confusion_matrix/*.csv > output/model1_confusion_matrix.csv
hdfs dfs -cat project/output/model2_confusion_matrix/*.csv > output/model2_confusion_matrix.csv

echo "Sync completed."
echo "Local files refreshed in data/, models/, and output/."
