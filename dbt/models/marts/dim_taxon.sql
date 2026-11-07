SELECT
    taxa.taxon_id
  , taxa.parent_id
  , taxa.scientific_name
  , common_names.common_name
  , taxa.rank
  , taxa.rank_level
  , taxa.path
  , taxa.level
  , taxa.has_children
  , taxa.is_active
  , taxa.is_in_tree
  , taxa.snapshot_date
FROM
    {{ ref('stg_taxa') }} taxa
LEFT JOIN
    {{ ref('stg_taxon_common_names') }} common_names
    ON taxa.taxon_id = common_names.taxon_id