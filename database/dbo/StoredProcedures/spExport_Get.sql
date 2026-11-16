--=====================================================================================================
--                                        dbo spExport_Get
--=====================================================================================================
-- Purpose:  Status of one export for the UI. Requires taxonomy.view, and a user only ever sees
--           their own jobs: another user's job ID returns no row.
-- History:
-- 2026-11-16  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE dbo.spExport_Get
    @ID_Session             BIGINT
  , @ID_Export_Job          INT
  , @ClientIpAddress        VARCHAR(45)     = NULL
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @ID_User INT;

    EXEC security.spSession_CheckAccess
        @ID_Session      = @ID_Session
      , @PermissionCode  = N'taxonomy.view'
      , @ClientIpAddress = @ClientIpAddress
      , @ID_User         = @ID_User OUTPUT;

    SELECT
        export_jobs.ID
      , export_jobs.ID_Taxon
      , export_jobs.Status
      , export_jobs.ExportRowCount
      , export_jobs.FileName
      , export_jobs.ErrorMessage
      , export_jobs.CreatedDate
      , export_jobs.FinishedDate
    FROM
        dbo.Export_Job export_jobs
    WHERE
        export_jobs.ID      = @ID_Export_Job
    AND export_jobs.ID_User = @ID_User;
END
GO