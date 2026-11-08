import time
from datetime import datetime, timezone

import pyodbc
from databricks import sql as databricks_sql
from databricks.sdk.core import Config

DATABRICKS_PROFILE = "dbc-609647e1-c073"
DATABRICKS_HTTP_PATH = "/sql/1.0/warehouses/606b0c60dc21c8fd"
SQL_SERVER_CONNECTION = (
    "Driver={ODBC Driver 18 for SQL Server};"
    "Server=.;Database=inat;Trusted_Connection=yes;"
    "Encrypt=yes;TrustServerCertificate=yes;"
)
BATCH_SIZE = 50_000

INT = (pyodbc.SQL_INTEGER, 0, 0)
BIGINT = (pyodbc.SQL_BIGINT, 0, 0)
BIT = (pyodbc.SQL_BIT, 0, 0)
DATE = (pyodbc.SQL_TYPE_DATE, 10, 0)
TIMESTAMP = (pyodbc.SQL_TYPE_TIMESTAMP, 23, 3)


def nvarchar(length):
    return (pyodbc.SQL_WVARCHAR, length, 0)


def decimal(precision, scale):
    return (pyodbc.SQL_DECIMAL, precision, scale)


# each gold table, the stage table it lands in, and the stage column types in the same order
TABLES = [
    {
        "stage_table": "stage.Observer",
        "columns": ["ID", "Login", "Name", "DisplayName"],
        "input_sizes": [INT, nvarchar(100), nvarchar(300), nvarchar(300)],
        "query": """
            SELECT
                observer_id
              , login
              , name
              , display_name
            FROM
                inat.gold.dim_observer
        """,
    },
    {
        "stage_table": "stage.Taxon",
        "columns": [
            "ID", "ID_Parent", "ScientificName", "CommonName", "Rank", "RankLevel",
            "Path", "Level", "HasChildren", "Active", "IsInTree", "SnapshotDate",
        ],
        "input_sizes": [
            INT, INT, nvarchar(300), nvarchar(300), nvarchar(50), decimal(4, 1),
            nvarchar(850), INT, BIT, BIT, BIT, DATE,
        ],
        "query": """
            SELECT
                taxon_id
              , parent_id
              , scientific_name
              , common_name
              , rank
              , CAST(rank_level AS DECIMAL(4, 1))
              , path
              , level
              , has_children
              , is_active
              , is_in_tree
              , snapshot_date
            FROM
                inat.gold.dim_taxon
        """,
    },
    {
        "stage_table": "stage.Photo",
        "columns": [
            "ID", "ID_Observer", "License", "Extension", "Width", "Height",
            "SquareUrl", "MediumUrl", "Attribution",
        ],
        "input_sizes": [
            BIGINT, INT, nvarchar(20), nvarchar(10), INT, INT,
            nvarchar(300), nvarchar(300), nvarchar(500),
        ],
        "query": """
            SELECT
                photo_id
              , observer_id
              , license
              , extension
              , width
              , height
              , square_url
              , medium_url
              , attribution
            FROM
                inat.gold.dim_photo
        """,
    },
    {
        "stage_table": "stage.Observation",
        "columns": [
            "ObservationUuid", "InatObservationID", "ID_Taxon", "ID_Observer", "ObservedDate",
            "Latitude", "Longitude", "PositionalAccuracy", "PhotoCount", "Source", "UpdatedDate",
        ],
        "input_sizes": [
            nvarchar(36), BIGINT, INT, INT, DATE,
            decimal(10, 7), decimal(10, 7), INT, INT, nvarchar(10), TIMESTAMP,
        ],
        "query": """
            SELECT
                observation_uuid
              , observation_id
              , taxon_id
              , observer_id
              , observed_on
              , CAST(latitude AS DECIMAL(10, 7))
              , CAST(longitude AS DECIMAL(10, 7))
              , positional_accuracy
              , photo_count
              , source
              , updated_at
            FROM
                inat.gold.fct_observations
        """,
    },
    {
        "stage_table": "stage.Observation_Photo",
        "columns": ["ObservationUuid", "ID_Photo", "PhotoPosition"],
        "input_sizes": [nvarchar(36), BIGINT, INT],
        "query": """
            SELECT
                observation_uuid
              , photo_id
              , photo_position
            FROM
                inat.gold.bridge_observation_photo
        """,
    },
]


