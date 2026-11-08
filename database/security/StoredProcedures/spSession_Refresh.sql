--=====================================================================================================
--                                        Security spSession_Refresh
--=====================================================================================================
-- Purpose:  Rotates the refresh token: the old one stops working, the new one is stored,
--           the expiry moves forward and the access cache is rebuilt.
--           Result: ok      = rotated, @ID_Session is set
--                   invalid = unknown, expired or revoked token, or inactive user: log in again
--                   reused  = a token that was already replaced was presented again, so someone
--                             kept a copy. The session is revoked and the event logged.
--           Returns a result instead of throwing, a bad token is a normal case, not an error.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE security.spSession_Refresh
    @OldTokenHash       VARBINARY(32)
  , @NewTokenHash       VARBINARY(32)
  , @NewExpiresDate     DATETIME2(3)
  , @ClientIpAddress    VARCHAR(45)     = NULL
  , @Result             NVARCHAR(20)    OUTPUT
  , @ID_Session         BIGINT          OUTPUT
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @Now                DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @ID_User            INT;
    DECLARE @ReusedSessionID    BIGINT;
    DECLARE @ReusedUserID       INT;

    SET @Result     = N'invalid';
    SET @ID_Session = NULL;

    -- the current token of a live session with an active user
    SELECT
        @ID_Session = sessions.ID
      , @ID_User    = sessions.ID_User
    FROM
        security.Session sessions
    INNER JOIN
        security.[User] users
        ON sessions.ID_User = users.ID
    WHERE
        sessions.TokenHash = @OldTokenHash
    AND sessions.RevokedDate IS NULL
    AND sessions.ExpiresDate > @Now
    AND users.Active = 1
    AND users.Deleted = 0;

    IF @ID_Session IS NULL BEGIN
        -- not a current token: check if it is a token that was already replaced
        SELECT
            @ReusedSessionID = sessions.ID
          , @ReusedUserID    = sessions.ID_User
        FROM
            security.Session sessions
        WHERE
            sessions.PreviousTokenHash = @OldTokenHash
        AND sessions.RevokedDate IS NULL;

        IF @ReusedSessionID IS NOT NULL BEGIN
            SET XACT_ABORT ON;

            BEGIN TRANSACTION;

            UPDATE security.Session
            SET
                RevokedDate   = @Now
              , RevokedReason = N'refresh token reused'
            WHERE
                ID = @ReusedSessionID;

            INSERT INTO security.Audit_Log (
                EventType
              , ID_User
              , ID_Session
              , ClientIpAddress
              , Details
            )
            VALUES (
                N'SessionRevoked'
              , @ReusedUserID
              , @ReusedSessionID
              , @ClientIpAddress
              , N'a replaced refresh token was used again, possible token theft'
            );

            COMMIT TRANSACTION;

            SET @Result = N'reused';
        END

        RETURN;
    END

    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    UPDATE security.Session
    SET
        PreviousTokenHash = TokenHash
      , TokenHash         = @NewTokenHash
      , ExpiresDate       = @NewExpiresDate
      , LastSeenDate      = @Now
    WHERE
        ID = @ID_Session;

    EXEC security.spSession_RebuildAccess @ID_Session = @ID_Session;

    INSERT INTO security.Audit_Log (
        EventType
      , ID_User
      , ID_Session
      , ClientIpAddress
    )
    VALUES (
        N'SessionRefreshed'
      , @ID_User
      , @ID_Session
      , @ClientIpAddress
    );

    COMMIT TRANSACTION;

    SET @Result = N'ok';
END
GO