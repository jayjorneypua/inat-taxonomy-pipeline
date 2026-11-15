--=====================================================================================================
--                                        Security spSession_GetAccessContext
--=====================================================================================================
-- Purpose:  The cheap check the api runs before answering from its cache. Checks the session and the
--           permission exactly like every other procedure (so logout and permission changes apply
--           immediately), then returns what a cache key needs:
--             ScopeSignature  the session's scope taxon ids, sorted: same scope, same cached answers
--             DataVersion     the last successful sync run: a new sync means new keys, so stale
--                             answers are never asked for again
-- History:
-- 2026-11-15  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE security.spSession_GetAccessContext
    @ID_Session         BIGINT
  , @PermissionCode     NVARCHAR(200)
  , @ClientIpAddress    VARCHAR(45)     = NULL
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @ID_User INT;

    EXEC security.spSession_CheckAccess
        @ID_Session      = @ID_Session
      , @PermissionCode  = @PermissionCode
      , @ClientIpAddress = @ClientIpAddress
      , @ID_User         = @ID_User OUTPUT;

    SELECT
        ISNULL(
            (
                SELECT
                    STRING_AGG(CAST(scopes.ID_Taxon AS NVARCHAR(MAX)), N',') WITHIN GROUP (ORDER BY scopes.ID_Taxon)
                FROM
                    security.Session_TaxonScope scopes
                WHERE
                    scopes.ID_Session = @ID_Session
            )
          , N''
        )                                   AS ScopeSignature
      , ISNULL(
            (
                SELECT
                    MAX(runs.ID)
                FROM
                    sync.Run runs
                WHERE
                    runs.Status = 'Succeeded'
            )
          , 0
        )                                   AS DataVersion;
END
GO