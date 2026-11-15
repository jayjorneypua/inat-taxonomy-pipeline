-- creates (or resets the password of) an administrator who can see all data.
-- the password hash comes from the AdminPasswordHash environment variable, made by
-- "dotnet run --project api\Inat.Api -- hash-password". the other values come from sqlcmd -v.
USE inat;
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @ID_User        INT = (SELECT ID FROM security.[User] WHERE Username = N'$(AdminUsername)');
DECLARE @AdminRoleID    INT = (SELECT ID FROM security.Role WHERE Name = N'Administrator');
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
        N'$(AdminFirstName)'
      , N'$(AdminLastName)'
      , N'$(AdminUsername)'
      , N'$(AdminEmail)'
      , N'$(AdminPasswordHash)'
      , 1
      , 1
    );

    SET @ID_User = SCOPE_IDENTITY();
    EXEC security.spTreeNode_SetPath @TableName = N'User', @ID = @ID_User;
END
ELSE BEGIN
    UPDATE security.[User]
    SET
        PasswordHash     = N'$(AdminPasswordHash)'
      , FailedLoginCount = 0
      , LockedUntil      = NULL
      , ID_UpdatedBy     = 1
      , UpdatedDate      = SYSUTCDATETIME()
    WHERE
        ID = @ID_User;
END

-- administrator role, no end date
IF NOT EXISTS (
    SELECT 1
    FROM security.User_Role
    WHERE ID_User = @ID_User
    AND ID_Role = @AdminRoleID
    AND EndDate IS NULL
) BEGIN
    INSERT INTO security.User_Role (ID_User, ID_Role, ID_CreatedBy) VALUES (@ID_User, @AdminRoleID, 1);
END

-- scope on the root of the tree: all data
IF NOT EXISTS (
    SELECT 1
    FROM security.User_TaxonScope
    WHERE ID_User = @ID_User
    AND ID_Taxon = @RootTaxonID
    AND EndDate IS NULL
) BEGIN
    INSERT INTO security.User_TaxonScope (ID_User, ID_Taxon, ID_CreatedBy) VALUES (@ID_User, @RootTaxonID, 1);
END

SELECT
    users.ID
  , users.Username
  , users.Email
  , roles.Name AS RoleName
FROM
    security.[User] users
INNER JOIN
    security.User_Role user_roles
    ON users.ID = user_roles.ID_User
    AND user_roles.EndDate IS NULL
INNER JOIN
    security.Role roles
    ON user_roles.ID_Role = roles.ID
WHERE
    users.ID = @ID_User;