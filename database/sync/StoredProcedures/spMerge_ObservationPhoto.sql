--=====================================================================================================
--                                        sync spMerge_ObservationPhoto
--=====================================================================================================
-- Purpose:  Moves stage.Observation_Photo into dbo.Observation_Photo. Stage is keyed by uuid,
--           so it is translated to dbo.Observation.ID first. Deletes pairs gone from gold
--           (full extract only), updates changed positions, inserts new pairs.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE sync.spMerge_ObservationPhoto
    @ID_Run             BIGINT
  , @IsFullExtract      BIT
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @StartedDate    DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsExtracted  INT          = (SELECT COUNT(*) FROM stage.Observation_Photo);
    DECLARE @RowsUpdated    INT;
    DECLARE @RowsInserted   INT;
    DECLARE @RowsDeleted    INT          = 0;

    -- translate uuid to the internal observation id once, for all three statements
    SELECT
        observations.ID                     AS ID_Observation
      , source_pairs.ID_Photo
      , source_pairs.PhotoPosition
    INTO
        #source_pairs
    FROM
        stage.Observation_Photo source_pairs
    INNER JOIN
        dbo.Observation observations
        ON source_pairs.ObservationUuid = observations.ObservationUuid;

    CREATE CLUSTERED INDEX IX_source_pairs ON #source_pairs (ID_Observation, ID_Photo);

    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    IF @IsFullExtract = 1 BEGIN
        DELETE target_pairs
        FROM
            dbo.Observation_Photo target_pairs
        WHERE
            NOT EXISTS (
                SELECT 1
                FROM #source_pairs source_pairs
                WHERE source_pairs.ID_Observation = target_pairs.ID_Observation
                AND source_pairs.ID_Photo = target_pairs.ID_Photo
            );

        SET @RowsDeleted = @@ROWCOUNT;
    END

    UPDATE target_pairs
    SET
        PhotoPosition = source_pairs.PhotoPosition
    FROM
        dbo.Observation_Photo target_pairs
    INNER JOIN
        #source_pairs source_pairs
        ON target_pairs.ID_Observation = source_pairs.ID_Observation
        AND target_pairs.ID_Photo = source_pairs.ID_Photo
    WHERE
        target_pairs.PhotoPosition <> source_pairs.PhotoPosition;

    SET @RowsUpdated = @@ROWCOUNT;

    INSERT INTO dbo.Observation_Photo (
        ID_Observation
      , ID_Photo
      , PhotoPosition
    )
    SELECT
        source_pairs.ID_Observation
      , source_pairs.ID_Photo
      , source_pairs.PhotoPosition
    FROM
        #source_pairs source_pairs
    WHERE
        NOT EXISTS (
            SELECT 1
            FROM dbo.Observation_Photo target_pairs
            WHERE target_pairs.ID_Observation = source_pairs.ID_Observation
            AND target_pairs.ID_Photo = source_pairs.ID_Photo
        );

    SET @RowsInserted = @@ROWCOUNT;

    COMMIT TRANSACTION;

    EXEC sync.spRunTable_Log
        @ID_Run        = @ID_Run
      , @TableName     = N'Observation_Photo'
      , @RowsExtracted = @RowsExtracted
      , @RowsInserted  = @RowsInserted
      , @RowsUpdated   = @RowsUpdated
      , @RowsDeleted   = @RowsDeleted
      , @StartedDate   = @StartedDate;
END
GO