-- tests effective permissions and scope inside a transaction that is rolled back at the end.
-- runs on inat_test_empty: seeded roles and permissions, no other data.
--
-- setup: Panda (organization) > Finance (department) > Manila (location)
--        Maria is a member of Manila only
--        Viewer role on Panda         -> Maria inherits it through the tree (dashboard.view, taxonomy.view)
--        Analyst directly on Maria, starting tomorrow -> not counted until then
--        Administrator directly on Maria, ended yesterday -> only counted in the past
--        Amphibia scope on Finance    -> Maria inherits it through the tree
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

BEGIN TRANSACTION;

DECLARE @Now                DATETIME2(3);
DECLARE @OrganizationTypeID INT = (SELECT ID FROM security.GroupType WHERE Name = N'Organization');
DECLARE @DepartmentTypeID   INT = (SELECT ID FROM security.GroupType WHERE Name = N'Department');
DECLARE @LocationTypeID     INT = (SELECT ID FROM security.GroupType WHERE Name = N'Location');
DECLARE @ViewerRoleID       INT = (SELECT ID FROM security.Role      WHERE Name = N'Viewer');
DECLARE @AnalystRoleID      INT = (SELECT ID FROM security.Role      WHERE Name = N'Analyst');
DECLARE @AdminRoleID        INT = (SELECT ID FROM security.Role      WHERE Name = N'Administrator');
DECLARE @PandaID            INT;
DECLARE @FinanceID          INT;
DECLARE @ManilaID           INT;
DECLARE @MariaID            INT;
DECLARE @Actual             NVARCHAR(400);

-- the scope needs a real taxon to point at
INSERT INTO dbo.Taxon (ID, ID_Parent, ScientificName, Rank, Path, Level, IsInTree) VALUES (48460, NULL,  N'Life',     N'stateofmatter', '48460',       1, 1);
INSERT INTO dbo.Taxon (ID, ID_Parent, ScientificName, Rank, Path, Level, IsInTree) VALUES (20978, 48460, N'Amphibia', N'class',         '48460,20978', 2, 1);

INSERT INTO security.[Group] (ID_Parent, ID_GroupType, Name, ID_CreatedBy) VALUES (NULL, @OrganizationTypeID, N'Panda', 1);
SET @PandaID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Group', @ID = @PandaID;

INSERT INTO security.[Group] (ID_Parent, ID_GroupType, Name, ID_CreatedBy) VALUES (@PandaID, @DepartmentTypeID, N'Finance', 1);
SET @FinanceID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Group', @ID = @FinanceID;

INSERT INTO security.[Group] (ID_Parent, ID_GroupType, Name, ID_CreatedBy) VALUES (@FinanceID, @LocationTypeID, N'Manila', 1);
SET @ManilaID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Group', @ID = @ManilaID;

INSERT INTO security.[User] (FirstName, LastName, Username, Email, ID_CreatedBy) VALUES (N'Maria', N'Santos', N'maria', N'maria@example.com', 1);
SET @MariaID = SCOPE_IDENTITY();

INSERT INTO security.User_Group (ID_User, ID_Group, ID_CreatedBy) VALUES (@MariaID, @ManilaID, 1);
INSERT INTO security.Group_Role (ID_Group, ID_Role, ID_CreatedBy) VALUES (@PandaID, @ViewerRoleID, 1);
INSERT INTO security.User_Role (ID_User, ID_Role, StartDate, ID_CreatedBy) VALUES (@MariaID, @AnalystRoleID, DATEADD(DAY, 1, SYSUTCDATETIME()), 1);
INSERT INTO security.User_Role (ID_User, ID_Role, StartDate, EndDate, ID_CreatedBy)
VALUES (@MariaID, @AdminRoleID, DATEADD(DAY, -7, SYSUTCDATETIME()), DATEADD(DAY, -1, SYSUTCDATETIME()), 1);
INSERT INTO security.Group_TaxonScope (ID_Group, ID_Taxon, ID_CreatedBy) VALUES (@FinanceID, 20978, 1);

-- "now" is taken after the setup, so every assignment above has already started
SET @Now = SYSUTCDATETIME();

-- 1. now: only the inherited Viewer role
SET @Actual = (SELECT STRING_AGG(PermissionCode, N',') WITHIN GROUP (ORDER BY PermissionCode) FROM security.fnUser_EffectivePermission(@MariaID, @Now));
IF ISNULL(@Actual, N'') = N'dashboard.view,taxonomy.view' BEGIN PRINT '--- passed 1: permissions now'; END
ELSE BEGIN PRINT CONCAT('--- FAILED 1: permissions now, got ', @Actual); END

-- 2. three days ago: only the Administrator role was valid then
SET @Actual = (SELECT STRING_AGG(PermissionCode, N',') WITHIN GROUP (ORDER BY PermissionCode) FROM security.fnUser_EffectivePermission(@MariaID, DATEADD(DAY, -3, @Now)));
IF ISNULL(@Actual, N'') = N'admin.users.manage,dashboard.view,observations.export,taxonomy.view' BEGIN PRINT '--- passed 2: permissions three days ago'; END
ELSE BEGIN PRINT CONCAT('--- FAILED 2: permissions three days ago, got ', @Actual); END

-- 3. two days from now: the Analyst role has started, so export is added
SET @Actual = (SELECT STRING_AGG(PermissionCode, N',') WITHIN GROUP (ORDER BY PermissionCode) FROM security.fnUser_EffectivePermission(@MariaID, DATEADD(DAY, 2, @Now)));
IF ISNULL(@Actual, N'') = N'dashboard.view,observations.export,taxonomy.view' BEGIN PRINT '--- passed 3: permissions two days from now'; END
ELSE BEGIN PRINT CONCAT('--- FAILED 3: permissions two days from now, got ', @Actual); END

-- 4. scope now: Amphibia, inherited from Finance
SET @Actual = (SELECT STRING_AGG(CAST(ID_Taxon AS NVARCHAR(20)), N',') FROM security.fnUser_EffectiveTaxonScope(@MariaID, @Now));
IF ISNULL(@Actual, N'') = N'20978' BEGIN PRINT '--- passed 4: scope now'; END
ELSE BEGIN PRINT CONCAT('--- FAILED 4: scope now, got ', @Actual); END

-- Maria leaves Manila
UPDATE security.User_Group
SET
    EndDate      = DATEADD(SECOND, 1, @Now)
  , ID_UpdatedBy = 1
  , UpdatedDate  = @Now
WHERE
    ID_User = @MariaID
AND ID_Group = @ManilaID;

-- 5. after leaving: no inherited role, and the Analyst role hasn't started yet
SET @Actual = (SELECT STRING_AGG(PermissionCode, N',') WITHIN GROUP (ORDER BY PermissionCode) FROM security.fnUser_EffectivePermission(@MariaID, DATEADD(SECOND, 2, @Now)));
IF @Actual IS NULL BEGIN PRINT '--- passed 5: no permissions after leaving'; END
ELSE BEGIN PRINT CONCAT('--- FAILED 5: no permissions after leaving, got ', @Actual); END

-- 6. scope after leaving: default deny
SET @Actual = (SELECT STRING_AGG(CAST(ID_Taxon AS NVARCHAR(20)), N',') FROM security.fnUser_EffectiveTaxonScope(@MariaID, DATEADD(SECOND, 2, @Now)));
IF @Actual IS NULL BEGIN PRINT '--- passed 6: no scope after leaving'; END
ELSE BEGIN PRINT CONCAT('--- FAILED 6: no scope after leaving, got ', @Actual); END

ROLLBACK TRANSACTION;