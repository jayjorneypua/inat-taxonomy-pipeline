# Databricks notebook source
import json
import sys

sys.path.append("../ingestion")

from pull_api_observations import pull_observations

# COMMAND ----------
summary = pull_observations(
    out_dir="/Volumes/inat/raw/files/api_observations",
    state_path="/Volumes/inat/raw/files/_state/api_observations.json",
    initial_watermark="2026-10-27T00:00:00Z",
)
dbutils.notebook.exit(json.dumps(summary))