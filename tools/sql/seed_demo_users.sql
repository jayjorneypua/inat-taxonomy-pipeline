-- development only: 30 demo users across three groups, so the admin grid has rows to page through.
-- their password hash is a placeholder that never verifies, so nobody can log in as them.
-- safe to run again: existing groups, users, memberships and roles are skipped.
USE inat;
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @OrganizationTypeID INT = (SELECT ID FROM security.GroupType WHERE Name = N'Organization');
DECLARE @ViewerRoleID       INT = (SELECT ID FROM security.Role      WHERE Name = N'Viewer');
DECLARE @AnalystRoleID      INT = (SELECT ID FROM security.Role      WHERE Name = N'Analyst');

-- groups
INSERT INTO security.[Group] (
    ID_GroupType
  , Name
  , ID_CreatedBy
)
SELECT
    @OrganizationTypeID
  , demo_groups.Name
  , 1
FROM (
    VALUES
        (N'Herp Team')
      , (N'Bird Survey')
      , (N'Botany Lab')
) demo_groups (Name)
WHERE
    NOT EXISTS (
        SELECT 1
        FROM security.[Group] existing_groups
        WHERE existing_groups.Name = demo_groups.Name
    );

-- 30 users: every 7th is locked, every 9th is inactive
WITH user_numbers AS (
    SELECT TOP (30)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS UserNumber
    FROM
        sys.all_objects
)
, demo_users AS (
    SELECT
        user_numbers.UserNumber
      , CHOOSE(user_numbers.UserNumber % 10 + 1, N'Ana', N'Ben', N'Carla', N'Diego', N'Ella', N'Felix', N'Grace', N'Hugo', N'Iris', N'Jonas') AS FirstName
      , CHOOSE(user_numbers.UserNumber % 7 + 1, N'Reyes', N'Santos', N'Cruz', N'Garcia', N'Lim', N'Tan', N'Bautista')                     AS LastName
    FROM
        user_numbers
)
INSERT INTO security.[User] (
    FirstName
  , LastName
  , Username
  , Email
  , PasswordHash
  , Active
  , LockedUntil
  , ID_CreatedBy
)
SELECT
    demo_users.FirstName
  , demo_users.LastName
  , CONCAT(N'demo.', LOWER(demo_users.FirstName), FORMAT(demo_users.UserNumber, '00'))
  , CONCAT(N'demo.', LOWER(demo_users.FirstName), FORMAT(demo_users.UserNumber, '00'), N'@example.com')
  , N'demo-account-cannot-log-in'
  , CASE WHEN demo_users.UserNumber % 9 = 0 THEN 0 ELSE 1 END
  , CASE WHEN demo_users.UserNumber % 7 = 0 THEN DATEADD(YEAR, 1, SYSUTCDATETIME()) END
  , 1
FROM
    demo_users
WHERE
    NOT EXISTS (
        SELECT 1
        FROM security.[User] existing_users
        WHERE existing_users.Username = CONCAT(N'demo.', LOWER(demo_users.FirstName), FORMAT(demo_users.UserNumber, '00'))
    );

-- memberships: one group each, by number
INSERT INTO security.User_Group (
    ID_User
  , ID_Group
  , ID_CreatedBy
)
SELECT
    users.ID
  , member_groups.ID
  , 1
FROM
    security.[User] users
INNER JOIN
    security.[Group] member_groups
    ON member_groups.Name = CHOOSE(CAST(RIGHT(users.Username, 2) AS INT) % 3 + 1, N'Herp Team', N'Bird Survey', N'Botany Lab')
WHERE
    users.Username LIKE N'demo.%'
AND NOT EXISTS (
        SELECT 1
        FROM security.User_Group existing_memberships
        WHERE existing_memberships.ID_User = users.ID
        AND existing_memberships.EndDate IS NULL
    );

-- roles: every 4th is an Analyst, the rest Viewers
INSERT INTO security.User_Role (
    ID_User
  , ID_Role
  , ID_CreatedBy
)
SELECT
    users.ID
  , CASE WHEN CAST(RIGHT(users.Username, 2) AS INT) % 4 = 0 THEN @AnalystRoleID ELSE @ViewerRoleID END
  , 1
FROM
    security.[User] users
WHERE
    users.Username LIKE N'demo.%'
AND NOT EXISTS (
        SELECT 1
        FROM security.User_Role existing_roles
        WHERE existing_roles.ID_User = users.ID
        AND existing_roles.EndDate IS NULL
    );

SELECT
    COUNT(*) AS demo_user_count
FROM
    security.[User]
WHERE
    Username LIKE N'demo.%';