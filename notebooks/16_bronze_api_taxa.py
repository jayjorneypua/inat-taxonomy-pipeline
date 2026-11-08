# Databricks notebook source
from pyspark.sql import functions as F

source_path = "/Volumes/inat/raw/files/api_taxa/"
checkpoint_path = "/Volumes/inat/raw/files/_checkpoints/bronze_api_taxa"
taxa_schema = (
    "id BIGINT, name STRING, rank STRING, rank_level DOUBLE, ancestry STRING"
    ", is_active BOOLEAN, parent_id BIGINT, preferred_common_name STRING"
)

# the folder and table must exist even when no taxa were fetched yet, silver reads this table
dbutils.fs.mkdirs(source_path)
spark.sql(f"""
    CREATE TABLE IF NOT EXISTS inat.bronze.api_taxa (
        {taxa_schema}
      , _source_file STRING
      , _ingested_at TIMESTAMP
    )
""")

# COMMAND ----------

stream = (
    spark.readStream
        .format("cloudFiles")
        .option("cloudFiles.format", "json")
        .option("cloudFiles.useIncrementalListing", "false")
        .option("pathGlobFilter", "*.json")
        .schema(taxa_schema)
        .load(source_path)
        .withColumn("_source_file", F.col("_metadata.file_path"))
        .withColumn("_ingested_at", F.current_timestamp())
    .writeStream
        .option("checkpointLocation", checkpoint_path)
        .trigger(availableNow=True)
        .toTable("inat.bronze.api_taxa")
)

stream.awaitTermination()