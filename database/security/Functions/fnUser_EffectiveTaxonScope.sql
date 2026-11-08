--=====================================================================================================
--                                        Security fnUser_EffectiveTaxonScope
--=====================================================================================================
-- Purpose:  Every taxon subtree a user can see at a point in time: scope given directly to the
--           user, plus scope given to any group the user belongs to or to any group above those.
--           No rows means no data (default deny).
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the function.
--=====================================================================================================
CREATE FUNCTION security.fnUser_EffectiveTaxonScope (
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
-- scope given directly to the user
SELECT
    user_scopes.ID_Taxon
FROM
    security.User_TaxonScope user_scopes
INNER JOIN
    active_user
    ON user_scopes.ID_User = active_user.ID
WHERE
    user_scopes.StartDate <= @AsOfDate
AND (user_scopes.EndDate IS NULL OR user_scopes.EndDate > @AsOfDate)

UNION

-- scope given to the user's groups or to any group above them
SELECT
    group_scopes.ID_Taxon
FROM
    security.Group_TaxonScope group_scopes
INNER JOIN
    security.[Group] scope_group
    ON group_scopes.ID_Group = scope_group.ID
INNER JOIN
    member_groups
    ON member_groups.Path = scope_group.Path
    OR member_groups.Path LIKE scope_group.Path + ',%'
WHERE
    group_scopes.StartDate <= @AsOfDate
AND (group_scopes.EndDate IS NULL OR group_scopes.EndDate > @AsOfDate)
AND scope_group.Active = 1
AND scope_group.Deleted = 0;
GO