# Databricks notebook source
import sys

sys.path.append("../ingestion")

from download_taxa import download_taxa

# COMMAND ----------

download_taxa(out_dir="/Volumes/inat/raw/files/taxa")