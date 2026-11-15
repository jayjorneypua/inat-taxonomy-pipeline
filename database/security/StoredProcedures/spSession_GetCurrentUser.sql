--=====================================================================================================
--                                        Security spSession_GetCurrentUser
--=====================================================================================================
-- Purpose:  Who is logged in and what they may do, so the ui can show or hide pages and buttons.
--           Any valid session may call it. Two result sets: the user, then the session's permission
--           codes, read from the Session_Permission cache filled at login and at each token refresh.
--           Hiding things in the ui is convenience; every procedure still checks access itself.
-- History:
-- 2026-11-15  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE security.spSession_GetCurrentUser
    @ID_Session         BIGINT
  , @ClientIpAddress    VARCHAR(45)     = NULL
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @ID_User INT;

    EXEC security.spSession_CheckAccess
        @ID_Session      = @ID_Session
      , @PermissionCode  = NULL
      , @ClientIpAddress = @ClientIpAddress
      , @ID_User         = @ID_User OUTPUT;

    SELECT
        users.ID
      , users.Username
      , users.FirstName
      , users.LastName
    FROM
        security.[User] users
    WHERE
        users.ID = @ID_User;

    SELECT
        permissions.Code                AS PermissionCode
    FROM
        security.Session_Permission session_permissions
    INNER JOIN
        security.Permission permissions
        ON session_permissions.ID_Permission = permissions.ID
    WHERE
        session_permissions.ID_Session = @ID_Session
    ORDER BY
        permissions.Code;
END
GO