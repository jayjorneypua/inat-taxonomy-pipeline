-- Databricks notebook source
CREATE OR REPLACE TABLE inat.silver.taxa AS
WITH latest_snapshot AS (
    SELECT
        MAX(snapshot_date) AS snapshot_date
    FROM
        inat.bronze.taxa
)
, latest_taxa AS (
    SELECT
        bronze_taxa.taxon_id
      , bronze_taxa.name
      , bronze_taxa.rank
      , bronze_taxa.rank_level
      , bronze_taxa.active
      , bronze_taxa.ancestry
      , bronze_taxa.snapshot_date
    FROM
        inat.bronze.taxa bronze_taxa
    INNER JOIN
        latest_snapshot
        ON bronze_taxa.snapshot_date = latest_snapshot.snapshot_date
)
, taxa_with_path AS (
    SELECT
        taxon_id
      , CAST(element_at(split(ancestry, '/'), -1) AS INT)          AS parent_id
      , name
      , rank
      , rank_level
      , CASE
            WHEN ancestry IS NOT NULL
                THEN concat(replace(ancestry, '/', ','), ',', CAST(taxon_id AS STRING))
            WHEN ancestry IS NULL AND active
                THEN CAST(taxon_id AS STRING)
        END                                                        AS path
      , active                                                     AS is_active
      , snapshot_date
    FROM
        latest_taxa
)
, path_ancestors AS (
    SELECT
        taxon_id
      , explode(split(path, ','))                                  AS ancestor_id
    FROM
        taxa_with_path
    WHERE
        path IS NOT NULL
)
, taxa_under_retired_ancestor AS (
    SELECT DISTINCT
        path_ancestors.taxon_id
    FROM
        path_ancestors
    INNER JOIN
        taxa_with_path retired_taxa
        ON CAST(path_ancestors.ancestor_id AS INT) = retired_taxa.taxon_id
        AND NOT retired_taxa.is_active
)
, taxa_with_tree_flag AS (
    SELECT
        taxa_with_path.taxon_id
      , taxa_with_path.parent_id
      , taxa_with_path.name
      , taxa_with_path.rank
      , taxa_with_path.rank_level
      , taxa_with_path.path
      , taxa_with_path.is_active
      , (
            taxa_with_path.is_active
        AND taxa_with_path.path IS NOT NULL
        AND taxa_under_retired_ancestor.taxon_id IS NULL
        )                                                          AS is_in_tree
      , taxa_with_path.snapshot_date
    FROM
        taxa_with_path
    LEFT JOIN
        taxa_under_retired_ancestor
        ON taxa_with_path.taxon_id = taxa_under_retired_ancestor.taxon_id
)
, tree_children AS (
    SELECT
        parent_id
      , COUNT(*) AS child_count
    FROM
        taxa_with_tree_flag
    WHERE
        is_in_tree
    GROUP BY
        parent_id
)
SELECT
    taxa_with_tree_flag.taxon_id
  , taxa_with_tree_flag.parent_id
  , taxa_with_tree_flag.name
  , taxa_with_tree_flag.rank
  , taxa_with_tree_flag.rank_level
  , taxa_with_tree_flag.path
  , CASE
        WHEN taxa_with_tree_flag.path IS NOT NULL
            THEN size(split(taxa_with_tree_flag.path, ','))
    END                                                            AS level
  , COALESCE(tree_children.child_count, 0) > 0                     AS has_children
  , taxa_with_tree_flag.is_active
  , taxa_with_tree_flag.is_in_tree
  , taxa_with_tree_flag.snapshot_date
  , current_timestamp()                                            AS _loaded_at
FROM
    taxa_with_tree_flag
LEFT JOIN
    tree_children
    ON taxa_with_tree_flag.taxon_id = tree_children.parent_id;