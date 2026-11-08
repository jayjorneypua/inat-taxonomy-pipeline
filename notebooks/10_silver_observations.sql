-- Databricks notebook source
CREATE OR REPLACE TABLE inat.silver.observations AS
WITH latest_dump_snapshot AS (
    SELECT
        MAX(snapshot_date) AS snapshot_date
    FROM
        inat.bronze.observations
)
, dump_observations AS (
    SELECT
        dump_rows.observation_uuid
      , CAST(NULL AS BIGINT)                                    AS observation_id
      , dump_rows.observer_id
      , dump_rows.latitude
      , dump_rows.longitude
      , dump_rows.positional_accuracy
      , dump_rows.taxon_id
      , dump_rows.quality_grade
      , dump_rows.observed_on
      , CAST(NULL AS TIMESTAMP)                                 AS updated_at
      , CAST(dump_rows.snapshot_date AS TIMESTAMP)              AS as_of_at
      , dump_rows._ingested_at                                  AS ingested_at
      , 'dump'                                                  AS source
      , 1                                                       AS source_priority
    FROM
        inat.bronze.observations dump_rows
    INNER JOIN
        latest_dump_snapshot
        ON dump_rows.snapshot_date = latest_dump_snapshot.snapshot_date
)
, api_observations AS (
    SELECT
        api_rows.uuid                                           AS observation_uuid
      , CAST(api_rows.id AS BIGINT)                             AS observation_id
      , CAST(api_rows.user.id AS INT)                           AS observer_id
      , CAST(element_at(split(api_rows.location, ','), 1) AS DOUBLE)  AS latitude
      , CAST(element_at(split(api_rows.location, ','), 2) AS DOUBLE)  AS longitude
      , CAST(api_rows.positional_accuracy AS INT)               AS positional_accuracy
      , CAST(api_rows.taxon.id AS INT)                          AS taxon_id
      , api_rows.quality_grade
      , CAST(api_rows.observed_on AS DATE)                      AS observed_on
      , to_timestamp(api_rows.updated_at)                       AS updated_at
      , to_timestamp(api_rows.updated_at)                       AS as_of_at
      , api_rows._ingested_at                                   AS ingested_at
      , 'api'                                                   AS source
      , 2                                                       AS source_priority
    FROM
        inat.bronze.api_observations api_rows
    CROSS JOIN
        latest_dump_snapshot
    WHERE
        to_timestamp(api_rows.updated_at) >= CAST(latest_dump_snapshot.snapshot_date AS TIMESTAMP)
)
, all_versions AS (
    SELECT * FROM dump_observations
    UNION ALL
    SELECT * FROM api_observations
)
, ranked_versions AS (
    SELECT
        all_versions.*
      , ROW_NUMBER() OVER (
            PARTITION BY
                observation_uuid
            ORDER BY
                as_of_at DESC
              , source_priority DESC
              , ingested_at DESC
        )                                                       AS version_rank
    FROM
        all_versions
)
SELECT
    observation_uuid
  , observation_id
  , observer_id
  , latitude
  , longitude
  , positional_accuracy
  , taxon_id
  , quality_grade
  , observed_on
  , updated_at
  , as_of_at
  , ingested_at
  , source
  , current_timestamp()                                         AS _loaded_at
FROM
    ranked_versions
WHERE
    version_rank = 1;

-- COMMAND ----------

CREATE OR REPLACE TABLE inat.silver.observation_photos AS
WITH latest_dump_snapshot AS (
    SELECT
        MAX(snapshot_date) AS snapshot_date
    FROM
        inat.bronze.photos
)
, dump_photos AS (
    SELECT
        dump_rows.observation_uuid
      , CAST(dump_rows.photo_id AS BIGINT)                      AS photo_id
      , dump_rows.position
      , upper(dump_rows.license)                                AS license
      , dump_rows.extension
      , dump_rows.width
      , dump_rows.height
      , CAST(NULL AS STRING)                                    AS attribution
      , dump_rows._ingested_at                                  AS ingested_at
      , 'dump'                                                  AS source
    FROM
        inat.bronze.photos dump_rows
    INNER JOIN
        latest_dump_snapshot
        ON dump_rows.snapshot_date = latest_dump_snapshot.snapshot_date
)
, latest_api_versions AS (
    SELECT
        api_rows.uuid
      , api_rows.photos
      , api_rows._ingested_at
      , ROW_NUMBER() OVER (
            PARTITION BY
                api_rows.uuid
            ORDER BY
                to_timestamp(api_rows.updated_at) DESC
              , api_rows._ingested_at DESC
        )                                                       AS version_rank
    FROM
        inat.bronze.api_observations api_rows
)
, api_photos AS (
    SELECT
        latest_api_versions.uuid                                AS observation_uuid
      , CAST(api_photo.id AS BIGINT)                            AS photo_id
      , photo_position                                          AS position
      , upper(api_photo.license_code)                           AS license
      , regexp_extract(api_photo.url, '[.]([A-Za-z0-9]+)$', 1)  AS extension
      , CAST(NULL AS INT)                                       AS width
      , CAST(NULL AS INT)                                       AS height
      , api_photo.attribution
      , latest_api_versions._ingested_at                        AS ingested_at
      , 'api'                                                   AS source
    FROM
        latest_api_versions
    LATERAL VIEW
        posexplode(latest_api_versions.photos) photo_list AS photo_position, api_photo
    WHERE
        latest_api_versions.version_rank = 1
    AND api_photo.license_code IS NOT NULL
)
, all_photos AS (
    SELECT * FROM dump_photos
    UNION ALL
    SELECT * FROM api_photos
)
SELECT
    all_photos.observation_uuid
  , all_photos.photo_id
  , all_photos.position
  , all_photos.license
  , all_photos.extension
  , all_photos.width
  , all_photos.height
  , all_photos.attribution
  , all_photos.ingested_at
  , all_photos.source
  , current_timestamp()                                         AS _loaded_at
FROM
    all_photos
INNER JOIN
    inat.silver.observations silver_observations
    ON all_photos.observation_uuid = silver_observations.observation_uuid
    AND all_photos.source = silver_observations.source;