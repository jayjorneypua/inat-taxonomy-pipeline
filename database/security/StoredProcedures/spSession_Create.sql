--=====================================================================================================
--                                        Security spSession_Create
--=====================================================================================================
-- Purpose:  Final step of a successful login, after the api has verified the password.
--           Creates the session with the hash of the refresh token, caches effective access,
--           resets the failure counters and logs the login. Returns the new session id.
--           Checks run before XACT_ABORT is turned on, so a refusal doesn't doom the caller's
--           transaction. XACT_ABORT then protects the writes.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
-- 2026-11-08  Jay Jorney Pua          Moved the checks above XACT_ABORT.
--=====================================================================================================
CREATE PROCEDURE security.spSession_Create
    @ID_User            INT
  , @TokenHash          VARBINARY(32)
  , @ExpiresDate        DATETIME2(3)
  , @ClientIpAddress    VARCHAR(45)     = NULL
  , @UserAgent          NVARCHAR(500)   = NULL
  , @ID_Session         BIGINT          OUTPUT
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @Now DATETIME2(3) = SYSUTCDATETIME();

    -- defensive: the api checked these already, the database still refuses on its own
    IF NOT EXISTS (
        SELECT 1
        FROM security.[User] users
        WHERE users.ID = @ID_User
        AND users.Active = 1
        AND users.Deleted = 0
        AND users.PasswordHash IS NOT NULL
        AND (users.LockedUntil IS NULL OR users.LockedUntil <= @Now)
    ) BEGIN
        THROW 50011, N'spSession_Create: user is inactive, deleted, cannot log in or is locked.', 1;
    END

    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    INSERT INTO security.Session (
        ID_User
      , TokenHash
      , ExpiresDate
      , ClientIpAddress
      , UserAgent
    )
    VALUES (
        @ID_User
      , @TokenHash
      , @ExpiresDate
      , @ClientIpAddress
      , @UserAgent
    );

    SET @ID_Session = SCOPE_IDENTITY();

    EXEC security.spSession_RebuildAccess @ID_Session = @ID_Session;

    UPDATE security.[User]
    SET
        LoginCount       = LoginCount + 1
      , FailedLoginCount = 0
      , LockedUntil      = NULL
      , LastLoginDate    = @Now
    WHERE
        ID = @ID_User;

    INSERT INTO security.Audit_Log (
        EventType
      , ID_User
      , ID_Session
      , ClientIpAddress
    )
    VALUES (
        N'LoginSucceeded'
      , @ID_User
      , @ID_Session
      , @ClientIpAddress
    );

    COMMIT TRANSACTION;
END
GO