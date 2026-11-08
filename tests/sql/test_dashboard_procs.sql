-- tests the drill-down proc against the real serving data, inside a transaction rolled back at the end.
-- three users: one scoped to Amphibia with Viewer, one with Viewer but no scope, one with no role.
USE inat;
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

BEGIN TRANSACTION;

DECLARE @OrganizationTypeID INT = (SELECT ID FROM security.GroupType WHERE Name = N'Organization');
DECLARE @ViewerRoleID       INT = (SELECT ID FROM security.Role      WHERE Name = N'Viewer');
DECLARE @HerpTeamID         INT;
DECLARE @NoScopeTeamID      INT;
DECLARE @ScopedUserID       INT;
DECLARE @UnscopedUserID     INT;
DECLARE @NoRoleUserID       INT;
DECLARE @ScopedSessionID    BIGINT;
DECLARE @UnscopedSessionID  BIGINT;
DECLARE @NoRoleSessionID    BIGINT;

-- Herp Team: Viewer role, scope Amphibia (20978)
INSERT INTO security.[Group] (ID_Parent, ID_GroupType, Name, ID_CreatedBy) VALUES (NULL, @OrganizationTypeID, N'Herp Team', 1);
SET @HerpTeamID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Group', @ID = @HerpTeamID;
INSERT INTO security.Group_Role (ID_Group, ID_Role, ID_CreatedBy) VALUES (@HerpTeamID, @ViewerRoleID, 1);
INSERT INTO security.Group_TaxonScope (ID_Group, ID_Taxon, ID_CreatedBy) VALUES (@HerpTeamID, 20978, 1);

-- No Scope Team: Viewer role, no scope at all
INSERT INTO security.[Group] (ID_Parent, ID_GroupType, Name, ID_CreatedBy) VALUES (NULL, @OrganizationTypeID, N'No Scope Team', 1);
SET @NoScopeTeamID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Group', @ID = @NoScopeTeamID;
INSERT INTO security.Group_Role (ID_Group, ID_Role, ID_CreatedBy) VALUES (@NoScopeTeamID, @ViewerRoleID, 1);

-- users
INSERT INTO security.[User] (FirstName, LastName, Username, Email, PasswordHash, ID_CreatedBy) VALUES (N'Herp', N'Tester', N'herp.tester', N'herp@example.com', N'x', 1);
SET @ScopedUserID = SCOPE_IDENTITY();
INSERT INTO security.User_Group (ID_User, ID_Group, ID_CreatedBy) VALUES (@ScopedUserID, @HerpTeamID, 1);

INSERT INTO security.[User] (FirstName, LastName, Username, Email, PasswordHash, ID_CreatedBy) VALUES (N'No', N'Scope', N'no.scope', N'noscope@example.com', N'x', 1);
SET @UnscopedUserID = SCOPE_IDENTITY();
INSERT INTO security.User_Group (ID_User, ID_Group, ID_CreatedBy) VALUES (@UnscopedUserID, @NoScopeTeamID, 1);

INSERT INTO security.[User] (FirstName, LastName, Username, Email, PasswordHash, ID_CreatedBy) VALUES (N'No', N'Role', N'no.role', N'norole@example.com', N'x', 1);
SET @NoRoleUserID = SCOPE_IDENTITY();

-- sessions
EXEC security.spSession_Create @ID_User = @ScopedUserID,   @TokenHash = 0x01, @ExpiresDate = '2099-01-01', @ID_Session = @ScopedSessionID OUTPUT;
EXEC security.spSession_Create @ID_User = @UnscopedUserID, @TokenHash = 0x02, @ExpiresDate = '2099-01-01', @ID_Session = @UnscopedSessionID OUTPUT;
EXEC security.spSession_Create @ID_User = @NoRoleUserID,   @TokenHash = 0x03, @ExpiresDate = '2099-01-01', @ID_Session = @NoRoleSessionID OUTPUT;

PRINT '--- 1. Herp Team at the root (expect only Animalia, with the amphibian count)';
EXEC dbo.spDashboard_TaxonChildrenCounts @ID_Session = @ScopedSessionID;

PRINT '--- 2. Herp Team drilling into Amphibia (expect frogs and salamanders, maybe caecilians)';
EXEC dbo.spDashboard_TaxonChildrenCounts @ID_Session = @ScopedSessionID, @ID_ParentTaxon = 20978;

PRINT '--- 3. Herp Team drilling into Plantae, outside its scope (expect no rows)';
EXEC dbo.spDashboard_TaxonChildrenCounts @ID_Session = @ScopedSessionID, @ID_ParentTaxon = 47126;

PRINT '--- 4. Viewer with no scope at the root (expect no rows: default deny)';
EXEC dbo.spDashboard_TaxonChildrenCounts @ID_Session = @UnscopedSessionID;

PRINT '--- 5. user with no role (expect access denied)';
BEGIN TRY
    EXEC dbo.spDashboard_TaxonChildrenCounts @ID_Session = @NoRoleSessionID;
    PRINT '--- FAILED: access was allowed';
END TRY
BEGIN CATCH
    PRINT '--- correctly denied: ' + ERROR_MESSAGE();
END CATCH

ROLLBACK TRANSACTION;