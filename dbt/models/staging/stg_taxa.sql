SELECT
    taxon_id
  , parent_id
  , name              AS scientific_name
  , rank
  , rank_level
  , path
  , level
  , has_children
  , is_active
  , is_in_tree
  , snapshot_date
FROM
    {{ source('silver', 'taxa') }}