--=====================================================================================================
--                                        sync spMerge_Taxon
--=====================================================================================================
-- Purpose:  Moves stage.Taxon into dbo.Taxon. New taxa are inserted in passes: each pass inserts
--           every new taxon whose parent is null or already in dbo.Taxon, until a pass inserts
--           nothing. Parents always land before children, as the ID_Parent foreign key requires,
--           without assuming anything about Level (retired taxa can have none).
--           Anything left after the passes has a parent missing from the data, which stops the
--           merge with a clear error. Then changed taxa are updated. Taxa are never deleted.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
-- 2026-11-08  Jay Jorney Pua          Insert by parent existence instead of by level.
--=====================================================================================================
CREATE PROCEDURE sync.spMerge_Taxon
    @ID_Run             BIGINT
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @StartedDate            DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsExtracted          INT          = (SELECT COUNT(*) FROM stage.Taxon);
    DECLARE @RowsUpdated            INT;
    DECLARE @RowsInserted           INT          = 0;
    DECLARE @RowsInsertedThisPass   INT          = 1;

    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    -- new taxa in passes, a taxon goes in once its parent exists
    WHILE @RowsInsertedThisPass > 0 BEGIN
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
            NOT EXISTS (
                SELECT 1
                FROM dbo.Taxon target_taxa
                WHERE target_taxa.ID = source_taxa.ID
            )
        AND (
                source_taxa.ID_Parent IS NULL
             OR EXISTS (
                    SELECT 1
                    FROM dbo.Taxon parent_taxa
                    WHERE parent_taxa.ID = source_taxa.ID_Parent
                )
            );

        SET @RowsInsertedThisPass = @@ROWCOUNT;
        SET @RowsInserted += @RowsInsertedThisPass;
    END

    -- anything still missing has a parent that is not in the data at all
    IF EXISTS (
        SELECT 1
        FROM stage.Taxon source_taxa
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.Taxon target_taxa
            WHERE target_taxa.ID = source_taxa.ID
        )
    ) BEGIN
        THROW 50030, N'spMerge_Taxon: some taxa reference a parent that is missing from the data.', 1;
    END

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