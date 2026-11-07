WITH calendar_days AS (
    SELECT
        explode(sequence(DATE '2025-01-01', current_date(), INTERVAL 1 DAY)) AS full_date
)
SELECT
    CAST(date_format(full_date, 'yyyyMMdd') AS INT)   AS date_key
  , full_date
  , year(full_date)                                   AS year
  , quarter(full_date)                                AS quarter
  , month(full_date)                                  AS month
  , date_format(full_date, 'MMMM')                    AS month_name
  , day(full_date)                                    AS day_of_month
  , dayofweek(full_date)                              AS day_of_week
  , date_format(full_date, 'EEEE')                    AS day_name
  , weekofyear(full_date)                             AS week_of_year
  , dayofweek(full_date) IN (1, 7)                    AS is_weekend
FROM
    calendar_days