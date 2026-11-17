{{
    config(
        materialized = 'incremental'
      , unique_key = 'taxon_id'
      , incremental_strategy = 'merge'
      , on_schema_change = 'fail'
    )
}}

-- one row per taxon. changed_at only moves when a taxon's values change, so the sync
-- can pull just those taxa: each run hashes the values and rewrites only new or changed rows
WITH taxa AS (
    SELECT
        stg_taxa.taxon_id
      , stg_taxa.parent_id
      , stg_taxa.scientific_name
      , common_names.common_name
      , stg_taxa.rank
      , stg_taxa.rank_level
      , stg_taxa.path
      , stg_taxa.level
      , stg_taxa.has_children
      , stg_taxa.is_active
      , stg_taxa.is_in_tree
      , stg_taxa.snapshot_date
      -- to_json keeps null and empty apart, so a value going to null still changes the hash
      , sha2(
            to_json(
                named_struct(
                    'parent_id', stg_taxa.parent_id
                  , 'scientific_name', stg_taxa.scientific_name
                  , 'common_name', common_names.common_name
                  , 'rank', stg_taxa.rank
                  , 'rank_level', stg_taxa.rank_level
                  , 'path', stg_taxa.path
                  , 'level', stg_taxa.level
                  , 'has_children', stg_taxa.has_children
                  , 'is_active', stg_taxa.is_active
                  , 'is_in_tree', stg_taxa.is_in_tree
                  , 'snapshot_date', stg_taxa.snapshot_date
                )
            )
          , 256
        )                                           AS row_hash
    FROM
        {{ ref('stg_taxa') }} stg_taxa
    LEFT JOIN
        {{ ref('stg_taxon_common_names') }} common_names
        ON stg_taxa.taxon_id = common_names.taxon_id
)
SELECT
    taxa.taxon_id
  , taxa.parent_id
  , taxa.scientific_name
  , taxa.common_name
  , taxa.rank
  , taxa.rank_level
  , taxa.path
  , taxa.level
  , taxa.has_children
  , taxa.is_active
  , taxa.is_in_tree
  , taxa.snapshot_date
  , taxa.row_hash
  , current_timestamp()                             AS changed_at
FROM
    taxa
{% if is_incremental() %}
LEFT JOIN
    {{ this }} existing_taxa
    ON taxa.taxon_id = existing_taxa.taxon_id
WHERE
    existing_taxa.taxon_id IS NULL
 OR existing_taxa.row_hash <> taxa.row_hash
{% endif %}
