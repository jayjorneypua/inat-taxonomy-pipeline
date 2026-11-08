--=====================================================================================================
--                                        sync spMerge_Photo
--=====================================================================================================
-- Purpose:  Moves stage.Photo into dbo.Photo: updates changed rows, inserts new ones. On a full
--           extract, also deletes photos no longer in gold, removing their bridge rows first.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE sync.spMerge_Photo
    @ID_Run             BIGINT
  , @IsFullExtract      BIT
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @StartedDate    DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsExtracted  INT          = (SELECT COUNT(*) FROM stage.Photo);
    DECLARE @RowsUpdated    INT;
    DECLARE @RowsInserted   INT;
    DECLARE @RowsDeleted    INT          = 0;

    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    UPDATE target_photos
    SET
        ID_Observer = source_photos.ID_Observer
      , License     = source_photos.License
      , Extension   = source_photos.Extension
      , Width       = source_photos.Width
      , Height      = source_photos.Height
      , SquareUrl   = source_photos.SquareUrl
      , MediumUrl   = source_photos.MediumUrl
      , Attribution = source_photos.Attribution
      , SyncedDate  = SYSUTCDATETIME()
    FROM
        dbo.Photo target_photos
    INNER JOIN
        stage.Photo source_photos
        ON target_photos.ID = source_photos.ID
    WHERE
        EXISTS (
            SELECT
                target_photos.ID_Observer, target_photos.License, target_photos.Extension, target_photos.Width
              , target_photos.Height, target_photos.SquareUrl, target_photos.MediumUrl, target_photos.Attribution
            EXCEPT
            SELECT
                source_photos.ID_Observer, source_photos.License, source_photos.Extension, source_photos.Width
              , source_photos.Height, source_photos.SquareUrl, source_photos.MediumUrl, source_photos.Attribution
        );

    SET @RowsUpdated = @@ROWCOUNT;

    INSERT INTO dbo.Photo (
        ID
      , ID_Observer
      , License
      , Extension
      , Width
      , Height
      , SquareUrl
      , MediumUrl
      , Attribution
    )
    SELECT
        source_photos.ID
      , source_photos.ID_Observer
      , source_photos.License
      , source_photos.Extension
      , source_photos.Width
      , source_photos.Height
      , source_photos.SquareUrl
      , source_photos.MediumUrl
      , source_photos.Attribution
    FROM
        stage.Photo source_photos
    WHERE
        NOT EXISTS (
            SELECT 1
            FROM dbo.Photo target_photos
            WHERE target_photos.ID = source_photos.ID
        );

    SET @RowsInserted = @@ROWCOUNT;

    IF @IsFullExtract = 1 BEGIN
        DELETE observation_photos
        FROM
            dbo.Observation_Photo observation_photos
        WHERE
            NOT EXISTS (
                SELECT 1
                FROM stage.Photo source_photos
                WHERE source_photos.ID = observation_photos.ID_Photo
            );

        DELETE target_photos
        FROM
            dbo.Photo target_photos
        WHERE
            NOT EXISTS (
                SELECT 1
                FROM stage.Photo source_photos
                WHERE source_photos.ID = target_photos.ID
            );

        SET @RowsDeleted = @@ROWCOUNT;
    END

    COMMIT TRANSACTION;

    EXEC sync.spRunTable_Log
        @ID_Run        = @ID_Run
      , @TableName     = N'Photo'
      , @RowsExtracted = @RowsExtracted
      , @RowsInserted  = @RowsInserted
      , @RowsUpdated   = @RowsUpdated
      , @RowsDeleted   = @RowsDeleted
      , @StartedDate   = @StartedDate;
END
GO