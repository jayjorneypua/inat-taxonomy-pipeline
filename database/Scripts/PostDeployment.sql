--=====================================================================================================
--                                        Post Deployment Seed Data
--=====================================================================================================
-- Purpose:  Runs after every publish. Every insert checks first, so reruns never duplicate.
-- History:
-- 2026-11-08  Jay Jorney Pua          System user and group types.
-- 2026-11-08  Jay Jorney Pua          Resource types and roles.
--=====================================================================================================

------------------------------------------------------------------------------------
-- System user: a real account for automated actions, cannot log in (no password hash)
------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM security.[User] WHERE ID = 1) BEGIN
    SET IDENTITY_INSERT security.[User] ON;

    INSERT INTO security.[User] (
        ID
      , FirstName
      , LastName
      , Username
      , Email
      , PasswordHash
      , HasChangedPassword
      , Path
      , Level
      , ID_CreatedBy
    )
    VALUES (
        1
      , N'System'
      , N'Account'
      , N'system'
      , N'system@inat.local'
      , NULL
      , 1
      , '1'
      , 1
      , 1
    );

    SET IDENTITY_INSERT security.[User] OFF;
END

------------------------------------------------------------------------------------
-- Group types
------------------------------------------------------------------------------------
INSERT INTO security.GroupType (
    Name
  , Description
  , DisplayOrder
  , ID_CreatedBy
)
SELECT
    seed_types.Name
  , seed_types.Description
  , seed_types.DisplayOrder
  , 1
FROM (
    VALUES
        (N'Organization', N'Top level tenant, every other group sits under one',   1)
      , (N'Department',   N'Functional unit inside an organization',               2)
      , (N'Location',     N'Physical site or region',                              3)
      , (N'Team',         N'Working group',                                        4)
) seed_types (Name, Description, DisplayOrder)
WHERE
    NOT EXISTS (
        SELECT 1
        FROM security.GroupType existing_types
        WHERE existing_types.Name = seed_types.Name
    );

------------------------------------------------------------------------------------
-- Resource types
------------------------------------------------------------------------------------
INSERT INTO security.ResourceType (
    Name
  , Description
  , DisplayOrder
  , ID_CreatedBy
)
SELECT
    seed_types.Name
  , seed_types.Description
  , seed_types.DisplayOrder
  , 1
FROM (
    VALUES
        (N'Page',   N'A screen in the web app',                    1)
      , (N'Button', N'An action inside a page',                    2)
      , (N'Api',    N'An api endpoint',                            3)
) seed_types (Name, Description, DisplayOrder)
WHERE
    NOT EXISTS (
        SELECT 1
        FROM security.ResourceType existing_types
        WHERE existing_types.Name = seed_types.Name
    );

------------------------------------------------------------------------------------
-- Roles
------------------------------------------------------------------------------------
INSERT INTO security.Role (
    Name
  , Description
  , DisplayOrder
  , ID_CreatedBy
)
SELECT
    seed_roles.Name
  , seed_roles.Description
  , seed_roles.DisplayOrder
  , 1
FROM (
    VALUES
        (N'Viewer',        N'Can view dashboards and the taxonomy tree',          1)
      , (N'Analyst',       N'Viewer plus exports and detailed observation data',  2)
      , (N'Administrator', N'Manages users, groups, roles and permissions',       3)
) seed_roles (Name, Description, DisplayOrder)
WHERE
    NOT EXISTS (
        SELECT 1
        FROM security.Role existing_roles
        WHERE existing_roles.Name = seed_roles.Name
    );