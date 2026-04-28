#!/usr/bin/env python3

import math
from typing import Dict, List, Tuple

from pyspark import StorageLevel
from pyspark.ml import Pipeline, Transformer
from pyspark.ml.classification import LogisticRegression, RandomForestClassifier
from pyspark.ml.evaluation import MulticlassClassificationEvaluator
from pyspark.ml.feature import Imputer, OneHotEncoder, StandardScaler, StringIndexer, VectorAssembler
from pyspark.ml.param.shared import Param, Params, TypeConverters
from pyspark.ml.tuning import CrossValidator, ParamGridBuilder
from pyspark.ml.util import DefaultParamsReadable, DefaultParamsWritable
from pyspark.sql import DataFrame, SparkSession
from pyspark.sql import functions as F


TEAM = "team3"
HIVE_DB = "team3_projectdb"
WAREHOUSE = "project/hive/warehouse"

HDFS_TRAIN_PATH = "project/data/train"
HDFS_TEST_PATH = "project/data/test"
HDFS_MODEL1_PATH = "project/models/model1"
HDFS_MODEL2_PATH = "project/models/model2"

HDFS_OUTPUT_MODEL1 = "project/output/model1_predictions"
HDFS_OUTPUT_MODEL2 = "project/output/model2_predictions"
HDFS_OUTPUT_EVAL = "project/output/evaluation"
HDFS_OUTPUT_TRAIN_DIST = "project/output/train_label_distribution"
HDFS_OUTPUT_TEST_DIST = "project/output/test_label_distribution"
HDFS_OUTPUT_MODEL1_PRED_DIST = "project/output/model1_prediction_distribution"
HDFS_OUTPUT_MODEL2_PRED_DIST = "project/output/model2_prediction_distribution"
HDFS_OUTPUT_MODEL1_CLASS = "project/output/model1_per_class_metrics"
HDFS_OUTPUT_MODEL2_CLASS = "project/output/model2_per_class_metrics"
HDFS_OUTPUT_MODEL1_CM = "project/output/model1_confusion_matrix"
HDFS_OUTPUT_MODEL2_CM = "project/output/model2_confusion_matrix"


class TimestampPartsTransformer(
    Transformer, DefaultParamsReadable, DefaultParamsWritable
):
    timestampCol = Param(
        Params._dummy(),
        "timestampCol",
        "timestamp column name",
        typeConverter=TypeConverters.toString,
    )

    def __init__(self, timestampCol: str = "start_time"):
        super(TimestampPartsTransformer, self).__init__()
        self._setDefault(timestampCol="start_time")
        self._set(timestampCol=timestampCol)

    def _transform(self, dataset: DataFrame) -> DataFrame:
        ts_col = F.col(self.getOrDefault(self.timestampCol))
        return (
            dataset.withColumn("start_year", F.year(ts_col).cast("double"))
            .withColumn("start_month_num", F.month(ts_col).cast("double"))
            .withColumn("start_day_num", F.dayofmonth(ts_col).cast("double"))
            .withColumn("start_dayofweek_num", F.dayofweek(ts_col).cast("double"))
            .withColumn("start_hour_num", F.hour(ts_col).cast("double"))
            .withColumn("start_minute_num", F.minute(ts_col).cast("double"))
            .withColumn("start_second_num", F.second(ts_col).cast("double"))
        )


class CyclicalEncoder(Transformer, DefaultParamsReadable, DefaultParamsWritable):
    inputCol = Param(
        Params._dummy(),
        "inputCol",
        "input column name",
        typeConverter=TypeConverters.toString,
    )
    outputPrefix = Param(
        Params._dummy(),
        "outputPrefix",
        "prefix for sin/cos columns",
        typeConverter=TypeConverters.toString,
    )
    period = Param(
        Params._dummy(),
        "period",
        "cyclical period",
        typeConverter=TypeConverters.toFloat,
    )

    def __init__(self, inputCol: str, outputPrefix: str, period: float):
        super(CyclicalEncoder, self).__init__()
        self._set(inputCol=inputCol, outputPrefix=outputPrefix, period=period)

    def _transform(self, dataset: DataFrame) -> DataFrame:
        in_col = F.col(self.getOrDefault(self.inputCol))
        prefix = self.getOrDefault(self.outputPrefix)
        period = float(self.getOrDefault(self.period))
        angle = in_col * F.lit(2.0 * math.pi / period)
        return (
            dataset.withColumn("{}_sin".format(prefix), F.sin(angle))
            .withColumn("{}_cos".format(prefix), F.cos(angle))
        )


