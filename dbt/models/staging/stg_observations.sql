SELECT
    observation_uuid
  , observation_id
  , observer_id
  , taxon_id
  , observed_on
  , latitude
  , longitude
  , positional_accuracy
  , quality_grade
  , updated_at
  , source
FROM
    {{ source('silver', 'observations') }}