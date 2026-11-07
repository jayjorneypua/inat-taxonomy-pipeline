-- every taxon must have exactly one current version in the history
SELECT
    taxon_id
  , COUNT(*) AS current_versions
FROM
    {{ ref('snap_taxa') }}
WHERE
    dbt_valid_to IS NULL
GROUP BY
    taxon_id
HAVING
    COUNT(*) > 1