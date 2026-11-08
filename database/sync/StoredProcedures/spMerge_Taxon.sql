--=====================================================================================================
--                                        sync spMerge_Taxon
--=====================================================================================================
-- Purpose:  Moves stage.Taxon into dbo.Taxon. New taxa are inserted level by level (1, then 2,
--           and so on) so a parent always exists before its children, as the ID_Parent foreign
--           key requires. Taxa without a level (retired, outside the tree) go last.
--           Then changed taxa are updated. Taxa are never deleted, retired ones stay with Active = 0.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE sync.spMerge_Taxon
    @ID_Run             BIGINT
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @StartedDate    DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsExtracted  INT          = (SELECT COUNT(*) FROM stage.Taxon);
    DECLARE @RowsUpdated    INT;
    DECLARE @RowsInserted   INT          = 0;
    DECLARE @CurrentLevel   INT;

    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    -- new taxa, level by level, parents first
    SET @CurrentLevel = (SELECT MIN(Level) FROM stage.Taxon WHERE Level IS NOT NULL);

    WHILE @CurrentLevel IS NOT NULL BEGIN
        INSERT INTO dbo.Taxon (
            ID
          , ID_Parent
          , ScientificName
          , CommonName
          , Rank
          , RankLevel
          , Path
          , Level
          , HasChildren
          , Active
          , IsInTree
          , SnapshotDate
        )
        SELECT
            source_taxa.ID
          , source_taxa.ID_Parent
          , source_taxa.ScientificName
          , source_taxa.CommonName
          , source_taxa.Rank
          , source_taxa.RankLevel
          , source_taxa.Path
          , source_taxa.Level
          , source_taxa.HasChildren
          , source_taxa.Active
          , source_taxa.IsInTree
          , source_taxa.SnapshotDate
        FROM
            stage.Taxon source_taxa
        WHERE
            source_taxa.Level = @CurrentLevel
        AND NOT EXISTS (
                SELECT 1
                FROM dbo.Taxon target_taxa
                WHERE target_taxa.ID = source_taxa.ID
            );

        SET @RowsInserted += @@ROWCOUNT;
        SET @CurrentLevel = (SELECT MIN(Level) FROM stage.Taxon WHERE Level > @CurrentLevel);
    END

    -- taxa without a level: retired and outside the tree
    INSERT INTO dbo.Taxon (
        ID
      , ID_Parent
      , ScientificName
      , CommonName
      , Rank
      , RankLevel
      , Path
      , Level
      , HasChildren
      , Active
      , IsInTree
      , SnapshotDate
    )
    SELECT
        source_taxa.ID
      , source_taxa.ID_Parent
      , source_taxa.ScientificName
      , source_taxa.CommonName
      , source_taxa.Rank
      , source_taxa.RankLevel
      , source_taxa.Path
      , source_taxa.Level
      , source_taxa.HasChildren
      , source_taxa.Active
      , source_taxa.IsInTree
      , source_taxa.SnapshotDate
    FROM
        stage.Taxon source_taxa
    WHERE
        source_taxa.Level IS NULL
    AND NOT EXISTS (
            SELECT 1
            FROM dbo.Taxon target_taxa
            WHERE target_taxa.ID = source_taxa.ID
        );

    SET @RowsInserted += @@ROWCOUNT;

    -- changed taxa
    UPDATE target_taxa
    SET
        ID_Parent      = source_taxa.ID_Parent
      , ScientificName = source_taxa.ScientificName
      , CommonName     = source_taxa.CommonName
      , Rank           = source_taxa.Rank
      , RankLevel      = source_taxa.RankLevel
      , Path           = source_taxa.Path
      , Level          = source_taxa.Level
      , HasChildren    = source_taxa.HasChildren
      , Active         = source_taxa.Active
      , IsInTree       = source_taxa.IsInTree
      , SnapshotDate   = source_taxa.SnapshotDate
      , SyncedDate     = SYSUTCDATETIME()
    FROM
        dbo.Taxon target_taxa
    INNER JOIN
        stage.Taxon source_taxa
        ON target_taxa.ID = source_taxa.ID
    WHERE
        EXISTS (
            SELECT
                target_taxa.ID_Parent, target_taxa.ScientificName, target_taxa.CommonName, target_taxa.Rank
              , target_taxa.RankLevel, target_taxa.Path, target_taxa.Level, target_taxa.HasChildren
              , target_taxa.Active, target_taxa.IsInTree, target_taxa.SnapshotDate
            EXCEPT
            SELECT
                source_taxa.ID_Parent, source_taxa.ScientificName, source_taxa.CommonName, source_taxa.Rank
              , source_taxa.RankLevel, source_taxa.Path, source_taxa.Level, source_taxa.HasChildren
              , source_taxa.Active, source_taxa.IsInTree, source_taxa.SnapshotDate
        );

    SET @RowsUpdated = @@ROWCOUNT;

    COMMIT TRANSACTION;

    EXEC sync.spRunTable_Log
        @ID_Run        = @ID_Run
      , @TableName     = N'Taxon'
      , @RowsExtracted = @RowsExtracted
      , @RowsInserted  = @RowsInserted
      , @RowsUpdated   = @RowsUpdated
      , @RowsDeleted   = 0
      , @StartedDate   = @StartedDate;
END
GO