def to_sql_value(value):
    # sql server datetime2 has no time zone, store everything as utc
    if isinstance(value, datetime) and value.tzinfo is not None:
        return value.astimezone(timezone.utc).replace(tzinfo=None)
    return value


def connect_databricks():
    databricks_config = Config(profile=DATABRICKS_PROFILE)
    return databricks_sql.connect(
        server_hostname=databricks_config.host.replace("https://", ""),
        http_path=DATABRICKS_HTTP_PATH,
        credentials_provider=lambda: databricks_config.authenticate,
    )


def load_table(table, databricks_connection, sql_server_connection):
    column_list = ", ".join(table["columns"])
    placeholders = ", ".join("?" for _ in table["columns"])
    insert_statement = f"INSERT INTO {table['stage_table']} ({column_list}) VALUES ({placeholders})"

    sql_server_cursor = sql_server_connection.cursor()
    sql_server_cursor.fast_executemany = True

    rows_loaded = 0
    start_time = time.time()

    with databricks_connection.cursor() as databricks_cursor:
        databricks_cursor.execute(table["query"])

        while True:
            batch = databricks_cursor.fetchmany(BATCH_SIZE)
            if not batch:
                break

            rows = [tuple(to_sql_value(value) for value in row) for row in batch]
            sql_server_cursor.setinputsizes(table["input_sizes"])
            sql_server_cursor.executemany(insert_statement, rows)
            sql_server_connection.commit()

            rows_loaded += len(rows)
            elapsed_seconds = time.time() - start_time
            print(
                f"{datetime.now():%H:%M:%S}  {table['stage_table']}: {rows_loaded:,} rows"
                f", {rows_loaded / elapsed_seconds:,.0f} rows/s"
            )

    print(f"{datetime.now():%H:%M:%S}  {table['stage_table']}: done, {rows_loaded:,} rows")


def run_merge(sql_server_connection):
    # the merge procedures manage their own transactions, so no outer transaction here
    sql_server_connection.autocommit = True
    cursor = sql_server_connection.cursor()

    cursor.execute(
        """
        SET NOCOUNT ON;
        DECLARE @ID_Run BIGINT;
        EXEC sync.spMerge_All @IsFullExtract = 1, @ID_Run = @ID_Run OUTPUT;
        SELECT @ID_Run;
        """
    )
    id_run = cursor.fetchone()[0]

    cursor.execute(
        """
        SELECT
            TableName
          , RowsExtracted
          , RowsInserted
          , RowsUpdated
          , RowsDeleted
          , DATEDIFF(SECOND, StartedDate, FinishedDate) AS Seconds
        FROM
            sync.Run_Table
        WHERE
            ID_Run = ?
        ORDER BY
            ID
        """,
        id_run,
    )

    print(f"\nrun {id_run} finished:")
    for run_table in cursor.fetchall():
        print(
            f"  {run_table.TableName:<18} extracted {run_table.RowsExtracted:>10,}"
            f"  inserted {run_table.RowsInserted:>10,}  updated {run_table.RowsUpdated:>10,}"
            f"  deleted {run_table.RowsDeleted:>8,}  {run_table.Seconds}s"
        )


def sync_gold():
    sync_start_time = time.time()

    with connect_databricks() as databricks_connection:
        sql_server_connection = pyodbc.connect(SQL_SERVER_CONNECTION, autocommit=False)
        try:
            cursor = sql_server_connection.cursor()
            for table in TABLES:
                cursor.execute(f"TRUNCATE TABLE {table['stage_table']}")
            sql_server_connection.commit()

            for table in TABLES:
                load_table(table, databricks_connection, sql_server_connection)

            print(f"{datetime.now():%H:%M:%S}  merging stage into the serving tables...")
            run_merge(sql_server_connection)
        finally:
            sql_server_connection.close()

    print(f"\ntotal time: {(time.time() - sync_start_time) / 60:.1f} minutes")


if __name__ == "__main__":
    sync_gold()