-- one common name per taxon, best source first:
-- 1. the name the api showed on observations (inat's preferred name)
-- 2. the name from the api taxa endpoint
-- 3. the monthly taxonomy archive, a global name before a regional one
WITH observation_names AS (
    SELECT
        CAST(api_rows.taxon.id AS INT)              AS taxon_id
      , api_rows.taxon.preferred_common_name        AS common_name
      , 1                                           AS source_priority
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
        NULLIF(TRIM(api_rows.taxon.preferred_common_name), '') IS NOT NULL
)
, api_taxa_names AS (
    SELECT
        CAST(api_rows.id AS INT)                    AS taxon_id
      , api_rows.preferred_common_name              AS common_name
      , 2                                           AS source_priority
      , ROW_NUMBER() OVER (
            PARTITION BY
                api_rows.id
            ORDER BY
                api_rows._ingested_at DESC
        )                                           AS version_rank
    FROM
        {{ source('bronze', 'api_taxa') }} api_rows
    WHERE
        NULLIF(TRIM(api_rows.preferred_common_name), '') IS NOT NULL
)
, latest_archive_snapshot AS (
    SELECT
        MAX(snapshot_date) AS snapshot_date
    FROM
        {{ source('bronze', 'vernacular_names') }}
)
, archive_names AS (
    SELECT
        CAST(archive_rows.id AS INT)                AS taxon_id
      , archive_rows.vernacularName                 AS common_name
      , 3                                           AS source_priority
      , ROW_NUMBER() OVER (
            PARTITION BY
                archive_rows.id
            ORDER BY
                CASE WHEN archive_rows.countryCode IS NULL THEN 0 ELSE 1 END
              , archive_rows.created
        )                                           AS version_rank
    FROM
        {{ source('bronze', 'vernacular_names') }} archive_rows
    INNER JOIN
        latest_archive_snapshot
        ON archive_rows.snapshot_date = latest_archive_snapshot.snapshot_date
    WHERE
        NULLIF(TRIM(archive_rows.vernacularName), '') IS NOT NULL
)
, all_names AS (
    SELECT taxon_id, common_name, source_priority FROM observation_names WHERE version_rank = 1
    UNION ALL
    SELECT taxon_id, common_name, source_priority FROM api_taxa_names    WHERE version_rank = 1
    UNION ALL
    SELECT taxon_id, common_name, source_priority FROM archive_names     WHERE version_rank = 1
)
, ranked_names AS (
    SELECT
        taxon_id
      , common_name
      , ROW_NUMBER() OVER (
            PARTITION BY
                taxon_id
            ORDER BY
                source_priority
        )                                           AS name_rank
    FROM
        all_names
)
SELECT
    taxon_id
  , common_name
FROM
    ranked_names
WHERE
    name_rank = 1