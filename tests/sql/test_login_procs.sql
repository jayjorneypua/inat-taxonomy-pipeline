-- tests the login procs inside a transaction that is rolled back at the end.
-- runs on inat_test_empty: seeded roles and permissions, no other data.
-- covers: unknown username, 5 failures locking the account, a locked account blocking login,
-- a successful login filling the session caches, the counters being reset, and the audit trail.
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

BEGIN TRANSACTION;

DECLARE @OrganizationTypeID INT = (SELECT ID FROM security.GroupType WHERE Name = N'Organization');
DECLARE @ViewerRoleID       INT = (SELECT ID FROM security.Role      WHERE Name = N'Viewer');
DECLARE @FirstAuditID       BIGINT = (SELECT ISNULL(MAX(ID), 0) + 1 FROM security.Audit_Log);
DECLARE @PandaID            INT;
DECLARE @MariaID            INT;
DECLARE @Attempt            INT = 1;
DECLARE @ID_Session         BIGINT;
DECLARE @WasRefused         BIT = 0;
DECLARE @Actual             NVARCHAR(400);

CREATE TABLE #login_info (
    ID_User             INT
  , PasswordHash        NVARCHAR(512)
  , IsLocked            BIT
  , LockedUntil         DATETIME2(3)
  , HasChangedPassword  BIT
);

-- a small slice of the taxonomy so the scope cache can find a path
INSERT INTO dbo.Taxon (ID, ID_Parent, ScientificName, Rank, Path, Level, IsInTree) VALUES (48460,  NULL,   N'Life',       N'stateofmatter', '48460',                  1, 1);
INSERT INTO dbo.Taxon (ID, ID_Parent, ScientificName, Rank, Path, Level, IsInTree) VALUES (1,      48460,  N'Animalia',   N'kingdom',       '48460,1',                2, 1);
INSERT INTO dbo.Taxon (ID, ID_Parent, ScientificName, Rank, Path, Level, IsInTree) VALUES (2,      1,      N'Chordata',   N'phylum',        '48460,1,2',              3, 1);
INSERT INTO dbo.Taxon (ID, ID_Parent, ScientificName, Rank, Path, Level, IsInTree) VALUES (355675, 2,      N'Vertebrata', N'subphylum',     '48460,1,2,355675',       4, 1);
INSERT INTO dbo.Taxon (ID, ID_Parent, ScientificName, Rank, Path, Level, IsInTree) VALUES (20978,  355675, N'Amphibia',   N'class',         '48460,1,2,355675,20978', 5, 1);

-- Panda with the Viewer role and Amphibia scope, Maria as a member
INSERT INTO security.[Group] (ID_Parent, ID_GroupType, Name, ID_CreatedBy) VALUES (NULL, @OrganizationTypeID, N'Panda', 1);
SET @PandaID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Group', @ID = @PandaID;

INSERT INTO security.[User] (FirstName, LastName, Username, Email, PasswordHash, ID_CreatedBy)
VALUES (N'Maria', N'Santos', N'maria', N'maria@example.com', N'test-hash-not-real', 1);
SET @MariaID = SCOPE_IDENTITY();

INSERT INTO security.User_Group (ID_User, ID_Group, ID_CreatedBy) VALUES (@MariaID, @PandaID, 1);
INSERT INTO security.Group_Role (ID_Group, ID_Role, ID_CreatedBy) VALUES (@PandaID, @ViewerRoleID, 1);
INSERT INTO security.Group_TaxonScope (ID_Group, ID_Taxon, ID_CreatedBy) VALUES (@PandaID, 20978, 1);

