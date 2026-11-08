--=====================================================================================================
--                                        Security spUser_GetLoginInfo
--=====================================================================================================
-- Purpose:  Step 1 of login. Returns what the api needs to verify a password: the hash and the
--           lock status. The only procedure that ever returns PasswordHash. Inactive, deleted
--           and password-less accounts (like System) return no row.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE security.spUser_GetLoginInfo
    @Username           NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @Now DATETIME2(3) = SYSUTCDATETIME();

    SELECT
        users.ID                                                        AS ID_User
      , users.PasswordHash
      , CAST(IIF(users.LockedUntil > @Now, 1, 0) AS BIT)                AS IsLocked
      , users.LockedUntil
      , users.HasChangedPassword
    FROM
        security.[User] users
    WHERE
        users.Username = @Username
    AND users.Active = 1
    AND users.Deleted = 0
    AND users.PasswordHash IS NOT NULL;
END
GO