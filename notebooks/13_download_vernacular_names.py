# Databricks notebook source
import json
import sys

sys.path.append("../ingestion")

from download_vernacular_names import download_vernacular_names

# COMMAND ----------

summary = download_vernacular_names(out_dir="/Volumes/inat/raw/files/vernacular_names")
dbutils.notebook.exit(json.dumps(summary))