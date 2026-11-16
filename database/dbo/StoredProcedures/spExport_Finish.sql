--=====================================================================================================
--                                        dbo spExport_Finish
--=====================================================================================================
-- Purpose:  The worker reports how a job ended: Done with the file name and row count, or Failed
--           with the error message.
-- History:
-- 2026-11-16  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE dbo.spExport_Finish
    @ID_Export_Job          INT
  , @Status                 VARCHAR(20)
  , @ExportRowCount         INT             = NULL
  , @FileName               NVARCHAR(260)   = NULL
  , @ErrorMessage           NVARCHAR(4000)  = NULL
AS BEGIN
    SET NOCOUNT ON;

    UPDATE
        export_jobs
    SET
        Status          = @Status
      , ExportRowCount  = @ExportRowCount
      , FileName        = @FileName
      , ErrorMessage    = @ErrorMessage
      , FinishedDate    = SYSUTCDATETIME()
    FROM
        dbo.Export_Job export_jobs
    WHERE
        export_jobs.ID = @ID_Export_Job;
END
GO