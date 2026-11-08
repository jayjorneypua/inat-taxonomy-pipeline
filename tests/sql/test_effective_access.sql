-- tests effective permissions and scope with sample data inside a transaction that is
-- rolled back at the end, so nothing stays in the database.
--
-- setup: Panda (organization) > Finance (department) > Manila (location)
--        Maria is a member of Manila only
--        Viewer role on Panda          -> Maria inherits it through the tree
--        Analyst role directly on Maria
--        Administrator directly on Maria, but it ended yesterday -> must not count
--        Amphibia scope on Finance     -> Maria inherits it through the tree
USE inat;
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

BEGIN TRANSACTION;

DECLARE @Now                DATETIME2(3) = SYSUTCDATETIME();
DECLARE @OrganizationTypeID INT = (SELECT ID FROM security.GroupType    WHERE Name = N'Organization');
DECLARE @DepartmentTypeID   INT = (SELECT ID FROM security.GroupType    WHERE Name = N'Department');
DECLARE @LocationTypeID     INT = (SELECT ID FROM security.GroupType    WHERE Name = N'Location');
DECLARE @PageTypeID         INT = (SELECT ID FROM security.ResourceType WHERE Name = N'Page');
DECLARE @ButtonTypeID       INT = (SELECT ID FROM security.ResourceType WHERE Name = N'Button');
DECLARE @ViewerRoleID       INT = (SELECT ID FROM security.Role         WHERE Name = N'Viewer');
DECLARE @AnalystRoleID      INT = (SELECT ID FROM security.Role         WHERE Name = N'Analyst');
DECLARE @AdminRoleID        INT = (SELECT ID FROM security.Role         WHERE Name = N'Administrator');
DECLARE @PandaID            INT;
DECLARE @FinanceID          INT;
DECLARE @ManilaID           INT;
DECLARE @MariaID            INT;
DECLARE @TaxonomyPageID     INT;
DECLARE @ObservationsPageID INT;
DECLARE @ExportButtonID     INT;
DECLARE @AdminPageID        INT;
DECLARE @ViewTaxonomyID     INT;
DECLARE @ExportID           INT;
DECLARE @ManageUsersID      INT;

-- groups
INSERT INTO security.[Group] (ID_Parent, ID_GroupType, Name, ID_CreatedBy) VALUES (NULL, @OrganizationTypeID, N'Panda', 1);
SET @PandaID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Group', @ID = @PandaID;

INSERT INTO security.[Group] (ID_Parent, ID_GroupType, Name, ID_CreatedBy) VALUES (@PandaID, @DepartmentTypeID, N'Finance', 1);
SET @FinanceID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Group', @ID = @FinanceID;

INSERT INTO security.[Group] (ID_Parent, ID_GroupType, Name, ID_CreatedBy) VALUES (@FinanceID, @LocationTypeID, N'Manila', 1);
SET @ManilaID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Group', @ID = @ManilaID;

-- user Maria, member of Manila only
INSERT INTO security.[User] (FirstName, LastName, Username, Email, ID_CreatedBy) VALUES (N'Maria', N'Santos', N'maria', N'maria@example.com', 1);
SET @MariaID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'User', @ID = @MariaID;

INSERT INTO security.User_Group (ID_User, ID_Group, ID_CreatedBy) VALUES (@MariaID, @ManilaID, 1);

-- resources: two pages, an export button inside the observations page, an admin page
INSERT INTO security.Resource (ID_Parent, ID_ResourceType, Code, Name, ID_CreatedBy) VALUES (NULL, @PageTypeID, N'page.taxonomy', N'Taxonomy tree', 1);
SET @TaxonomyPageID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Resource', @ID = @TaxonomyPageID;

INSERT INTO security.Resource (ID_Parent, ID_ResourceType, Code, Name, ID_CreatedBy) VALUES (NULL, @PageTypeID, N'page.observations', N'Observations', 1);
SET @ObservationsPageID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Resource', @ID = @ObservationsPageID;

INSERT INTO security.Resource (ID_Parent, ID_ResourceType, Code, Name, ID_CreatedBy) VALUES (@ObservationsPageID, @ButtonTypeID, N'button.observations.export', N'Export observations', 1);
SET @ExportButtonID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Resource', @ID = @ExportButtonID;

