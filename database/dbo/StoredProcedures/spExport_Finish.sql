--=====================================================================================================
--                                        dbo spExport_Finish
--=====================================================================================================
-- Purpose:  The worker reports how a job ended. Only a Running job, and only the worker that
--           claimed it, may finish it, and only as Done or Failed. A failed job gets the message
--           the user sees; the details stay in the API log.
-- History:
-- 2026-11-16  Jay Jorney Pua          Created the procedure.
-- 2026-11-16  Jay Jorney Pua          Checks the status change and the claimer, owns the failure text.
-- 2026-11-16  Jay Jorney Pua          Status from dbo.ExportStatus.
--=====================================================================================================
CREATE PROCEDURE dbo.spExport_Finish
    @ID_Export_Job          INT
  , @ClaimedBy              NVARCHAR(100)
  , @Status                 NVARCHAR(100)
  , @ExportRowCount         INT             = NULL
  , @FileName               NVARCHAR(260)   = NULL
AS BEGIN
    SET NOCOUNT ON;

    IF @Status NOT IN (N'Done', N'Failed') BEGIN
        THROW 51001, N'An export can only finish as Done or Failed.', 1;
    END

    DECLARE @ID_ExportStatus_Running INT = (SELECT ID FROM dbo.ExportStatus WHERE Name = N'Running');
    DECLARE @ID_ExportStatus_New     INT = (SELECT ID FROM dbo.ExportStatus WHERE Name = @Status);

    UPDATE
        export_jobs
    SET
        ID_ExportStatus = @ID_ExportStatus_New
      , ExportRowCount  =
            CASE
                WHEN @Status = N'Done' THEN @ExportRowCount
                ELSE NULL
            END
      , FileName        =
            CASE
                WHEN @Status = N'Done' THEN @FileName
                ELSE NULL
            END
      , ErrorMessage    =
            CASE
                WHEN @Status = N'Failed' THEN CONCAT(N'Export failed. Ask an administrator to check the API log for export ', @ID_Export_Job, N'.')
                ELSE NULL
            END
      , FinishedDate    = SYSUTCDATETIME()
    FROM
        dbo.Export_Job export_jobs
    WHERE
        export_jobs.ID              = @ID_Export_Job
    AND export_jobs.ID_ExportStatus = @ID_ExportStatus_Running
    AND export_jobs.ClaimedBy       = @ClaimedBy;

    IF @@ROWCOUNT = 0 BEGIN
        THROW 51002, N'The export is not running for this worker.', 1;
    END
END
GO
