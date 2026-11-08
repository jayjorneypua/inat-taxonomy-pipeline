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
  , ingested_at       AS changed_at
FROM
    {{ source('silver', 'observations') }}