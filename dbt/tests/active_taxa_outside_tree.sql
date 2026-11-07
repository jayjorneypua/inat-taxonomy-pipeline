-- active taxa that are cut off from the tree because an ancestor was retired.
-- this is a known source issue, so it warns instead of failing the build
{{ config(severity = 'warn') }}

SELECT
    taxon_id
  , scientific_name
  , parent_id
FROM
    {{ ref('dim_taxon') }}
WHERE
    is_active
AND NOT is_in_tree