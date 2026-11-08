--=====================================================================================================
--                                        sync spMerge_Observer
--=====================================================================================================
-- Purpose:  Moves stage.Observer into dbo.Observer: updates rows that changed, inserts new ones.
--           Observers are never deleted. EXCEPT compares nulls correctly, unlike <>.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE sync.spMerge_Observer
    @ID_Run             BIGINT
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @StartedDate    DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsExtracted  INT          = (SELECT COUNT(*) FROM stage.Observer);
    DECLARE @RowsUpdated    INT;
    DECLARE @RowsInserted   INT;

    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    UPDATE target_observers
    SET
        Login       = source_observers.Login
      , Name        = source_observers.Name
      , DisplayName = source_observers.DisplayName
      , SyncedDate  = SYSUTCDATETIME()
    FROM
        dbo.Observer target_observers
    INNER JOIN
        stage.Observer source_observers
        ON target_observers.ID = source_observers.ID
    WHERE
        EXISTS (
            SELECT target_observers.Login, target_observers.Name, target_observers.DisplayName
            EXCEPT
            SELECT source_observers.Login, source_observers.Name, source_observers.DisplayName
        );

    SET @RowsUpdated = @@ROWCOUNT;

    INSERT INTO dbo.Observer (
        ID
      , Login
      , Name
      , DisplayName
    )
    SELECT
        source_observers.ID
      , source_observers.Login
      , source_observers.Name
      , source_observers.DisplayName
    FROM
        stage.Observer source_observers
    WHERE
        NOT EXISTS (
            SELECT 1
            FROM dbo.Observer target_observers
            WHERE target_observers.ID = source_observers.ID
        );

    SET @RowsInserted = @@ROWCOUNT;

    COMMIT TRANSACTION;

    EXEC sync.spRunTable_Log
        @ID_Run        = @ID_Run
      , @TableName     = N'Observer'
      , @RowsExtracted = @RowsExtracted
      , @RowsInserted  = @RowsInserted
      , @RowsUpdated   = @RowsUpdated
      , @RowsDeleted   = 0
      , @StartedDate   = @StartedDate;
END
GO