class ECEFTransformer(Transformer, DefaultParamsReadable, DefaultParamsWritable):
    latCol = Param(
        Params._dummy(),
        "latCol",
        "latitude column name",
        typeConverter=TypeConverters.toString,
    )
    lonCol = Param(
        Params._dummy(),
        "lonCol",
        "longitude column name",
        typeConverter=TypeConverters.toString,
    )
    altCol = Param(
        Params._dummy(),
        "altCol",
        "altitude column name",
        typeConverter=TypeConverters.toString,
    )

    def __init__(self, latCol: str = "start_lat", lonCol: str = "start_lng", altCol: str = "altitude_m"):
        super(ECEFTransformer, self).__init__()
        self._set(latCol=latCol, lonCol=lonCol, altCol=altCol)

    def _transform(self, dataset: DataFrame) -> DataFrame:
        a = 6378137.0
        e2 = 6.69437999014e-3

        lat_rad = F.radians(F.col(self.getOrDefault(self.latCol)))
        lon_rad = F.radians(F.col(self.getOrDefault(self.lonCol)))
        alt = F.col(self.getOrDefault(self.altCol)).cast("double")

        sin_lat = F.sin(lat_rad)
        cos_lat = F.cos(lat_rad)
        sin_lon = F.sin(lon_rad)
        cos_lon = F.cos(lon_rad)

        n = F.lit(a) / F.sqrt(F.lit(1.0) - F.lit(e2) * sin_lat * sin_lat)

        x = (n + alt) * cos_lat * cos_lon
        y = (n + alt) * cos_lat * sin_lon
        z = ((F.lit(1.0) - F.lit(e2)) * n + alt) * sin_lat

        return (
            dataset.withColumn("ecef_x", x)
            .withColumn("ecef_y", y)
            .withColumn("ecef_z", z)
        )


def build_spark() -> SparkSession:
    spark = (
        SparkSession.builder
        .appName("{} - stage3 severity classification weighted".format(TEAM))
        .master("yarn")
        .config("hive.metastore.uris", "thrift://hadoop-02.uni.innopolis.ru:9883")
        .config("spark.sql.warehouse.dir", WAREHOUSE)
        .enableHiveSupport()
        .getOrCreate()
    )
    spark.sparkContext.setLogLevel("WARN")
    return spark


def export_dataframe_csv(df: DataFrame, hdfs_dir: str) -> None:
    (
        df.coalesce(1)
        .write
        .mode("overwrite")
        .format("csv")
        .option("sep", ",")
        .option("header", "true")
        .save(hdfs_dir)
    )


def export_dataframe_json(df: DataFrame, hdfs_dir: str) -> None:
    (
        df.coalesce(1)
        .write
        .mode("overwrite")
        .format("json")
        .save(hdfs_dir)
    )


def read_hive_tables(spark: SparkSession) -> Tuple[DataFrame, DataFrame, DataFrame, DataFrame, DataFrame]:
    accidents = spark.table("{}.accidents_part".format(HIVE_DB))
    locations = spark.table("{}.locations_part".format(HIVE_DB))
    weather = spark.table("{}.weather_buck".format(HIVE_DB))
    twilight = spark.table("{}.twilight_buck".format(HIVE_DB))
    road = spark.table("{}.road_features_buck".format(HIVE_DB))
    return accidents, locations, weather, twilight, road


