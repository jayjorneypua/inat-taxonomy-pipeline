WITH photo_counts AS (
    SELECT
        observation_uuid
      , COUNT(*) AS photo_count
    FROM
        {{ ref('bridge_observation_photo') }}
    GROUP BY
        observation_uuid
)
SELECT
    observations.observation_uuid
  , observations.observation_id
  , observations.taxon_id
  , observations.observer_id
  , CAST(date_format(observations.observed_on, 'yyyyMMdd') AS INT)   AS observed_date_key
  , observations.observed_on
  , observations.latitude
  , observations.longitude
  , observations.positional_accuracy
  , COALESCE(photo_counts.photo_count, 0)                           AS photo_count
  , observations.source
  , observations.updated_at
  , observations.changed_at
FROM
    {{ ref('stg_observations') }} observations
LEFT JOIN
    photo_counts
    ON observations.observation_uuid = photo_counts.observation_uuid