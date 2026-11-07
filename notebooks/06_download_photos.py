# Databricks notebook source
import json
import sys

sys.path.append("../ingestion")

from download_photos import download_photos

# COMMAND ----------

summary = download_photos(
    observations_dir="/Volumes/inat/raw/files/observations",
    out_dir="/Volumes/inat/raw/files/photos",
)
dbutils.notebook.exit(json.dumps(summary))