# Databricks notebook source
import json
import sys

sys.path.append("../ingestion")

from pull_api_taxa import pull_taxa

MAX_PASSES = 3

# COMMAND ----------

# taxa in the latest dump snapshot
dump_taxon_ids = spark.sql("""
    SELECT
        taxa.taxon_id
    FROM
        inat.bronze.taxa taxa
    INNER JOIN (
        SELECT MAX(snapshot_date) AS snapshot_date FROM inat.bronze.taxa
    ) latest_snapshot
        ON taxa.snapshot_date = latest_snapshot.snapshot_date
""")

# taxa our observations point to that the dump doesn't have (created after the snapshot)
observed_taxon_ids = spark.sql("""
    SELECT DISTINCT
        taxon_id
    FROM
        inat.silver.observations
    WHERE
        taxon_id IS NOT NULL
""")

missing_taxon_ids = [
    row.taxon_id for row in observed_taxon_ids.join(dump_taxon_ids, "taxon_id", "left_anti").collect()
]

# fetch them, then any of their ancestors that are new too, so every parent exists
fetched_taxa = []
pass_number = 1

while missing_taxon_ids and pass_number <= MAX_PASSES:
    print(f"pass {pass_number}: fetching {len(missing_taxon_ids)} taxa")
    newly_fetched = pull_taxa(missing_taxon_ids, out_dir="/Volumes/inat/raw/files/api_taxa")
    fetched_taxa.extend(newly_fetched)

    known_ids = {taxon["id"] for taxon in fetched_taxa}
    ancestor_ids = {
        int(ancestor_id)
        for taxon in newly_fetched
        if taxon.get("ancestry")
        for ancestor_id in taxon["ancestry"].split("/")
    } - known_ids

    if not ancestor_ids:
        break

    ancestor_frame = spark.createDataFrame([(ancestor_id,) for ancestor_id in ancestor_ids], "taxon_id INT")
    missing_taxon_ids = [
        row.taxon_id for row in ancestor_frame.join(dump_taxon_ids, "taxon_id", "left_anti").collect()
    ]
    pass_number += 1

dbutils.notebook.exit(json.dumps({"taxa_fetched": len(fetched_taxa)}))