def build_ml_dataframe(
    accidents: DataFrame,
    locations: DataFrame,
    weather: DataFrame,
    twilight: DataFrame,
    road: DataFrame,
) -> DataFrame:
    df = (
        accidents.alias("a")
        .join(locations.alias("l"), F.col("a.location_id") == F.col("l.id"), "inner")
        .join(weather.alias("w"), F.col("a.weather_id") == F.col("w.id"), "left")
        .join(twilight.alias("t"), F.col("a.twilight_id") == F.col("t.id"), "left")
        .join(road.alias("r"), F.col("a.road_feat_id") == F.col("r.id"), "left")
        .select(
            F.col("a.source").alias("source"),
            F.col("a.severity").cast("double").alias("severity_raw"),
            F.col("a.start_time").alias("start_time"),
            F.col("a.distance_mi").cast("double").alias("distance_mi"),

            F.col("l.start_lat").cast("double").alias("start_lat"),
            F.col("l.start_lng").cast("double").alias("start_lng"),
            F.col("l.state").alias("state"),
            F.col("l.county").alias("county"),
            F.col("l.city").alias("city"),
            F.col("l.timezone").alias("timezone"),

            F.col("w.temperature_f").cast("double").alias("temperature_f"),
            F.col("w.wind_chill_f").cast("double").alias("wind_chill_f"),
            F.col("w.humidity_pct").cast("double").alias("humidity_pct"),
            F.col("w.pressure_in").cast("double").alias("pressure_in"),
            F.col("w.visibility_mi").cast("double").alias("visibility_mi"),
            F.col("w.wind_direction").alias("wind_direction"),
            F.col("w.wind_speed_mph").cast("double").alias("wind_speed_mph"),
            F.col("w.precipitation_in").cast("double").alias("precipitation_in"),
            F.col("w.weather_condition").alias("weather_condition"),

            F.col("t.sunrise_sunset").alias("sunrise_sunset"),
            F.col("t.civil_twilight").alias("civil_twilight"),
            F.col("t.nautical_twilight").alias("nautical_twilight"),
            F.col("t.astronomical_twilight").alias("astronomical_twilight"),

            F.col("r.amenity").cast("double").alias("amenity"),
            F.col("r.bump").cast("double").alias("bump"),
            F.col("r.crossing").cast("double").alias("crossing"),
            F.col("r.give_way").cast("double").alias("give_way"),
            F.col("r.junction").cast("double").alias("junction"),
            F.col("r.no_exit").cast("double").alias("no_exit"),
            F.col("r.railway").cast("double").alias("railway"),
            F.col("r.roundabout").cast("double").alias("roundabout"),
            F.col("r.station").cast("double").alias("station"),
            F.col("r.stop").cast("double").alias("stop"),
            F.col("r.traffic_calming").cast("double").alias("traffic_calming"),
            F.col("r.traffic_signal").cast("double").alias("traffic_signal"),
            F.col("r.turning_loop").cast("double").alias("turning_loop"),
        )
        .filter(F.col("severity_raw").isin([1.0, 2.0, 3.0, 4.0]))
        .filter(F.col("start_time").isNotNull())
        .filter(F.col("start_lat").isNotNull() & F.col("start_lng").isNotNull())
        .withColumn("label", (F.col("severity_raw") - F.lit(1.0)).cast("double"))
        .withColumn("altitude_m", F.lit(0.0))
    )

    string_fill = {
        "source": "Unknown",
        "state": "Unknown",
        "county": "Unknown",
        "city": "Unknown",
        "timezone": "Unknown",
        "wind_direction": "Unknown",
        "weather_condition": "Unknown",
        "sunrise_sunset": "Unknown",
        "civil_twilight": "Unknown",
        "nautical_twilight": "Unknown",
        "astronomical_twilight": "Unknown",
    }
    df = df.fillna(string_fill)

    boolean_numeric_cols = [
        "amenity",
        "bump",
        "crossing",
        "give_way",
        "junction",
        "no_exit",
        "railway",
        "roundabout",
        "station",
        "stop",
        "traffic_calming",
        "traffic_signal",
        "turning_loop",
    ]
    df = df.fillna(0.0, subset=boolean_numeric_cols)

    return df


