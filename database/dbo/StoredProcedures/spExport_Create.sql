--=====================================================================================================
--                                        dbo spExport_Create
--=====================================================================================================
-- Purpose:  Queues a CSV export of the observations in a taxon's subtree for the session's user.
--           Requires taxonomy.view. Returns the new job's ID. The rows themselves are read later
--           by the worker, still limited to the session's scope.
-- History:
-- 2026-11-16  Jay Jorney Pua          Created the procedure.
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
      , @PermissionCode  = N'taxonomy.view'
      , @ClientIpAddress = @ClientIpAddress
      , @ID_User         = @ID_User OUTPUT;

    INSERT INTO dbo.Export_Job
    (
        ID_User
      , ID_Session
      , ID_Taxon
    )
    VALUES
    (
        @ID_User
      , @ID_Session
      , @ID_Taxon
    );

    SELECT
        CAST(SCOPE_IDENTITY() AS INT)       AS ID;
END
GO