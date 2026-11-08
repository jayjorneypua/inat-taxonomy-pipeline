--=====================================================================================================
--                                        Security spSession_Revoke
--=====================================================================================================
-- Purpose:  Ends a session: a normal logout (@Reason = 'logout') or a forced logout by an admin
--           (any other reason). Safe to call twice: an already revoked session is left alone.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE security.spSession_Revoke
    @ID_Session         BIGINT
  , @Reason             NVARCHAR(200)
  , @ClientIpAddress    VARCHAR(45)     = NULL
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @Now        DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @ID_User    INT          = (
        SELECT ID_User
        FROM security.Session
        WHERE ID = @ID_Session
        AND RevokedDate IS NULL
    );

    -- unknown or already revoked: nothing to do
    IF @ID_User IS NULL BEGIN
        RETURN;
    END

    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    UPDATE security.Session
    SET
        RevokedDate   = @Now
      , RevokedReason = @Reason
    WHERE
        ID = @ID_Session;

    INSERT INTO security.Audit_Log (
        EventType
      , ID_User
      , ID_Session
      , ClientIpAddress
      , Details
    )
    VALUES (
        IIF(@Reason = N'logout', N'Logout', N'SessionRevoked')
      , @ID_User
      , @ID_Session
      , @ClientIpAddress
      , @Reason
    );

    COMMIT TRANSACTION;
END
GO