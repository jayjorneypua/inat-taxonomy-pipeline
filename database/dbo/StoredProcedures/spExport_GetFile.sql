--=====================================================================================================
--                                        dbo spExport_GetFile
--=====================================================================================================
-- Purpose:  Decides whether a download is allowed: requires observations.export, only the owner's
--           job, only when Done. Returns the stored file name and the name the browser saves it as,
--           or no row, in which case the API answers 404.
-- History:
-- 2026-11-16  Jay Jorney Pua          Created the procedure.
-- 2026-11-16  Jay Jorney Pua          Requires observations.export, status from dbo.ExportStatus.
--=====================================================================================================
CREATE PROCEDURE dbo.spExport_GetFile
    @ID_Session             BIGINT
  , @ID_Export_Job          INT
  , @ClientIpAddress        VARCHAR(45)     = NULL
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @ID_User INT;

    EXEC security.spSession_CheckAccess
        @ID_Session      = @ID_Session
      , @PermissionCode  = N'observations.export'
      , @ClientIpAddress = @ClientIpAddress
      , @ID_User         = @ID_User OUTPUT;

    DECLARE @ID_ExportStatus_Done INT = (SELECT ID FROM dbo.ExportStatus WHERE Name = N'Done');

    SELECT
        export_jobs.FileName
      , CONCAT(N'observations-taxon-', export_jobs.ID_Taxon, N'-export-', export_jobs.ID, N'.csv')   AS DownloadName
    FROM
        dbo.Export_Job export_jobs
    WHERE
        export_jobs.ID              = @ID_Export_Job
    AND export_jobs.ID_User         = @ID_User
    AND export_jobs.ID_ExportStatus = @ID_ExportStatus_Done
    AND export_jobs.FileName        IS NOT NULL;
END
GO