def build_preprocessor(categorical_cols: List[str], numeric_cols: List[str]) -> Pipeline:
    timestamp_parts = TimestampPartsTransformer(timestampCol="start_time")
    month_cycle = CyclicalEncoder("start_month_num", "month", 12.0)
    day_cycle = CyclicalEncoder("start_day_num", "day", 31.0)
    dow_cycle = CyclicalEncoder("start_dayofweek_num", "dayofweek", 7.0)
    hour_cycle = CyclicalEncoder("start_hour_num", "hour", 24.0)
    minute_cycle = CyclicalEncoder("start_minute_num", "minute", 60.0)
    second_cycle = CyclicalEncoder("start_second_num", "second", 60.0)
    ecef = ECEFTransformer("start_lat", "start_lng", "altitude_m")

    imputer = Imputer(
        inputCols=numeric_cols,
        outputCols=["{}_imp".format(c) for c in numeric_cols],
        strategy="median",
    )

    indexers = [
        StringIndexer(
            inputCol=c,
            outputCol="{}_idx".format(c),
            handleInvalid="keep",
        )
        for c in categorical_cols
    ]

    encoder = OneHotEncoder(
        inputCols=["{}_idx".format(c) for c in categorical_cols],
        outputCols=["{}_ohe".format(c) for c in categorical_cols],
        handleInvalid="keep",
    )

    assembler_inputs = ["{}_imp".format(c) for c in numeric_cols] + ["{}_ohe".format(c) for c in categorical_cols]

    assembler = VectorAssembler(
        inputCols=assembler_inputs,
        outputCol="features_raw",
        handleInvalid="keep",
    )

    scaler = StandardScaler(
        inputCol="features_raw",
        outputCol="features",
        withStd=True,
        withMean=False,
    )

    return Pipeline(
        stages=[
            timestamp_parts,
            month_cycle,
            day_cycle,
            dow_cycle,
            hour_cycle,
            minute_cycle,
            second_cycle,
            ecef,
            imputer,
        ] + indexers + [encoder, assembler, scaler]
    )


def label_distribution_df(df: DataFrame, col_name: str = "label") -> DataFrame:
    return (
        df.select((F.col(col_name) + F.lit(1.0)).cast("int").alias("severity"))
        .groupBy("severity")
        .count()
        .orderBy("severity")
    )


def compute_class_weights(train_df: DataFrame) -> Tuple[Dict[float, float], DataFrame]:
    rows = train_df.groupBy("label").count().orderBy("label").collect()
    total = float(sum(r["count"] for r in rows))
    num_classes = float(len(rows))

    weight_map = {}
    report_rows = []
    for row in rows:
        label = float(row["label"])
        count = int(row["count"])
        weight = total / (num_classes * float(count))
        weight_map[label] = float(weight)
        report_rows.append((int(label + 1.0), count, float(weight)))

    spark = train_df.sql_ctx.sparkSession
    schema_rows = spark.createDataFrame(
        report_rows,
        ["severity", "count", "class_weight"],
    )
    return weight_map, schema_rows.orderBy("severity")


def add_class_weights(train_df: DataFrame, weight_map: Dict[float, float]) -> DataFrame:
    map_items = []
    for label, weight in sorted(weight_map.items()):
        map_items.extend([F.lit(float(label)), F.lit(float(weight))])

    weight_expr = F.create_map(*map_items)
    return train_df.withColumn("weight", weight_expr[F.col("label")])


