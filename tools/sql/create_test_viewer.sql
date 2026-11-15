-- creates or resets e2e.viewer, a test account for the ui tests: Viewer role, scope Amphibia only.
-- run only against inat_test_copy (tools/run_ui_tests.ps1 does this). the password hash comes from the
-- ViewerPasswordHash environment variable. safe to run again: it resets the password and any lockout.
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @ID_User        INT = (SELECT ID FROM security.[User] WHERE Username = N'e2e.viewer');
DECLARE @ViewerRoleID   INT = (SELECT ID FROM security.Role WHERE Name = N'Viewer');
DECLARE @AmphibiaID     INT = 20978;

IF @ID_User IS NULL BEGIN
    INSERT INTO security.[User] (
        FirstName
      , LastName
      , Username
      , Email
      , PasswordHash
      , HasChangedPassword
      , ID_CreatedBy
    )
    VALUES (
        N'E2E'
      , N'Viewer'
      , N'e2e.viewer'
      , N'e2e.viewer@example.com'
      , N'$(ViewerPasswordHash)'
      , 1
      , 1
    );

    SET @ID_User = SCOPE_IDENTITY();
    EXEC security.spTreeNode_SetPath @TableName = N'User', @ID = @ID_User;
END
ELSE BEGIN
    UPDATE security.[User]
    SET
        PasswordHash     = N'$(ViewerPasswordHash)'
      , FailedLoginCount = 0
      , LockedUntil      = NULL
      , ID_UpdatedBy     = 1
      , UpdatedDate      = SYSUTCDATETIME()
    WHERE
        ID = @ID_User;
END

IF NOT EXISTS (
    SELECT 1
    FROM security.User_Role
    WHERE ID_User = @ID_User
    AND ID_Role = @ViewerRoleID
    AND EndDate IS NULL
) BEGIN
    INSERT INTO security.User_Role (ID_User, ID_Role, ID_CreatedBy) VALUES (@ID_User, @ViewerRoleID, 1);
END

IF NOT EXISTS (
    SELECT 1
    FROM security.User_TaxonScope
    WHERE ID_User = @ID_User
    AND ID_Taxon = @AmphibiaID
    AND EndDate IS NULL
) BEGIN
    INSERT INTO security.User_TaxonScope (ID_User, ID_Taxon, ID_CreatedBy) VALUES (@ID_User, @AmphibiaID, 1);
END

PRINT 'e2e.viewer is ready';