INSERT INTO security.Resource (ID_Parent, ID_ResourceType, Code, Name, ID_CreatedBy) VALUES (NULL, @PageTypeID, N'page.admin', N'Administration', 1);
SET @AdminPageID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Resource', @ID = @AdminPageID;

-- permissions
INSERT INTO security.Permission (ID_Resource, Action, Code, ID_CreatedBy) VALUES (@TaxonomyPageID, N'view', N'taxonomy.view', 1);
SET @ViewTaxonomyID = SCOPE_IDENTITY();

INSERT INTO security.Permission (ID_Resource, Action, Code, ID_CreatedBy) VALUES (@ExportButtonID, N'execute', N'observations.export', 1);
SET @ExportID = SCOPE_IDENTITY();

INSERT INTO security.Permission (ID_Resource, Action, Code, ID_CreatedBy) VALUES (@AdminPageID, N'manage', N'admin.users.manage', 1);
SET @ManageUsersID = SCOPE_IDENTITY();

-- what each role can do
INSERT INTO security.Role_Permission (ID_Role, ID_Permission, ID_CreatedBy) VALUES (@ViewerRoleID,  @ViewTaxonomyID, 1);
INSERT INTO security.Role_Permission (ID_Role, ID_Permission, ID_CreatedBy) VALUES (@AnalystRoleID, @ExportID,       1);
INSERT INTO security.Role_Permission (ID_Role, ID_Permission, ID_CreatedBy) VALUES (@AdminRoleID,   @ManageUsersID,  1);

-- role assignments
INSERT INTO security.Group_Role (ID_Group, ID_Role, ID_CreatedBy) VALUES (@PandaID, @ViewerRoleID, 1);
INSERT INTO security.User_Role  (ID_User, ID_Role, ID_CreatedBy) VALUES (@MariaID, @AnalystRoleID, 1);
INSERT INTO security.User_Role  (ID_User, ID_Role, StartDate, EndDate, ID_CreatedBy)
VALUES (@MariaID, @AdminRoleID, DATEADD(DAY, -7, @Now), DATEADD(DAY, -1, @Now), 1);

-- data scope: Amphibia (20978) on Finance
INSERT INTO security.Group_TaxonScope (ID_Group, ID_Taxon, ID_CreatedBy) VALUES (@FinanceID, 20978, 1);

SET @Now = SYSUTCDATETIME();

PRINT '--- Maria''s effective permissions (expect taxonomy.view and observations.export, NOT admin.users.manage)';
SELECT
    PermissionCode
FROM
    security.fnUser_EffectivePermission(@MariaID, @Now)
ORDER BY
    PermissionCode;

PRINT '--- Maria''s permissions 3 days ago (expect only admin.users.manage: it was valid then, Viewer and Analyst were assigned today)';
SELECT
    PermissionCode
FROM
    security.fnUser_EffectivePermission(@MariaID, DATEADD(DAY, -3, @Now))
ORDER BY
    PermissionCode;

PRINT '--- Maria''s effective scope (expect 20978, inherited from Finance)';
SELECT
    ID_Taxon
FROM
    security.fnUser_EffectiveTaxonScope(@MariaID, @Now);

-- move Maria out of Manila: closing the membership must remove the inherited role and scope
UPDATE security.User_Group
SET
    EndDate      = DATEADD(SECOND, 1, @Now)
  , ID_UpdatedBy = 1
  , UpdatedDate  = @Now
WHERE
    ID_User = @MariaID
AND ID_Group = @ManilaID;

PRINT '--- after leaving Manila (expect only observations.export, her direct role)';
SELECT
    PermissionCode
FROM
    security.fnUser_EffectivePermission(@MariaID, DATEADD(SECOND, 2, @Now))
ORDER BY
    PermissionCode;

PRINT '--- scope after leaving Manila (expect no rows: default deny)';
SELECT
    ID_Taxon
FROM
    security.fnUser_EffectiveTaxonScope(@MariaID, DATEADD(SECOND, 2, @Now));

ROLLBACK TRANSACTION;