-- one row per photo. a photo shared by several observations appears once,
-- preferring the api version since it is newer and carries inat's own credit text
WITH photo_versions AS (
    SELECT
        photos.photo_id
      , photos.license
      , photos.extension
      , photos.width
      , photos.height
      , photos.attribution
      , observations.observer_id
      , ROW_NUMBER() OVER (
            PARTITION BY
                photos.photo_id
            ORDER BY
                CASE WHEN photos.source = 'api' THEN 1 ELSE 2 END
        )                                                           AS version_rank
    FROM
        {{ ref('stg_observation_photos') }} photos
    INNER JOIN
        {{ ref('stg_observations') }} observations
        ON photos.observation_uuid = observations.observation_uuid
)
SELECT
    photo_versions.photo_id
  , photo_versions.license
  , photo_versions.extension
  , photo_versions.width
  , photo_versions.height
  , concat(
        'https://inaturalist-open-data.s3.amazonaws.com/photos/'
      , CAST(photo_versions.photo_id AS STRING)
      , '/square.'
      , photo_versions.extension
    )                                                               AS square_url
  , concat(
        'https://inaturalist-open-data.s3.amazonaws.com/photos/'
      , CAST(photo_versions.photo_id AS STRING)
      , '/medium.'
      , photo_versions.extension
    )                                                               AS medium_url
  , COALESCE(
        photo_versions.attribution
      , CASE
            WHEN photo_versions.license = 'CC0'
                THEN concat(observers.display_name, ', no rights reserved (CC0)')
            ELSE concat('(c) ', observers.display_name, ', some rights reserved (', photo_versions.license, ')')
        END
    )                                                               AS attribution
  , photo_versions.observer_id
FROM
    photo_versions
LEFT JOIN
    {{ ref('dim_observer') }} observers
    ON photo_versions.observer_id = observers.observer_id
WHERE
    photo_versions.version_rank = 1