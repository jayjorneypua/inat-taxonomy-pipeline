-- creates or resets cache.warmer, the account the api's CacheWarmer logs in with: Viewer role,
-- scope on the root of the tree (same as the administrator), so its cache keys match full-scope users.
-- the password hash comes from the CacheWarmerPasswordHash environment variable, made by
-- "dotnet run --project api\Inat.Api -- hash-password" from the CacheWarmer:Password user-secret.
-- safe to run again: it resets the password and any lockout.
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @ID_User        INT = (SELECT ID FROM security.[User] WHERE Username = N'cache.warmer');
DECLARE @ViewerRoleID   INT = (SELECT ID FROM security.Role WHERE Name = N'Viewer');
DECLARE @RootTaxonID    INT = 48460;

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
        N'Cache'
      , N'Warmer'
      , N'cache.warmer'
      , N'cache.warmer@inat.local'
      , N'$(CacheWarmerPasswordHash)'
      , 1
      , 1
    );

    SET @ID_User = SCOPE_IDENTITY();
    EXEC security.spTreeNode_SetPath @TableName = N'User', @ID = @ID_User;
END
ELSE BEGIN
    UPDATE security.[User]
    SET
        PasswordHash     = N'$(CacheWarmerPasswordHash)'
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
    AND ID_Taxon = @RootTaxonID
    AND EndDate IS NULL
) BEGIN
    INSERT INTO security.User_TaxonScope (ID_User, ID_Taxon, ID_CreatedBy) VALUES (@ID_User, @RootTaxonID, 1);
END

PRINT 'cache.warmer is ready';