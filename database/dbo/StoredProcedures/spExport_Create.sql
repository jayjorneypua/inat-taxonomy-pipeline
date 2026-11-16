--=====================================================================================================
--                                        dbo spExport_Create
--=====================================================================================================
-- Purpose:  Queues a CSV export of the observations in a taxon's subtree for the session's user.
--           Requires observations.export. Returns the new job's ID. The rows themselves are read
--           later by the worker, still limited to the session's scope.
-- History:
-- 2026-11-16  Jay Jorney Pua          Created the procedure.
-- 2026-11-16  Jay Jorney Pua          Requires observations.export, status from dbo.ExportStatus.
--=====================================================================================================
CREATE PROCEDURE dbo.spExport_Create
    @ID_Session             BIGINT
  , @ID_Taxon               INT
  , @ClientIpAddress        VARCHAR(45)     = NULL
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @ID_User INT;

    EXEC security.spSession_CheckAccess
        @ID_Session      = @ID_Session
      , @PermissionCode  = N'observations.export'
      , @ClientIpAddress = @ClientIpAddress
      , @ID_User         = @ID_User OUTPUT;

    DECLARE @ID_ExportStatus_Queued INT = (SELECT ID FROM dbo.ExportStatus WHERE Name = N'Queued');

    INSERT INTO dbo.Export_Job (
        ID_User
      , ID_Session
      , ID_Taxon
      , ID_ExportStatus
    )
    VALUES (
        @ID_User
      , @ID_Session
      , @ID_Taxon
      , @ID_ExportStatus_Queued
    );

    SELECT
        CAST(SCOPE_IDENTITY() AS INT)       AS ID;
END
GO