def compute_metrics(predictions: DataFrame, labels: List[float]) -> Tuple[Dict[str, float], List[Tuple[int, float, float, float]], DataFrame, DataFrame]:
    weighted_f1 = MulticlassClassificationEvaluator(
        labelCol="label",
        predictionCol="prediction",
        metricName="f1",
    ).evaluate(predictions)

    accuracy = MulticlassClassificationEvaluator(
        labelCol="label",
        predictionCol="prediction",
        metricName="accuracy",
    ).evaluate(predictions)

    weighted_precision = MulticlassClassificationEvaluator(
        labelCol="label",
        predictionCol="prediction",
        metricName="weightedPrecision",
    ).evaluate(predictions)

    weighted_recall = MulticlassClassificationEvaluator(
        labelCol="label",
        predictionCol="prediction",
        metricName="weightedRecall",
    ).evaluate(predictions)

    per_class_rows = []
    macro_precision_vals = []
    macro_recall_vals = []
    macro_f1_vals = []

    for lbl in labels:
        precision = MulticlassClassificationEvaluator(
            labelCol="label",
            predictionCol="prediction",
            metricName="precisionByLabel",
            metricLabel=lbl,
        ).evaluate(predictions)

        recall = MulticlassClassificationEvaluator(
            labelCol="label",
            predictionCol="prediction",
            metricName="recallByLabel",
            metricLabel=lbl,
        ).evaluate(predictions)

        f1 = MulticlassClassificationEvaluator(
            labelCol="label",
            predictionCol="prediction",
            metricName="fMeasureByLabel",
            metricLabel=lbl,
        ).evaluate(predictions)

        macro_precision_vals.append(precision)
        macro_recall_vals.append(recall)
        macro_f1_vals.append(f1)

        per_class_rows.append(
            (int(lbl + 1.0), float(precision), float(recall), float(f1))
        )

    macro_precision = float(sum(macro_precision_vals) / len(macro_precision_vals))
    macro_recall = float(sum(macro_recall_vals) / len(macro_recall_vals))
    macro_f1 = float(sum(macro_f1_vals) / len(macro_f1_vals))

    summary = {
        "accuracy": float(accuracy),
        "weighted_precision": float(weighted_precision),
        "weighted_recall": float(weighted_recall),
        "weighted_f1": float(weighted_f1),
        "macro_precision": macro_precision,
        "macro_recall": macro_recall,
        "macro_f1": macro_f1,
    }

    confusion_df = (
        predictions.select(
            (F.col("label") + F.lit(1.0)).cast("int").alias("label"),
            (F.col("prediction") + F.lit(1.0)).cast("int").alias("prediction"),
        )
        .groupBy("label", "prediction")
        .count()
        .orderBy("label", "prediction")
    )

    pred_dist_df = (
        predictions.select(
            (F.col("prediction") + F.lit(1.0)).cast("int").alias("severity")
        )
        .groupBy("severity")
        .count()
        .orderBy("severity")
    )

    return summary, per_class_rows, confusion_df, pred_dist_df


def export_predictions(predictions: DataFrame, hdfs_dir: str) -> None:
    export_df = predictions.select(
        (F.col("label") + F.lit(1.0)).cast("int").alias("label"),
        (F.col("prediction") + F.lit(1.0)).cast("int").alias("prediction"),
    )
    export_dataframe_csv(export_df, hdfs_dir)


