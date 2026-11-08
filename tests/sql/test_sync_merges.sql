-- tests the observer and taxon merges inside a transaction that is rolled back at the end.
-- stage taxa are inserted children first on purpose, the merge must still insert parents first.
USE inat;
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

BEGIN TRANSACTION;

DECLARE @ID_Run BIGINT;

TRUNCATE TABLE stage.Taxon;
TRUNCATE TABLE stage.Observer;

-- children first: Amphibia, then Animalia, then Life
INSERT INTO stage.Taxon (ID, ID_Parent, ScientificName, Rank, Path, Level, Active, IsInTree, HasChildren)
VALUES
    (20978, 1,     N'Amphibia', N'class',         '48460,1,20978', 3, 1, 1, 0)
  , (1,     48460, N'Animalia', N'kingdom',       '48460,1',       2, 1, 1, 1)
  , (48460, NULL,  N'Life',     N'stateofmatter', '48460',         1, 1, 1, 1)
  , (99999, NULL,  N'Oldname',  N'species',       NULL,            NULL, 0, 0, 0);

INSERT INTO stage.Observer (ID, Login, Name, DisplayName)
VALUES
    (2873, N'jmaughn', N'James Maughn', N'James Maughn')
  , (9999, N'nameless', NULL, N'nameless');

-- first run: everything is new
EXEC sync.spRun_Start @ID_Run = @ID_Run OUTPUT;
EXEC sync.spMerge_Observer @ID_Run = @ID_Run;
EXEC sync.spMerge_Taxon    @ID_Run = @ID_Run;
EXEC sync.spRun_Finish     @ID_Run = @ID_Run, @Status = 'Succeeded';

-- second run: one taxon renamed, nothing else changed
UPDATE stage.Taxon SET CommonName = N'Amphibians' WHERE ID = 20978;

EXEC sync.spRun_Start @ID_Run = @ID_Run OUTPUT;
EXEC sync.spMerge_Observer @ID_Run = @ID_Run;
EXEC sync.spMerge_Taxon    @ID_Run = @ID_Run;
EXEC sync.spRun_Finish     @ID_Run = @ID_Run, @Status = 'Succeeded';

PRINT '--- serving taxa (expect 4 rows, Amphibia with common name Amphibians)';
SELECT
    ID
  , ID_Parent
  , ScientificName
  , CommonName
  , Level
FROM
    dbo.Taxon
ORDER BY
    Level;

PRINT '--- run log (expect run 1: 2 observers and 4 taxa inserted; run 2: 0 inserted, 1 taxon updated)';
SELECT
    run_tables.ID_Run
  , run_tables.TableName
  , run_tables.RowsExtracted
  , run_tables.RowsInserted
  , run_tables.RowsUpdated
  , runs.Status
FROM
    sync.Run_Table run_tables
INNER JOIN
    sync.Run runs
    ON run_tables.ID_Run = runs.ID
ORDER BY
    run_tables.ID;

ROLLBACK TRANSACTION;