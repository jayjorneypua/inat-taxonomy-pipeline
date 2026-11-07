SELECT
    observation_uuid
  , photo_id
  , position          AS photo_position
  , license
  , extension
  , width
  , height
  , attribution
  , source
FROM
    {{ source('silver', 'observation_photos') }}