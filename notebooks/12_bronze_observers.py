# Databricks notebook source
from pyspark.sql import functions as F

source_path = "/Volumes/inat/raw/files/observers/"
checkpoint_path = "/Volumes/inat/raw/files/_checkpoints/bronze_observers"

stream = (
    spark.readStream
        .format("cloudFiles")
        .option("cloudFiles.format", "csv")
        .option("header", "true")
        .option("sep", "\t")
        .option("cloudFiles.inferColumnTypes", "true")
        .option("cloudFiles.useIncrementalListing", "false")
        .option("cloudFiles.schemaLocation", checkpoint_path)
        .option("pathGlobFilter", "*.csv.gz")
        .load(source_path)
        .withColumn("_source_file", F.col("_metadata.file_path"))
        .withColumn("_ingested_at", F.current_timestamp())
    .writeStream
        .option("checkpointLocation", checkpoint_path)
        .trigger(availableNow=True)
        .toTable("inat.bronze.observers")
)

stream.awaitTermination()