-- 1. unknown username: no row
INSERT INTO #login_info EXEC security.spUser_GetLoginInfo @Username = N'nobody';
IF (SELECT COUNT(*) FROM #login_info) = 0 BEGIN PRINT '--- passed 1: unknown username returns nothing'; END
ELSE BEGIN PRINT '--- FAILED 1: unknown username returned a row'; END

-- 2. Maria before any failure: not locked
DELETE FROM #login_info;
INSERT INTO #login_info EXEC security.spUser_GetLoginInfo @Username = N'maria';
IF (SELECT IsLocked FROM #login_info) = 0 BEGIN PRINT '--- passed 2: not locked yet'; END
ELSE BEGIN PRINT '--- FAILED 2: locked before any failure'; END

-- one failure for an unknown username, then 5 wrong passwords for Maria
EXEC security.spUser_LoginFailed @Username = N'nobody', @ClientIpAddress = '10.0.0.9';

WHILE @Attempt <= 5 BEGIN
    EXEC security.spUser_LoginFailed @Username = N'maria', @ClientIpAddress = '10.0.0.5';
    SET @Attempt += 1;
END

-- 3. after 5 failures: locked
DELETE FROM #login_info;
INSERT INTO #login_info EXEC security.spUser_GetLoginInfo @Username = N'maria';
IF (SELECT IsLocked FROM #login_info) = 1 BEGIN PRINT '--- passed 3: locked after 5 failures'; END
ELSE BEGIN PRINT '--- FAILED 3: not locked after 5 failures'; END

-- 4. a session while locked must be refused
BEGIN TRY
    EXEC security.spSession_Create @ID_User = @MariaID, @TokenHash = 0x01, @ExpiresDate = '2099-01-01', @ID_Session = @ID_Session OUTPUT;
END TRY
BEGIN CATCH
    SET @WasRefused = 1;
END CATCH

IF @WasRefused = 1 BEGIN PRINT '--- passed 4: locked account refused'; END
ELSE BEGIN PRINT '--- FAILED 4: a locked account got a session'; END

-- pretend the 15 minutes passed, then log in
UPDATE security.[User] SET LockedUntil = DATEADD(MINUTE, -1, SYSUTCDATETIME()) WHERE ID = @MariaID;

EXEC security.spSession_Create
    @ID_User         = @MariaID
  , @TokenHash       = 0x0102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F20
  , @ExpiresDate     = '2099-01-01'
  , @ClientIpAddress = '10.0.0.5'
  , @ID_Session      = @ID_Session OUTPUT;

-- 5. session permissions: the Viewer role through Panda
SET @Actual = (
    SELECT STRING_AGG(permissions.Code, N',') WITHIN GROUP (ORDER BY permissions.Code)
    FROM security.Session_Permission session_permissions
    INNER JOIN security.Permission permissions ON session_permissions.ID_Permission = permissions.ID
    WHERE session_permissions.ID_Session = @ID_Session
);
IF ISNULL(@Actual, N'') = N'dashboard.view,taxonomy.view' BEGIN PRINT '--- passed 5: session permissions'; END
ELSE BEGIN PRINT CONCAT('--- FAILED 5: session permissions, got ', @Actual); END

-- 6. session scope: Amphibia with its full path
SET @Actual = (SELECT STRING_AGG(CAST(TaxonPath AS NVARCHAR(850)), N';') FROM security.Session_TaxonScope WHERE ID_Session = @ID_Session);
IF ISNULL(@Actual, N'') = N'48460,1,2,355675,20978' BEGIN PRINT '--- passed 6: session scope'; END
ELSE BEGIN PRINT CONCAT('--- FAILED 6: session scope, got ', @Actual); END

-- 7. counters reset after the successful login
SET @Actual = (SELECT CONCAT(LoginCount, N'/', FailedLoginCount, N'/', ISNULL(CONVERT(NVARCHAR(30), LockedUntil), N'null')) FROM security.[User] WHERE ID = @MariaID);
IF @Actual = N'1/0/null' BEGIN PRINT '--- passed 7: counters reset'; END
ELSE BEGIN PRINT CONCAT('--- FAILED 7: counters (logins/failures/locked until), got ', @Actual); END

-- 8. audit trail of this test, in order
SET @Actual = (SELECT STRING_AGG(EventType, N',') WITHIN GROUP (ORDER BY ID) FROM security.Audit_Log WHERE ID >= @FirstAuditID);
IF @Actual = N'LoginFailed,LoginFailed,LoginFailed,LoginFailed,LoginFailed,LoginLocked,LoginSucceeded' BEGIN PRINT '--- passed 8: audit trail'; END
ELSE BEGIN PRINT CONCAT('--- FAILED 8: audit trail, got ', @Actual); END

ROLLBACK TRANSACTION;