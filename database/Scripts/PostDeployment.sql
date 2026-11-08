--=====================================================================================================
--                                        Post Deployment Seed Data
--=====================================================================================================
-- Purpose:  Runs after every publish. Every insert checks first, so reruns never duplicate.
-- History:
-- 2026-11-08  Jay Jorney Pua          System user and group types.
-- 2026-11-08  Jay Jorney Pua          Resource types and roles.
-- 2026-11-08  Jay Jorney Pua          App resources, permissions and what each role can do.
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

------------------------------------------------------------------------------------
-- App resources: pages first, then the buttons inside them
------------------------------------------------------------------------------------
INSERT INTO security.Resource (
    ID_Parent
  , ID_ResourceType
  , Code
  , Name
  , DisplayOrder
  , ID_CreatedBy
)
SELECT
    NULL
  , resource_types.ID
  , seed_pages.Code
  , seed_pages.Name
  , seed_pages.DisplayOrder
  , 1
FROM (
    VALUES
        (N'page.dashboard', N'Dashboard',      1)
      , (N'page.taxonomy',  N'Taxonomy tree',  2)
      , (N'page.admin',     N'Administration', 3)
) seed_pages (Code, Name, DisplayOrder)
INNER JOIN
    security.ResourceType resource_types
    ON resource_types.Name = N'Page'
WHERE
    NOT EXISTS (
        SELECT 1
        FROM security.Resource existing_resources
        WHERE existing_resources.Code = seed_pages.Code
    );

INSERT INTO security.Resource (
    ID_Parent
  , ID_ResourceType
  , Code
  , Name
  , DisplayOrder
  , ID_CreatedBy
)
SELECT
    parent_pages.ID
  , resource_types.ID
  , seed_buttons.Code
  , seed_buttons.Name
  , seed_buttons.DisplayOrder
  , 1
FROM (
    VALUES
        (N'button.observations.export', N'Export observations', N'page.dashboard', 1)
) seed_buttons (Code, Name, ParentCode, DisplayOrder)
INNER JOIN
    security.Resource parent_pages
    ON parent_pages.Code = seed_buttons.ParentCode
INNER JOIN
    security.ResourceType resource_types
    ON resource_types.Name = N'Button'
WHERE
    NOT EXISTS (
        SELECT 1
        FROM security.Resource existing_resources
        WHERE existing_resources.Code = seed_buttons.Code
    );

-- set Path and Level for any resource that doesn't have one yet, parents have lower ids
DECLARE @ResourceWithoutPathID INT = (SELECT MIN(ID) FROM security.Resource WHERE Path IS NULL);

WHILE @ResourceWithoutPathID IS NOT NULL BEGIN
    EXEC security.spTreeNode_SetPath @TableName = N'Resource', @ID = @ResourceWithoutPathID;
    SET @ResourceWithoutPathID = (SELECT MIN(ID) FROM security.Resource WHERE Path IS NULL);
END

------------------------------------------------------------------------------------
-- Permissions
------------------------------------------------------------------------------------
INSERT INTO security.Permission (
    ID_Resource
  , Action
  , Code
  , Description
  , ID_CreatedBy
)
SELECT
    resources.ID
  , seed_permissions.Action
  , seed_permissions.Code
  , seed_permissions.Description
  , 1
FROM (
    VALUES
        (N'page.dashboard',             N'view',    N'dashboard.view',      N'Open the dashboard')
      , (N'page.taxonomy',              N'view',    N'taxonomy.view',       N'Open the taxonomy tree')
      , (N'button.observations.export', N'execute', N'observations.export', N'Export observations')
      , (N'page.admin',                 N'manage',  N'admin.users.manage',  N'Manage users, groups and roles')
) seed_permissions (ResourceCode, Action, Code, Description)
INNER JOIN
    security.Resource resources
    ON resources.Code = seed_permissions.ResourceCode
WHERE
    NOT EXISTS (
        SELECT 1
        FROM security.Permission existing_permissions
        WHERE existing_permissions.Code = seed_permissions.Code
    );

------------------------------------------------------------------------------------
-- What each role can do
------------------------------------------------------------------------------------
INSERT INTO security.Role_Permission (
    ID_Role
  , ID_Permission
  , ID_CreatedBy
)
SELECT
    roles.ID
  , permissions.ID
  , 1
FROM (
    VALUES
        (N'Viewer',        N'dashboard.view')
      , (N'Viewer',        N'taxonomy.view')
      , (N'Analyst',       N'dashboard.view')
      , (N'Analyst',       N'taxonomy.view')
      , (N'Analyst',       N'observations.export')
      , (N'Administrator', N'dashboard.view')
      , (N'Administrator', N'taxonomy.view')
      , (N'Administrator', N'observations.export')
      , (N'Administrator', N'admin.users.manage')
) seed_grants (RoleName, PermissionCode)
INNER JOIN
    security.Role roles
    ON roles.Name = seed_grants.RoleName
INNER JOIN
    security.Permission permissions
    ON permissions.Code = seed_grants.PermissionCode
WHERE
    NOT EXISTS (
        SELECT 1
        FROM security.Role_Permission existing_grants
        WHERE existing_grants.ID_Role = roles.ID
        AND existing_grants.ID_Permission = permissions.ID
    );