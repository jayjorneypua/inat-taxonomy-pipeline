-- tests the full sync with a tiny dataset. Not wrapped in one transaction like the other tests,
-- because spMerge_All commits table by table. It cleans up after itself at the end instead.
USE inat;
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @ID_Run BIGINT;

TRUNCATE TABLE stage.Observer;
TRUNCATE TABLE stage.Taxon;
TRUNCATE TABLE stage.Photo;
TRUNCATE TABLE stage.Observation;
TRUNCATE TABLE stage.Observation_Photo;

INSERT INTO stage.Observer (ID, Login, Name, DisplayName) VALUES (2873, N'jmaughn', N'James Maughn', N'James Maughn');

INSERT INTO stage.Taxon (ID, ID_Parent, ScientificName, Rank, Path, Level, Active, IsInTree, HasChildren)
VALUES (48460, NULL, N'Life', N'stateofmatter', '48460', 1, 1, 1, 0);

INSERT INTO stage.Photo (ID, ID_Observer, License, Extension, SquareUrl, MediumUrl, Attribution)
VALUES
    (1001, 2873, 'CC-BY-NC', 'jpeg', 'https://example.com/1001/square.jpeg', 'https://example.com/1001/medium.jpeg', N'(c) James Maughn')
  , (1002, 2873, 'CC-BY-NC', 'jpeg', 'https://example.com/1002/square.jpeg', 'https://example.com/1002/medium.jpeg', N'(c) James Maughn');

INSERT INTO stage.Observation (ObservationUuid, ID_Taxon, ID_Observer, ObservedDate, PhotoCount, Source)
VALUES
    ('11111111-1111-1111-1111-111111111111', 48460, 2873, '2025-06-01', 1, 'dump')
  , ('22222222-2222-2222-2222-222222222222', 48460, 2873, '2025-06-02', 1, 'dump');

INSERT INTO stage.Observation_Photo (ObservationUuid, ID_Photo, PhotoPosition)
VALUES
    ('11111111-1111-1111-1111-111111111111', 1001, 0)
  , ('22222222-2222-2222-2222-222222222222', 1002, 0);

-- run 1: everything is new
EXEC sync.spMerge_All @IsFullExtract = 1, @ID_Run = @ID_Run OUTPUT;

-- run 2: observation 2 and its photo disappear from gold
DELETE FROM stage.Observation       WHERE ObservationUuid = '22222222-2222-2222-2222-222222222222';
DELETE FROM stage.Observation_Photo WHERE ObservationUuid = '22222222-2222-2222-2222-222222222222';
DELETE FROM stage.Photo             WHERE ID = 1002;

EXEC sync.spMerge_All @IsFullExtract = 1, @ID_Run = @ID_Run OUTPUT;

PRINT '--- serving counts after run 2 (expect 1 observation, 1 photo, 1 bridge row)';
SELECT 'Observation' AS table_name, COUNT(*) AS row_count FROM dbo.Observation
UNION ALL SELECT 'Photo', COUNT(*) FROM dbo.Photo
UNION ALL SELECT 'Observation_Photo', COUNT(*) FROM dbo.Observation_Photo;

PRINT '--- run log of the last 2 runs (expect run 1 all inserts, run 2: 1 photo and 1 observation deleted)';
SELECT
    run_tables.ID_Run
  , run_tables.TableName
  , run_tables.RowsInserted
  , run_tables.RowsUpdated
  , run_tables.RowsDeleted
  , runs.Status
FROM
    sync.Run_Table run_tables
INNER JOIN
    sync.Run runs
    ON run_tables.ID_Run = runs.ID
WHERE
    run_tables.ID_Run >= @ID_Run - 1
ORDER BY
    run_tables.ID;

-- clean up the test data, children before parents
DELETE FROM dbo.Observation_Photo;
DELETE FROM dbo.Observation;
DELETE FROM dbo.Photo;
DELETE FROM dbo.Observer WHERE ID = 2873;
DELETE FROM dbo.Taxon WHERE ID = 48460;
DELETE FROM sync.Run_Table;
DELETE FROM sync.Run;
TRUNCATE TABLE stage.Observer;
TRUNCATE TABLE stage.Taxon;
TRUNCATE TABLE stage.Photo;
TRUNCATE TABLE stage.Observation;
TRUNCATE TABLE stage.Observation_Photo;