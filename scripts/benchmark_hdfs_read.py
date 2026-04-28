#!/usr/bin/env python3
import argparse
import csv
import os
import time

from pyspark.sql import SparkSession


TABLES = [
    "accidents",
    "locations",
    "road_features",
    "twilight",
    "weather",
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--label", required=True, help="Benchmark label, e.g. parquet_snappy")
    parser.add_argument("--fmt", required=True, choices=["parquet", "avro"], help="Input file format")
    parser.add_argument("--base", required=True, help="Base HDFS directory")
    parser.add_argument("--output", required=True, help="Local CSV output file")
    args = parser.parse_args()

    spark = (
        SparkSession.builder
        .appName(f"stage1-read-benchmark-{args.label}")
        .getOrCreate()
    )

    output_exists = os.path.exists(args.output)
    os.makedirs(os.path.dirname(args.output), exist_ok=True)

    with open(args.output, "a", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        if not output_exists:
            writer.writerow([
                "label",
                "format",
                "table",
                "row_count",
                "read_seconds",
                "status",
                "error"
            ])

        for table in TABLES:
            path = f"{args.base}/{table}"
            print(f"\nReading {table} from {path} as {args.fmt} ...")

            start = time.time()
            try:
                df = spark.read.format(args.fmt).load(path)
                row_count = df.count()
                elapsed = time.time() - start
                print(f"  OK: {table} -> {row_count} rows in {elapsed:.2f} sec")
                writer.writerow([
                    args.label,
                    args.fmt,
                    table,
                    row_count,
                    f"{elapsed:.2f}",
                    "OK",
                    ""
                ])
            except Exception as e:
                elapsed = time.time() - start
                err = str(e).replace("\n", " ")[:500]
                print(f"  ERROR reading {table}: {err}")
                writer.writerow([
                    args.label,
                    args.fmt,
                    table,
                    "",
                    f"{elapsed:.2f}",
                    "ERROR",
                    err
                ])

    spark.stop()


if __name__ == "__main__":
    main()
