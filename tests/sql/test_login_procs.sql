-- tests the login procs inside a transaction that is rolled back at the end.
-- covers: unknown username, 5 failures locking the account, a locked account blocking login,
-- a successful login filling the session caches, and the counters being reset.
USE inat;
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

BEGIN TRANSACTION;

DECLARE @Now                DATETIME2(3);
DECLARE @OrganizationTypeID INT = (SELECT ID FROM security.GroupType    WHERE Name = N'Organization');
DECLARE @PageTypeID         INT = (SELECT ID FROM security.ResourceType WHERE Name = N'Page');
DECLARE @ViewerRoleID       INT = (SELECT ID FROM security.Role         WHERE Name = N'Viewer');
DECLARE @PandaID            INT;
DECLARE @MariaID            INT;
DECLARE @TaxonomyPageID     INT;
DECLARE @ViewTaxonomyID     INT;
DECLARE @Attempt            INT = 1;
DECLARE @ID_Session         BIGINT;

-- a tiny slice of the taxonomy so the scope cache can find a path: Life > Animalia > Chordata > Vertebrata > Amphibia
INSERT INTO dbo.Taxon (ID, ID_Parent, ScientificName, Rank, Path, Level, IsInTree) VALUES (48460,  NULL,   N'Life',       N'stateofmatter', '48460',                    1, 1);
INSERT INTO dbo.Taxon (ID, ID_Parent, ScientificName, Rank, Path, Level, IsInTree) VALUES (1,      48460,  N'Animalia',   N'kingdom',       '48460,1',                  2, 1);
INSERT INTO dbo.Taxon (ID, ID_Parent, ScientificName, Rank, Path, Level, IsInTree) VALUES (2,      1,      N'Chordata',   N'phylum',        '48460,1,2',                3, 1);
INSERT INTO dbo.Taxon (ID, ID_Parent, ScientificName, Rank, Path, Level, IsInTree) VALUES (355675, 2,      N'Vertebrata', N'subphylum',     '48460,1,2,355675',         4, 1);
INSERT INTO dbo.Taxon (ID, ID_Parent, ScientificName, Rank, Path, Level, IsInTree) VALUES (20978,  355675, N'Amphibia',   N'class',         '48460,1,2,355675,20978',   5, 1);

-- Panda with the Viewer role and Amphibia scope, Maria as a member
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
INSERT INTO security.Group_TaxonScope (ID_Group, ID_Taxon, ID_CreatedBy) VALUES (@PandaID, 20978, 1);

PRINT '--- 1. unknown username (expect no row)';
EXEC security.spUser_GetLoginInfo @Username = N'nobody';

PRINT '--- 2. Maria before any failure (expect IsLocked 0)';
EXEC security.spUser_GetLoginInfo @Username = N'maria';

-- one failed attempt for a username that doesn't exist, then 5 wrong passwords for Maria
EXEC security.spUser_LoginFailed @Username = N'nobody', @ClientIpAddress = '10.0.0.9';

WHILE @Attempt <= 5 BEGIN
    EXEC security.spUser_LoginFailed @Username = N'maria', @ClientIpAddress = '10.0.0.5';
    SET @Attempt += 1;
END

PRINT '--- 3. Maria after 5 failures (expect IsLocked 1)';
EXEC security.spUser_GetLoginInfo @Username = N'maria';

PRINT '--- 4. creating a session while locked (expect it to be refused)';
BEGIN TRY
    EXEC security.spSession_Create
        @ID_User     = @MariaID
      , @TokenHash   = 0x01
      , @ExpiresDate = '2099-01-01'
      , @ID_Session  = @ID_Session OUTPUT;

    PRINT '--- FAILED: a locked account got a session';
END TRY
BEGIN CATCH
    PRINT '--- correctly refused: ' + ERROR_MESSAGE();
END CATCH

-- pretend the 15 minutes passed
UPDATE security.[User] SET LockedUntil = DATEADD(MINUTE, -1, SYSUTCDATETIME()) WHERE ID = @MariaID;

-- successful login: in real life the token hash comes from the api, here a fake one
SET @Now = SYSUTCDATETIME();

EXEC security.spSession_Create
    @ID_User         = @MariaID
  , @TokenHash       = 0x0102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F20
  , @ExpiresDate     = '2099-01-01'
  , @ClientIpAddress = '10.0.0.5'
  , @UserAgent       = N'test script'
  , @ID_Session      = @ID_Session OUTPUT;

PRINT '--- 5. session permissions (expect taxonomy.view)';
SELECT
    permissions.Code AS PermissionCode
FROM
    security.Session_Permission session_permissions
INNER JOIN
    security.Permission permissions
    ON session_permissions.ID_Permission = permissions.ID
WHERE
    session_permissions.ID_Session = @ID_Session;

PRINT '--- 6. session scope (expect 20978 with path 48460,1,2,355675,20978)';
SELECT
    ID_Taxon
  , TaxonPath
FROM
    security.Session_TaxonScope
WHERE
    ID_Session = @ID_Session;

PRINT '--- 7. Maria''s counters (expect LoginCount 1, FailedLoginCount 0, LockedUntil NULL)';
SELECT
    LoginCount
  , FailedLoginCount
  , LockedUntil
FROM
    security.[User]
WHERE
    ID = @MariaID;

PRINT '--- 8. audit log (expect 1 unknown username, 4 LoginFailed, 1 LoginLocked, 1 LoginSucceeded)';
SELECT
    EventType
  , Username
  , Details
FROM
    security.Audit_Log
ORDER BY
    ID;

ROLLBACK TRANSACTION;