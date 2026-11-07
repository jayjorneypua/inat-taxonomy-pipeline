# Databricks notebook source
from pyspark.sql import functions as F

source_path = "/Volumes/inat/raw/files/api_observations/"
checkpoint_path = "/Volumes/inat/raw/files/_checkpoints/bronze_api_observations"

stream = (
    spark.readStream
        .format("cloudFiles")
        .option("cloudFiles.format", "json")
        .option("cloudFiles.inferColumnTypes", "true")
        .option("cloudFiles.useIncrementalListing", "false")
        .option("cloudFiles.schemaLocation", checkpoint_path)
        .option("pathGlobFilter", "*.json")
        .load(source_path)
        .withColumn("_source_file", F.col("_metadata.file_path"))
        .withColumn("_ingested_at", F.current_timestamp())
    .writeStream
        .option("checkpointLocation", checkpoint_path)
        .trigger(availableNow=True)
        .toTable("inat.bronze.api_observations")
)

stream.awaitTermination()