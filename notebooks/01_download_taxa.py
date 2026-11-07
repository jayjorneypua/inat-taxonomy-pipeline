# Databricks notebook source
import json
import sys

sys.path.append("../ingestion")

from download_dump_file import download_dump_file

# COMMAND ----------

summary = download_dump_file("taxa.csv.gz", out_dir="/Volumes/inat/raw/files/taxa")
dbutils.notebook.exit(json.dumps(summary))