def main() -> None:
    spark = build_spark()

    print("Databases:")
    spark.sql("SHOW DATABASES").show(truncate=False)
    print("Tables in {}:".format(HIVE_DB))
    spark.sql("SHOW TABLES IN {}".format(HIVE_DB)).show(truncate=False)

    accidents, locations, weather, twilight, road = read_hive_tables(spark)

    raw_df = build_ml_dataframe(accidents, locations, weather, twilight, road)
    raw_df = raw_df.repartition(48).persist(StorageLevel.MEMORY_AND_DISK)

    print("ML dataframe schema:")
    raw_df.printSchema()

    train_raw, test_raw = raw_df.randomSplit([0.8, 0.2], seed=42)
    train_raw = train_raw.persist(StorageLevel.MEMORY_AND_DISK)
    test_raw = test_raw.persist(StorageLevel.MEMORY_AND_DISK)

    categorical_cols = [
        "source",
        "state",
        "county",
        "city",
        "timezone",
        "wind_direction",
        "weather_condition",
        "sunrise_sunset",
        "civil_twilight",
        "nautical_twilight",
        "astronomical_twilight",
    ]

    numeric_cols = [
        "distance_mi",
        "temperature_f",
        "wind_chill_f",
        "humidity_pct",
        "pressure_in",
        "visibility_mi",
        "wind_speed_mph",
        "precipitation_in",
        "amenity",
        "bump",
        "crossing",
        "give_way",
        "junction",
        "no_exit",
        "railway",
        "roundabout",
        "station",
        "stop",
        "traffic_calming",
        "traffic_signal",
        "turning_loop",
        "start_year",
        "month_sin",
        "month_cos",
        "day_sin",
        "day_cos",
        "dayofweek_sin",
        "dayofweek_cos",
        "hour_sin",
        "hour_cos",
        "minute_sin",
        "minute_cos",
        "second_sin",
        "second_cos",
        "ecef_x",
        "ecef_y",
        "ecef_z",
    ]

    preprocessor = build_preprocessor(categorical_cols, numeric_cols)
    preprocessor_model = preprocessor.fit(train_raw)

    train_prepared = (
        preprocessor_model.transform(train_raw)
        .select("features", "label")
        .persist(StorageLevel.MEMORY_AND_DISK)
    )
    test_prepared = (
        preprocessor_model.transform(test_raw)
        .select("features", "label")
        .persist(StorageLevel.MEMORY_AND_DISK)
    )

    export_dataframe_json(train_prepared.select("features", "label"), HDFS_TRAIN_PATH)
    export_dataframe_json(test_prepared.select("features", "label"), HDFS_TEST_PATH)

    train_label_dist_df = label_distribution_df(train_prepared, "label")
    test_label_dist_df = label_distribution_df(test_prepared, "label")
    export_dataframe_csv(train_label_dist_df, HDFS_OUTPUT_TRAIN_DIST)
    export_dataframe_csv(test_label_dist_df, HDFS_OUTPUT_TEST_DIST)

    weight_map, class_weight_report_df = compute_class_weights(train_prepared)
    print("Training class weights:")
    class_weight_report_df.show(truncate=False)

    train_weighted = add_class_weights(train_prepared, weight_map).persist(StorageLevel.MEMORY_AND_DISK)
    labels = sorted([float(r["label"]) for r in train_prepared.select("label").distinct().collect()])

    f1_evaluator = MulticlassClassificationEvaluator(
        labelCol="label",
        predictionCol="prediction",
        metricName="f1",
    )

    rf = RandomForestClassifier(
        labelCol="label",
        featuresCol="features",
        weightCol="weight",
        seed=42,
        numTrees=30,
        maxDepth=8,
        maxBins=128,
    )

    rf_base_model = rf.fit(train_weighted)
    rf_base_predictions = rf_base_model.transform(test_prepared)
    rf_base_summary, _, _, _ = compute_metrics(rf_base_predictions, labels)
    print("Weighted RandomForest baseline macro F1: {:.6f}".format(rf_base_summary["macro_f1"]))
    print("Weighted RandomForest baseline accuracy: {:.6f}".format(rf_base_summary["accuracy"]))

    rf_grid = (
        ParamGridBuilder()
        .addGrid(rf.numTrees, [20, 40])
        .addGrid(rf.maxDepth, [6, 10])
        .build()
    )

    rf_cv = CrossValidator(
        estimator=rf,
        estimatorParamMaps=rf_grid,
        evaluator=f1_evaluator,
        numFolds=3,
        parallelism=2,
        seed=42,
    )

    rf_cv_model = rf_cv.fit(train_weighted)
    model1 = rf_cv_model.bestModel
    model1.write().overwrite().save(HDFS_MODEL1_PATH)

    model1_predictions = model1.transform(test_prepared)
    model1_summary, model1_per_class_rows, model1_cm_df, model1_pred_dist_df = compute_metrics(model1_predictions, labels)

    export_predictions(model1_predictions, HDFS_OUTPUT_MODEL1)

    model1_per_class_df = spark.createDataFrame(
        model1_per_class_rows,
        ["severity", "precision", "recall", "f1"],
    )
    export_dataframe_csv(model1_per_class_df, HDFS_OUTPUT_MODEL1_CLASS)
    export_dataframe_csv(model1_cm_df, HDFS_OUTPUT_MODEL1_CM)
    export_dataframe_csv(model1_pred_dist_df, HDFS_OUTPUT_MODEL1_PRED_DIST)

    print("Best Weighted RandomForest weighted F1: {:.6f}".format(model1_summary["weighted_f1"]))
    print("Best Weighted RandomForest accuracy: {:.6f}".format(model1_summary["accuracy"]))
    print("Best Weighted RandomForest macro recall: {:.6f}".format(model1_summary["macro_recall"]))

    lr = LogisticRegression(
        labelCol="label",
        featuresCol="features",
        weightCol="weight",
        family="multinomial",
        maxIter=50,
        standardization=False,
    )

    lr_base_model = lr.fit(train_weighted)
    lr_base_predictions = lr_base_model.transform(test_prepared)
    lr_base_summary, _, _, _ = compute_metrics(lr_base_predictions, labels)
    print("Weighted LogisticRegression baseline macro F1: {:.6f}".format(lr_base_summary["macro_f1"]))
    print("Weighted LogisticRegression baseline accuracy: {:.6f}".format(lr_base_summary["accuracy"]))

    lr_grid = (
        ParamGridBuilder()
        .addGrid(lr.regParam, [0.0, 0.05])
        .addGrid(lr.elasticNetParam, [0.0, 0.5])
        .build()
    )

    lr_cv = CrossValidator(
        estimator=lr,
        estimatorParamMaps=lr_grid,
        evaluator=f1_evaluator,
        numFolds=3,
        parallelism=2,
        seed=42,
    )

    lr_cv_model = lr_cv.fit(train_weighted)
    model2 = lr_cv_model.bestModel
    model2.write().overwrite().save(HDFS_MODEL2_PATH)

    model2_predictions = model2.transform(test_prepared)
    model2_summary, model2_per_class_rows, model2_cm_df, model2_pred_dist_df = compute_metrics(model2_predictions, labels)

    export_predictions(model2_predictions, HDFS_OUTPUT_MODEL2)

    model2_per_class_df = spark.createDataFrame(
        model2_per_class_rows,
        ["severity", "precision", "recall", "f1"],
    )
    export_dataframe_csv(model2_per_class_df, HDFS_OUTPUT_MODEL2_CLASS)
    export_dataframe_csv(model2_cm_df, HDFS_OUTPUT_MODEL2_CM)
    export_dataframe_csv(model2_pred_dist_df, HDFS_OUTPUT_MODEL2_PRED_DIST)

    print("Best Weighted LogisticRegression weighted F1: {:.6f}".format(model2_summary["weighted_f1"]))
    print("Best Weighted LogisticRegression accuracy: {:.6f}".format(model2_summary["accuracy"]))
    print("Best Weighted LogisticRegression macro recall: {:.6f}".format(model2_summary["macro_recall"]))

    evaluation_rows = [
        (
            "WeightedRandomForestClassifier",
            "inverse_frequency_weights",
            float(model1_summary["accuracy"]),
            float(model1_summary["weighted_precision"]),
            float(model1_summary["weighted_recall"]),
            float(model1_summary["weighted_f1"]),
            float(model1_summary["macro_precision"]),
            float(model1_summary["macro_recall"]),
            float(model1_summary["macro_f1"]),
        ),
        (
            "WeightedMultinomialLogisticRegression",
            "inverse_frequency_weights",
            float(model2_summary["accuracy"]),
            float(model2_summary["weighted_precision"]),
            float(model2_summary["weighted_recall"]),
            float(model2_summary["weighted_f1"]),
            float(model2_summary["macro_precision"]),
            float(model2_summary["macro_recall"]),
            float(model2_summary["macro_f1"]),
        ),
    ]

    evaluation_df = spark.createDataFrame(
        evaluation_rows,
        [
            "model",
            "imbalance_strategy",
            "accuracy",
            "weighted_precision",
            "weighted_recall",
            "weighted_f1",
            "macro_precision",
            "macro_recall",
            "macro_f1",
        ],
    )
    export_dataframe_csv(evaluation_df, HDFS_OUTPUT_EVAL)

    print("Stage 3 weighted model training completed successfully.")
    print("Saved HDFS outputs:")
    print("  {}".format(HDFS_TRAIN_PATH))
    print("  {}".format(HDFS_TEST_PATH))
    print("  {}".format(HDFS_MODEL1_PATH))
    print("  {}".format(HDFS_MODEL2_PATH))
    print("  {}".format(HDFS_OUTPUT_MODEL1))
    print("  {}".format(HDFS_OUTPUT_MODEL2))
    print("  {}".format(HDFS_OUTPUT_EVAL))
    print("  {}".format(HDFS_OUTPUT_TRAIN_DIST))
    print("  {}".format(HDFS_OUTPUT_TEST_DIST))
    print("  {}".format(HDFS_OUTPUT_MODEL1_PRED_DIST))
    print("  {}".format(HDFS_OUTPUT_MODEL2_PRED_DIST))
    print("  {}".format(HDFS_OUTPUT_MODEL1_CLASS))
    print("  {}".format(HDFS_OUTPUT_MODEL2_CLASS))
    print("  {}".format(HDFS_OUTPUT_MODEL1_CM))
    print("  {}".format(HDFS_OUTPUT_MODEL2_CM))

    spark.stop()


if __name__ == "__main__":
    main()
