--=====================================================================================================
--                                        Security spUser_LoginFailed
--=====================================================================================================
-- Purpose:  Records a failed login. Locks the account for 15 minutes after 5 failures.
--           When a lock has expired, counting starts over at 1, so one typo after a lock
--           doesn't lock the account again. Unknown usernames are logged with ID_User null.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE security.spUser_LoginFailed
    @Username           NVARCHAR(100)
  , @ClientIpAddress    VARCHAR(45)     = NULL
AS BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @MaxFailedLogins    INT          = 5;
    DECLARE @LockoutMinutes     INT          = 15;
    DECLARE @Now                DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @ID_User            INT;
    DECLARE @NewFailedCount     INT;
    DECLARE @IsNowLocked        BIT          = 0;

    BEGIN TRANSACTION;

    -- lock the user row so two failed attempts at the same moment can't both read the old count
    SELECT
        @ID_User        = users.ID
      , @NewFailedCount = CASE
                              WHEN users.LockedUntil IS NOT NULL AND users.LockedUntil <= @Now
                                  THEN 1
                              ELSE users.FailedLoginCount + 1
                          END
    FROM
        security.[User] users WITH (UPDLOCK, HOLDLOCK)
    WHERE
        users.Username = @Username
    AND users.Active = 1
    AND users.Deleted = 0;

    IF @ID_User IS NOT NULL BEGIN
        SET @IsNowLocked = IIF(@NewFailedCount >= @MaxFailedLogins, 1, 0);

        UPDATE security.[User]
        SET
            FailedLoginCount = @NewFailedCount
          , LockedUntil      = CASE
                                   WHEN @IsNowLocked = 1
                                       THEN DATEADD(MINUTE, @LockoutMinutes, @Now)
                                   ELSE NULL
                               END
        WHERE
            ID = @ID_User;
    END

    INSERT INTO security.Audit_Log (
        EventType
      , ID_User
      , Username
      , ClientIpAddress
      , Details
    )
    VALUES (
        IIF(@IsNowLocked = 1, N'LoginLocked', N'LoginFailed')
      , @ID_User
      , @Username
      , @ClientIpAddress
      , CASE
            WHEN @ID_User IS NULL
                THEN N'unknown username'
            ELSE CONCAT(N'failed attempt ', @NewFailedCount, N' of ', @MaxFailedLogins)
        END
    );

    COMMIT TRANSACTION;
END
GO