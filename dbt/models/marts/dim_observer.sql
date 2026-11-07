-- only observers who appear in our observations, not the whole open dataset
WITH observers_in_scope AS (
    SELECT DISTINCT
        observer_id
    FROM
        {{ ref('stg_observations') }}
)
SELECT
    observers.observer_id
  , observers.login
  , observers.name
  , COALESCE(observers.name, observers.login)   AS display_name
FROM
    {{ ref('stg_observers') }} observers
INNER JOIN
    observers_in_scope
    ON observers.observer_id = observers_in_scope.observer_id