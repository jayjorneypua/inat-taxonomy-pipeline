--=====================================================================================================
--                                        sync spMerge_Observation
--=====================================================================================================
-- Purpose:  Moves stage.Observation into dbo.Observation, matched on ObservationUuid: updates
--           changed rows, inserts new ones. On a full extract, also deletes observations no
--           longer in gold, removing their bridge rows first.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE sync.spMerge_Observation
    @ID_Run             BIGINT
  , @IsFullExtract      BIT
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @StartedDate    DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsExtracted  INT          = (SELECT COUNT(*) FROM stage.Observation);
    DECLARE @RowsUpdated    INT;
    DECLARE @RowsInserted   INT;
    DECLARE @RowsDeleted    INT          = 0;

    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    UPDATE target_observations
    SET
        InatObservationID  = source_observations.InatObservationID
      , ID_Taxon           = source_observations.ID_Taxon
      , ID_Observer        = source_observations.ID_Observer
      , ObservedDate       = source_observations.ObservedDate
      , Latitude           = source_observations.Latitude
      , Longitude          = source_observations.Longitude
      , PositionalAccuracy = source_observations.PositionalAccuracy
      , PhotoCount         = source_observations.PhotoCount
      , Source             = source_observations.Source
      , UpdatedDate        = source_observations.UpdatedDate
      , SyncedDate         = SYSUTCDATETIME()
    FROM
        dbo.Observation target_observations
    INNER JOIN
        stage.Observation source_observations
        ON target_observations.ObservationUuid = source_observations.ObservationUuid
    WHERE
        EXISTS (
            SELECT
                target_observations.InatObservationID, target_observations.ID_Taxon, target_observations.ID_Observer
              , target_observations.ObservedDate, target_observations.Latitude, target_observations.Longitude
              , target_observations.PositionalAccuracy, target_observations.PhotoCount, target_observations.Source
              , target_observations.UpdatedDate
            EXCEPT
            SELECT
                source_observations.InatObservationID, source_observations.ID_Taxon, source_observations.ID_Observer
              , source_observations.ObservedDate, source_observations.Latitude, source_observations.Longitude
              , source_observations.PositionalAccuracy, source_observations.PhotoCount, source_observations.Source
              , source_observations.UpdatedDate
        );

    SET @RowsUpdated = @@ROWCOUNT;

    INSERT INTO dbo.Observation (
        ObservationUuid
      , InatObservationID
      , ID_Taxon
      , ID_Observer
      , ObservedDate
      , Latitude
      , Longitude
      , PositionalAccuracy
      , PhotoCount
      , Source
      , UpdatedDate
    )
    SELECT
        source_observations.ObservationUuid
      , source_observations.InatObservationID
      , source_observations.ID_Taxon
      , source_observations.ID_Observer
      , source_observations.ObservedDate
      , source_observations.Latitude
      , source_observations.Longitude
      , source_observations.PositionalAccuracy
      , source_observations.PhotoCount
      , source_observations.Source
      , source_observations.UpdatedDate
    FROM
        stage.Observation source_observations
    WHERE
        NOT EXISTS (
            SELECT 1
            FROM dbo.Observation target_observations
            WHERE target_observations.ObservationUuid = source_observations.ObservationUuid
        );

    SET @RowsInserted = @@ROWCOUNT;

    IF @IsFullExtract = 1 BEGIN
        DELETE observation_photos
        FROM
            dbo.Observation_Photo observation_photos
        INNER JOIN
            dbo.Observation target_observations
            ON observation_photos.ID_Observation = target_observations.ID
        WHERE
            NOT EXISTS (
                SELECT 1
                FROM stage.Observation source_observations
                WHERE source_observations.ObservationUuid = target_observations.ObservationUuid
            );

        DELETE target_observations
        FROM
            dbo.Observation target_observations
        WHERE
            NOT EXISTS (
                SELECT 1
                FROM stage.Observation source_observations
                WHERE source_observations.ObservationUuid = target_observations.ObservationUuid
            );

        SET @RowsDeleted = @@ROWCOUNT;
    END

    COMMIT TRANSACTION;

    EXEC sync.spRunTable_Log
        @ID_Run        = @ID_Run
      , @TableName     = N'Observation'
      , @RowsExtracted = @RowsExtracted
      , @RowsInserted  = @RowsInserted
      , @RowsUpdated   = @RowsUpdated
      , @RowsDeleted   = @RowsDeleted
      , @StartedDate   = @StartedDate;
END
GO