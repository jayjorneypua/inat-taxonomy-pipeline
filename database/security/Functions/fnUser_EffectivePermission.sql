--=====================================================================================================
--                                        Security fnUser_EffectivePermission
--=====================================================================================================
-- Purpose:  Everything a user can do at a point in time: roles given directly to the user,
--           plus roles given to any group the user belongs to or to any group above those
--           (found through Path). Only active rows and assignments valid at @AsOfDate count.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the function.
--=====================================================================================================
CREATE FUNCTION security.fnUser_EffectivePermission (
    @ID_User            INT
  , @AsOfDate           DATETIME2(3)
)
RETURNS TABLE
AS
RETURN
WITH active_user AS (
    SELECT
        users.ID
    FROM
        security.[User] users
    WHERE
        users.ID = @ID_User
    AND users.Active = 1
    AND users.Deleted = 0
)
, member_groups AS (
    SELECT
        member_group.Path
    FROM
        security.User_Group memberships
    INNER JOIN
        active_user
        ON memberships.ID_User = active_user.ID
    INNER JOIN
        security.[Group] member_group
        ON memberships.ID_Group = member_group.ID
    WHERE
        memberships.StartDate <= @AsOfDate
    AND (memberships.EndDate IS NULL OR memberships.EndDate > @AsOfDate)
    AND member_group.Active = 1
    AND member_group.Deleted = 0
)
, effective_roles AS (
    -- roles given directly to the user
    SELECT
        user_roles.ID_Role
    FROM
        security.User_Role user_roles
    INNER JOIN
        active_user
        ON user_roles.ID_User = active_user.ID
    WHERE
        user_roles.StartDate <= @AsOfDate
    AND (user_roles.EndDate IS NULL OR user_roles.EndDate > @AsOfDate)

    UNION

    -- roles given to the user's groups or to any group above them
    SELECT
        group_roles.ID_Role
    FROM
        security.Group_Role group_roles
    INNER JOIN
        security.[Group] role_group
        ON group_roles.ID_Group = role_group.ID
    INNER JOIN
        member_groups
        ON member_groups.Path = role_group.Path
        OR member_groups.Path LIKE role_group.Path + ',%'
    WHERE
        group_roles.StartDate <= @AsOfDate
    AND (group_roles.EndDate IS NULL OR group_roles.EndDate > @AsOfDate)
    AND role_group.Active = 1
    AND role_group.Deleted = 0
)
SELECT DISTINCT
    permissions.ID                  AS ID_Permission
  , permissions.Code                AS PermissionCode
FROM
    effective_roles
INNER JOIN
    security.Role roles
    ON effective_roles.ID_Role = roles.ID
INNER JOIN
    security.Role_Permission role_permissions
    ON roles.ID = role_permissions.ID_Role
INNER JOIN
    security.Permission permissions
    ON role_permissions.ID_Permission = permissions.ID
INNER JOIN
    security.Resource resources
    ON permissions.ID_Resource = resources.ID
WHERE
    roles.Active = 1
AND roles.Deleted = 0
AND permissions.Active = 1
AND permissions.Deleted = 0
AND resources.Active = 1
AND resources.Deleted = 0;
GO