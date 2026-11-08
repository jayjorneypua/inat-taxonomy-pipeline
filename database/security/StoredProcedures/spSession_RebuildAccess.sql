--=====================================================================================================
--                                        Security spSession_RebuildAccess
--=====================================================================================================
-- Purpose:  Refills the session caches (Session_Permission, Session_TaxonScope) from the
--           effective permission and scope functions. Called at login and at token refresh,
--           so role and scope changes take effect within one refresh.
--           Scope rows need the taxon's Path, so only taxa already synced into dbo.Taxon count.
--           The check runs before XACT_ABORT, so a refusal doesn't doom the caller's transaction.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
-- 2026-11-08  Jay Jorney Pua          Moved the check above XACT_ABORT.
--=====================================================================================================
CREATE PROCEDURE security.spSession_RebuildAccess
    @ID_Session         BIGINT
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @Now        DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @ID_User    INT          = (SELECT ID_User FROM security.Session WHERE ID = @ID_Session);

    IF @ID_User IS NULL BEGIN
        THROW 50010, N'spSession_RebuildAccess: session not found.', 1;
    END

    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    DELETE FROM security.Session_Permission WHERE ID_Session = @ID_Session;
    DELETE FROM security.Session_TaxonScope WHERE ID_Session = @ID_Session;

    INSERT INTO security.Session_Permission (
        ID_Session
      , ID_Permission
    )
    SELECT
        @ID_Session
      , effective_permissions.ID_Permission
    FROM
        security.fnUser_EffectivePermission(@ID_User, @Now) effective_permissions;

    INSERT INTO security.Session_TaxonScope (
        ID_Session
      , ID_Taxon
      , TaxonPath
    )
    SELECT
        @ID_Session
      , effective_scopes.ID_Taxon
      , taxa.Path
    FROM
        security.fnUser_EffectiveTaxonScope(@ID_User, @Now) effective_scopes
    INNER JOIN
        dbo.Taxon taxa
        ON effective_scopes.ID_Taxon = taxa.ID
    WHERE
        taxa.Path IS NOT NULL;

    COMMIT TRANSACTION;
END
GO