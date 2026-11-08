-- tests refresh, revoke and the access check inside a transaction that is rolled back at the end.
-- covers: allowed and denied access, token rotation, reuse of a replaced token (theft detection),
-- logout, double logout, and refreshing after logout.
USE inat;
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

BEGIN TRANSACTION;

DECLARE @OrganizationTypeID INT = (SELECT ID FROM security.GroupType    WHERE Name = N'Organization');
DECLARE @PageTypeID         INT = (SELECT ID FROM security.ResourceType WHERE Name = N'Page');
DECLARE @ViewerRoleID       INT = (SELECT ID FROM security.Role         WHERE Name = N'Viewer');
DECLARE @PandaID            INT;
DECLARE @MariaID            INT;
DECLARE @TaxonomyPageID     INT;
DECLARE @ViewTaxonomyID     INT;
DECLARE @ID_Session         BIGINT;
DECLARE @SecondSessionID    BIGINT;
DECLARE @RefreshedSessionID BIGINT;
DECLARE @ID_User            INT;
DECLARE @Result             NVARCHAR(20);
DECLARE @TokenA             VARBINARY(32) = HASHBYTES('SHA2_256', 'test token a');
DECLARE @TokenB             VARBINARY(32) = HASHBYTES('SHA2_256', 'test token b');
DECLARE @TokenC             VARBINARY(32) = HASHBYTES('SHA2_256', 'test token c');
DECLARE @TokenD             VARBINARY(32) = HASHBYTES('SHA2_256', 'test token d');

-- setup: Panda with the Viewer role (taxonomy.view), Maria as a member
INSERT INTO security.[Group] (ID_Parent, ID_GroupType, Name, ID_CreatedBy) VALUES (NULL, @OrganizationTypeID, N'Panda', 1);
SET @PandaID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Group', @ID = @PandaID;

INSERT INTO security.[User] (FirstName, LastName, Username, Email, PasswordHash, ID_CreatedBy)
VALUES (N'Maria', N'Santos', N'maria', N'maria@example.com', N'test-hash-not-real', 1);
SET @MariaID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'User', @ID = @MariaID;

INSERT INTO security.User_Group (ID_User, ID_Group, ID_CreatedBy) VALUES (@MariaID, @PandaID, 1);

INSERT INTO security.Resource (ID_Parent, ID_ResourceType, Code, Name, ID_CreatedBy) VALUES (NULL, @PageTypeID, N'page.taxonomy', N'Taxonomy tree', 1);
SET @TaxonomyPageID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Resource', @ID = @TaxonomyPageID;

INSERT INTO security.Permission (ID_Resource, Action, Code, ID_CreatedBy) VALUES (@TaxonomyPageID, N'view', N'taxonomy.view', 1);
SET @ViewTaxonomyID = SCOPE_IDENTITY();

INSERT INTO security.Role_Permission (ID_Role, ID_Permission, ID_CreatedBy) VALUES (@ViewerRoleID, @ViewTaxonomyID, 1);
INSERT INTO security.Group_Role (ID_Group, ID_Role, ID_CreatedBy) VALUES (@PandaID, @ViewerRoleID, 1);

-- login with token A
EXEC security.spSession_Create
    @ID_User     = @MariaID
  , @TokenHash   = @TokenA
  , @ExpiresDate = '2099-01-01'
  , @ID_Session  = @ID_Session OUTPUT;

PRINT '--- 1. access to taxonomy.view (expect allowed)';
EXEC security.spSession_CheckAccess
    @ID_Session     = @ID_Session
  , @PermissionCode = N'taxonomy.view'
  , @ID_User        = @ID_User OUTPUT;
PRINT CONCAT('--- allowed for user ', @ID_User);

PRINT '--- 2. access to admin.users.manage (expect denied)';
BEGIN TRY
    EXEC security.spSession_CheckAccess
        @ID_Session     = @ID_Session
      , @PermissionCode = N'admin.users.manage'
      , @ID_User        = @ID_User OUTPUT;
    PRINT '--- FAILED: access was allowed';
END TRY
BEGIN CATCH
    PRINT '--- correctly denied: ' + ERROR_MESSAGE();
END CATCH

PRINT '--- 3. refresh token A to token B (expect ok)';
EXEC security.spSession_Refresh
    @OldTokenHash   = @TokenA
  , @NewTokenHash   = @TokenB
  , @NewExpiresDate = '2099-01-02'
  , @Result         = @Result OUTPUT
  , @ID_Session     = @RefreshedSessionID OUTPUT;
PRINT CONCAT('--- result: ', @Result);

PRINT '--- 4. use token A again, it was replaced (expect reused, session revoked)';
EXEC security.spSession_Refresh
    @OldTokenHash   = @TokenA
  , @NewTokenHash   = @TokenC
  , @NewExpiresDate = '2099-01-03'
  , @Result         = @Result OUTPUT
  , @ID_Session     = @RefreshedSessionID OUTPUT;
PRINT CONCAT('--- result: ', @Result);

PRINT '--- 5. access with the revoked session (expect denied)';
BEGIN TRY
    EXEC security.spSession_CheckAccess
        @ID_Session     = @ID_Session
      , @PermissionCode = N'taxonomy.view'
      , @ID_User        = @ID_User OUTPUT;
    PRINT '--- FAILED: access was allowed';
END TRY
BEGIN CATCH
    PRINT '--- correctly denied: ' + ERROR_MESSAGE();
END CATCH

-- a fresh login with token C, then logout twice
EXEC security.spSession_Create
    @ID_User     = @MariaID
  , @TokenHash   = @TokenC
  , @ExpiresDate = '2099-01-01'
  , @ID_Session  = @SecondSessionID OUTPUT;

EXEC security.spSession_Revoke @ID_Session = @SecondSessionID, @Reason = N'logout';
EXEC security.spSession_Revoke @ID_Session = @SecondSessionID, @Reason = N'logout';

PRINT '--- 6. refresh after logout (expect invalid)';
EXEC security.spSession_Refresh
    @OldTokenHash   = @TokenC
  , @NewTokenHash   = @TokenD
  , @NewExpiresDate = '2099-01-03'
  , @Result         = @Result OUTPUT
  , @ID_Session     = @RefreshedSessionID OUTPUT;
PRINT CONCAT('--- result: ', @Result);

PRINT '--- 7. audit log (expect LoginSucceeded, AccessDenied, SessionRefreshed, SessionRevoked, AccessDenied, LoginSucceeded, one Logout)';
SELECT
    EventType
  , ResourceCode
  , Details
FROM
    security.Audit_Log
ORDER BY
    ID;

ROLLBACK TRANSACTION;