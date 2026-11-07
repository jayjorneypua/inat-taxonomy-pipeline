# Databricks notebook source
import json
import sys

sys.path.append("../ingestion")

from download_observations import download_observations

# COMMAND ----------
summary = download_observations(out_dir="/Volumes/inat/raw/files/observations")
dbutils.notebook.exit(json.dumps(summary))
