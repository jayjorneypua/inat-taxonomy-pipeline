--=====================================================================================================
--                                        sync spRunTable_Log
--=====================================================================================================
-- Purpose:  Records the row counts and duration of one table's merge within a run.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE sync.spRunTable_Log
    @ID_Run             BIGINT
  , @TableName          SYSNAME
  , @RowsExtracted      INT
  , @RowsInserted       INT
  , @RowsUpdated        INT
  , @RowsDeleted        INT
  , @StartedDate        DATETIME2(3)
AS BEGIN
    SET NOCOUNT ON;

    INSERT INTO sync.Run_Table (
        ID_Run
      , TableName
      , RowsExtracted
      , RowsInserted
      , RowsUpdated
      , RowsDeleted
      , StartedDate
      , FinishedDate
    )
    VALUES (
        @ID_Run
      , @TableName
      , @RowsExtracted
      , @RowsInserted
      , @RowsUpdated
      , @RowsDeleted
      , @StartedDate
      , SYSUTCDATETIME()
    );
END
GO