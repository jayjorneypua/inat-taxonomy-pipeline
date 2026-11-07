# Databricks notebook source
import json
import sys

sys.path.append("../ingestion")

from download_dump_file import download_dump_file

# COMMAND ----------

summary = download_dump_file("observers.csv.gz", out_dir="/Volumes/inat/raw/files/observers")
dbutils.notebook.exit(json.dumps(summary))