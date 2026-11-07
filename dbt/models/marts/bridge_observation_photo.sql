SELECT
    observation_uuid
  , photo_id
  , photo_position
FROM
    {{ ref('stg_observation_photos') }}