import argparse
import time
from datetime import datetime, timedelta, timezone

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
WATERMARK_OVERLAP = timedelta(hours=1)

INT = (pyodbc.SQL_INTEGER, 0, 0)
BIGINT = (pyodbc.SQL_BIGINT, 0, 0)
BIT = (pyodbc.SQL_BIT, 0, 0)
DATE = (pyodbc.SQL_TYPE_DATE, 10, 0)
TIMESTAMP = (pyodbc.SQL_TYPE_TIMESTAMP, 23, 3)


def nvarchar(length):
    return (pyodbc.SQL_WVARCHAR, length, 0)


def decimal(precision, scale):
    return (pyodbc.SQL_DECIMAL, precision, scale)


# tables with a gold_table are extracted incrementally on changed_at, the others always in full
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
        "gold_table": "inat.gold.dim_photo",
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
        "gold_table": "inat.gold.fct_observations",
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
        "gold_table": "inat.gold.bridge_observation_photo",
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


def as_utc(value):
    # sql server returns naive datetimes, they are utc by convention
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


def connect_databricks():
    databricks_config = Config(profile=DATABRICKS_PROFILE)
    return databricks_sql.connect(
        server_hostname=databricks_config.host.replace("https://", ""),
        http_path=DATABRICKS_HTTP_PATH,
        credentials_provider=lambda: databricks_config.authenticate,
    )


def read_watermarks(sql_server_connection):
    cursor = sql_server_connection.cursor()
    cursor.execute("SELECT TableName, LastUpdatedDate FROM sync.Watermark")
    return {row.TableName: row.LastUpdatedDate for row in cursor.fetchall() if row.LastUpdatedDate}


def save_watermarks(sql_server_connection, new_watermarks):
    cursor = sql_server_connection.cursor()
    for gold_table, watermark in new_watermarks.items():
        cursor.execute(
            """
            UPDATE sync.Watermark
            SET
                LastUpdatedDate = ?
              , UpdatedDate     = SYSUTCDATETIME()
            WHERE
                TableName = ?;

            IF @@ROWCOUNT = 0 BEGIN
                INSERT INTO sync.Watermark (TableName, LastUpdatedDate) VALUES (?, ?);
            END
            """,
            to_sql_value(watermark), gold_table, gold_table, to_sql_value(watermark),
        )


def read_current_max_changed_at(databricks_connection, gold_table):
    with databricks_connection.cursor() as databricks_cursor:
        databricks_cursor.execute(f"SELECT MAX(changed_at) FROM {gold_table}")
        return databricks_cursor.fetchone()[0]


def load_table(table, databricks_connection, sql_server_connection, extract_window):
    column_list = ", ".join(table["columns"])
    placeholders = ", ".join("?" for _ in table["columns"])
    insert_statement = f"INSERT INTO {table['stage_table']} ({column_list}) VALUES ({placeholders})"

    query = table["query"]
    query_parameters = None
    if extract_window is not None:
        query += " WHERE changed_at > :watermark_from AND changed_at <= :watermark_to"
        query_parameters = extract_window

    sql_server_cursor = sql_server_connection.cursor()
    sql_server_cursor.fast_executemany = True

    rows_loaded = 0
    start_time = time.time()

    with databricks_connection.cursor() as databricks_cursor:
        databricks_cursor.execute(query, query_parameters)

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


def run_merge(sql_server_connection, is_full_extract):
    cursor = sql_server_connection.cursor()

    cursor.execute(
        """
        SET NOCOUNT ON;
        DECLARE @ID_Run BIGINT;
        EXEC sync.spMerge_All @IsFullExtract = ?, @ID_Run = @ID_Run OUTPUT;
        SELECT @ID_Run;
        """,
        1 if is_full_extract else 0,
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


def sync_gold(force_full_extract):
    sync_start_time = time.time()

    with connect_databricks() as databricks_connection:
        sql_server_connection = pyodbc.connect(SQL_SERVER_CONNECTION, autocommit=False)
        try:
            incremental_tables = [table for table in TABLES if "gold_table" in table]
            stored_watermarks = read_watermarks(sql_server_connection)

            # without a watermark for every incremental table there is nothing to start from
            is_full_extract = force_full_extract or any(
                table["gold_table"] not in stored_watermarks for table in incremental_tables
            )
            print(f"{datetime.now():%H:%M:%S}  mode: {'full' if is_full_extract else 'incremental'}")

            # the upper bound of this run, read before extracting
            new_watermarks = {}
            for table in incremental_tables:
                current_max = read_current_max_changed_at(databricks_connection, table["gold_table"])
                if current_max is not None:
                    new_watermarks[table["gold_table"]] = current_max

            cursor = sql_server_connection.cursor()
            for table in TABLES:
                cursor.execute(f"TRUNCATE TABLE {table['stage_table']}")
            sql_server_connection.commit()

            for table in TABLES:
                extract_window = None
                gold_table = table.get("gold_table")
                if not is_full_extract and gold_table in new_watermarks:
                    extract_window = {
                        "watermark_from": as_utc(stored_watermarks[gold_table]) - WATERMARK_OVERLAP,
                        "watermark_to": new_watermarks[gold_table],
                    }
                load_table(table, databricks_connection, sql_server_connection, extract_window)

            print(f"{datetime.now():%H:%M:%S}  merging stage into the serving tables...")
            # the merge procedures manage their own transactions
            sql_server_connection.autocommit = True
            run_merge(sql_server_connection, is_full_extract)

            # only move the watermarks once the merge succeeded
            save_watermarks(sql_server_connection, new_watermarks)
        finally:
            sql_server_connection.close()

    print(f"\ntotal time: {(time.time() - sync_start_time) / 60:.1f} minutes")


if __name__ == "__main__":
    argument_parser = argparse.ArgumentParser(description="sync databricks gold into sql server")
    argument_parser.add_argument("--full", action="store_true", help="extract everything and delete what is gone")
    arguments = argument_parser.parse_args()
    sync_gold(force_full_extract=arguments.full)