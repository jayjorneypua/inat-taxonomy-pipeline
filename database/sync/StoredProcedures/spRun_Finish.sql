--=====================================================================================================
--                                        sync spRun_Finish
--=====================================================================================================
-- Purpose:  Closes a sync run as Succeeded or Failed, with the error message on failure.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE sync.spRun_Finish
    @ID_Run             BIGINT
  , @Status             VARCHAR(20)
  , @ErrorMessage       NVARCHAR(4000)  = NULL
AS BEGIN
    SET NOCOUNT ON;

    UPDATE sync.Run
    SET
        FinishedDate = SYSUTCDATETIME()
      , Status       = @Status
      , ErrorMessage = @ErrorMessage
    WHERE
        ID = @ID_Run;
END
GO