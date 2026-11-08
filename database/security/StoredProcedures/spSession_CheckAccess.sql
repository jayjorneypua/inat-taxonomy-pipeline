--=====================================================================================================
--                                        Security spSession_CheckAccess
--=====================================================================================================
-- Purpose:  The gate every dashboard procedure calls first. Passes silently when the session is
--           valid and has the permission, and returns the user id. Otherwise logs AccessDenied
--           and throws, so the calling procedure stops.
--           Callers run it before turning on XACT_ABORT, so a denial doesn't doom their transaction.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE security.spSession_CheckAccess
    @ID_Session         BIGINT
  , @PermissionCode     NVARCHAR(200)
  , @ClientIpAddress    VARCHAR(45)     = NULL
  , @ID_User            INT             OUTPUT
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @Now        DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @Message    NVARCHAR(400);

    SET @ID_User = NULL;

    SELECT
        @ID_User = sessions.ID_User
    FROM
        security.Session sessions
    INNER JOIN
        security.[User] users
        ON sessions.ID_User = users.ID
    WHERE
        sessions.ID = @ID_Session
    AND sessions.RevokedDate IS NULL
    AND sessions.ExpiresDate > @Now
    AND users.Active = 1
    AND users.Deleted = 0;

    IF @ID_User IS NULL BEGIN
        INSERT INTO security.Audit_Log (
            EventType
          , ID_Session
          , ResourceCode
          , ClientIpAddress
          , Details
        )
        VALUES (
            N'AccessDenied'
          , @ID_Session
          , @PermissionCode
          , @ClientIpAddress
          , N'invalid, expired or revoked session'
        );

        THROW 50020, N'Access denied: the session is invalid, expired or revoked.', 1;
    END

    IF NOT EXISTS (
        SELECT 1
        FROM security.Session_Permission session_permissions
        INNER JOIN security.Permission permissions
            ON session_permissions.ID_Permission = permissions.ID
        WHERE session_permissions.ID_Session = @ID_Session
        AND permissions.Code = @PermissionCode
    ) BEGIN
        INSERT INTO security.Audit_Log (
            EventType
          , ID_User
          , ID_Session
          , ResourceCode
          , ClientIpAddress
          , Details
        )
        VALUES (
            N'AccessDenied'
          , @ID_User
          , @ID_Session
          , @PermissionCode
          , @ClientIpAddress
          , N'missing permission'
        );

        SET @Message = CONCAT(N'Access denied: missing permission ', @PermissionCode, N'.');
        THROW 50021, @Message, 1;
    END

    -- record activity at most once a minute, so read heavy pages don't write on every call
    UPDATE security.Session
    SET
        LastSeenDate = @Now
    WHERE
        ID = @ID_Session
    AND LastSeenDate < DATEADD(MINUTE, -1, @Now);
END
GO