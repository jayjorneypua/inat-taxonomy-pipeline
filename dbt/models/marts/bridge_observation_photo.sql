SELECT
    observation_uuid
  , photo_id
  , photo_position
  , changed_at
FROM
    {{ ref('stg_observation_photos') }}