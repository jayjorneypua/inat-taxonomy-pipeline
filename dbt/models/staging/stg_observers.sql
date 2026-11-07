WITH latest_dump_snapshot AS (
    SELECT
        MAX(snapshot_date) AS snapshot_date
    FROM
        {{ source('bronze', 'observers') }}
)
, dump_observers AS (
    SELECT
        dump_rows.observer_id
      , dump_rows.login
      , dump_rows.name
    FROM
        {{ source('bronze', 'observers') }} dump_rows
    INNER JOIN
        latest_dump_snapshot
        ON dump_rows.snapshot_date = latest_dump_snapshot.snapshot_date
)
, api_observer_versions AS (
    SELECT
        CAST(api_rows.`user`.id AS INT)       AS observer_id
      , api_rows.`user`.login                 AS login
      , api_rows.`user`.name                  AS name
      , ROW_NUMBER() OVER (
            PARTITION BY
                api_rows.`user`.id
            ORDER BY
                to_timestamp(api_rows.updated_at) DESC
              , api_rows._ingested_at DESC
        )                                     AS version_rank
    FROM
        {{ source('bronze', 'api_observations') }} api_rows
)
, api_observers AS (
    SELECT
        observer_id
      , login
      , name
    FROM
        api_observer_versions
    WHERE
        version_rank = 1
)
-- api is newer, but older api rows have no name, so fall back to the dump
SELECT
    COALESCE(api_observers.observer_id, dump_observers.observer_id)  AS observer_id
  , COALESCE(api_observers.login, dump_observers.login)              AS login
  , COALESCE(api_observers.name, dump_observers.name)                AS name
FROM
    dump_observers
FULL OUTER JOIN
    api_observers
    ON dump_observers.observer_id = api_observers.observer_id