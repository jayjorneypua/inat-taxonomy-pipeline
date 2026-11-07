-- the dump has no common names, so take the newest one the api returned per taxon
WITH common_name_versions AS (
    SELECT
        CAST(api_rows.taxon.id AS INT)              AS taxon_id
      , api_rows.taxon.preferred_common_name        AS common_name
      , ROW_NUMBER() OVER (
            PARTITION BY
                api_rows.taxon.id
            ORDER BY
                to_timestamp(api_rows.updated_at) DESC
              , api_rows._ingested_at DESC
        )                                           AS version_rank
    FROM
        {{ source('bronze', 'api_observations') }} api_rows
    WHERE
        api_rows.taxon.preferred_common_name IS NOT NULL
)
SELECT
    taxon_id
  , common_name
FROM
    common_name_versions
WHERE
    version_rank = 1