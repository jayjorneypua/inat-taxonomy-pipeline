-- tests refresh, revoke and the access check inside a transaction that is rolled back at the end.
-- runs on inat_test_empty: seeded roles and permissions, no other data.
-- covers: allowed and denied access, token rotation, reuse of a replaced token (theft detection),
-- logout, double logout, refreshing after logout, and the audit trail.
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

BEGIN TRANSACTION;

DECLARE @OrganizationTypeID INT = (SELECT ID FROM security.GroupType WHERE Name = N'Organization');
DECLARE @ViewerRoleID       INT = (SELECT ID FROM security.Role      WHERE Name = N'Viewer');
DECLARE @FirstAuditID       BIGINT = (SELECT ISNULL(MAX(ID), 0) + 1 FROM security.Audit_Log);
DECLARE @PandaID            INT;
DECLARE @MariaID            INT;
DECLARE @ID_Session         BIGINT;
DECLARE @SecondSessionID    BIGINT;
DECLARE @RefreshedSessionID BIGINT;
DECLARE @ID_User            INT;
DECLARE @Result             NVARCHAR(20);
DECLARE @WasDenied          BIT;
DECLARE @Actual             NVARCHAR(400);
DECLARE @TokenA             VARBINARY(32) = HASHBYTES('SHA2_256', 'test token a');
DECLARE @TokenB             VARBINARY(32) = HASHBYTES('SHA2_256', 'test token b');
DECLARE @TokenC             VARBINARY(32) = HASHBYTES('SHA2_256', 'test token c');
DECLARE @TokenD             VARBINARY(32) = HASHBYTES('SHA2_256', 'test token d');

-- Panda with the Viewer role (dashboard.view, taxonomy.view), Maria as a member
INSERT INTO security.[Group] (ID_Parent, ID_GroupType, Name, ID_CreatedBy) VALUES (NULL, @OrganizationTypeID, N'Panda', 1);
SET @PandaID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Group', @ID = @PandaID;

INSERT INTO security.[User] (FirstName, LastName, Username, Email, PasswordHash, ID_CreatedBy)
VALUES (N'Maria', N'Santos', N'maria', N'maria@example.com', N'test-hash-not-real', 1);
SET @MariaID = SCOPE_IDENTITY();

INSERT INTO security.User_Group (ID_User, ID_Group, ID_CreatedBy) VALUES (@MariaID, @PandaID, 1);
INSERT INTO security.Group_Role (ID_Group, ID_Role, ID_CreatedBy) VALUES (@PandaID, @ViewerRoleID, 1);

-- login with token A
EXEC security.spSession_Create @ID_User = @MariaID, @TokenHash = @TokenA, @ExpiresDate = '2099-01-01', @ID_Session = @ID_Session OUTPUT;

-- 1. taxonomy.view is allowed
SET @WasDenied = 0;
BEGIN TRY
    EXEC security.spSession_CheckAccess @ID_Session = @ID_Session, @PermissionCode = N'taxonomy.view', @ID_User = @ID_User OUTPUT;
END TRY
BEGIN CATCH
    SET @WasDenied = 1;
END CATCH
IF @WasDenied = 0 AND @ID_User = @MariaID BEGIN PRINT '--- passed 1: allowed permission'; END
ELSE BEGIN PRINT '--- FAILED 1: taxonomy.view was denied'; END

-- 2. admin.users.manage is denied
SET @WasDenied = 0;
BEGIN TRY
    EXEC security.spSession_CheckAccess @ID_Session = @ID_Session, @PermissionCode = N'admin.users.manage', @ID_User = @ID_User OUTPUT;
END TRY
BEGIN CATCH
    SET @WasDenied = 1;
END CATCH
IF @WasDenied = 1 BEGIN PRINT '--- passed 2: missing permission denied'; END
ELSE BEGIN PRINT '--- FAILED 2: admin.users.manage was allowed'; END

-- 3. refresh token A to token B
EXEC security.spSession_Refresh @OldTokenHash = @TokenA, @NewTokenHash = @TokenB, @NewExpiresDate = '2099-01-02', @Result = @Result OUTPUT, @ID_Session = @RefreshedSessionID OUTPUT;
IF @Result = N'ok' BEGIN PRINT '--- passed 3: refresh ok'; END
ELSE BEGIN PRINT CONCAT('--- FAILED 3: refresh, got ', @Result); END

-- 4. token A again, it was replaced: reused, session revoked
EXEC security.spSession_Refresh @OldTokenHash = @TokenA, @NewTokenHash = @TokenC, @NewExpiresDate = '2099-01-03', @Result = @Result OUTPUT, @ID_Session = @RefreshedSessionID OUTPUT;
IF @Result = N'reused' BEGIN PRINT '--- passed 4: reuse detected'; END
ELSE BEGIN PRINT CONCAT('--- FAILED 4: reuse, got ', @Result); END

-- 5. the revoked session is denied
SET @WasDenied = 0;
BEGIN TRY
    EXEC security.spSession_CheckAccess @ID_Session = @ID_Session, @PermissionCode = N'taxonomy.view', @ID_User = @ID_User OUTPUT;
END TRY
BEGIN CATCH
    SET @WasDenied = 1;
END CATCH
IF @WasDenied = 1 BEGIN PRINT '--- passed 5: revoked session denied'; END
ELSE BEGIN PRINT '--- FAILED 5: a revoked session was allowed'; END

-- a fresh login with token C, then logout twice
EXEC security.spSession_Create @ID_User = @MariaID, @TokenHash = @TokenC, @ExpiresDate = '2099-01-01', @ID_Session = @SecondSessionID OUTPUT;
EXEC security.spSession_Revoke @ID_Session = @SecondSessionID, @Reason = N'logout';
EXEC security.spSession_Revoke @ID_Session = @SecondSessionID, @Reason = N'logout';

-- 6. refresh after logout: invalid
EXEC security.spSession_Refresh @OldTokenHash = @TokenC, @NewTokenHash = @TokenD, @NewExpiresDate = '2099-01-03', @Result = @Result OUTPUT, @ID_Session = @RefreshedSessionID OUTPUT;
IF @Result = N'invalid' BEGIN PRINT '--- passed 6: refresh after logout invalid'; END
ELSE BEGIN PRINT CONCAT('--- FAILED 6: refresh after logout, got ', @Result); END

-- 7. audit trail of this test, in order, with exactly one Logout
SET @Actual = (SELECT STRING_AGG(EventType, N',') WITHIN GROUP (ORDER BY ID) FROM security.Audit_Log WHERE ID >= @FirstAuditID);
IF @Actual = N'LoginSucceeded,AccessDenied,SessionRefreshed,SessionRevoked,AccessDenied,LoginSucceeded,Logout' BEGIN PRINT '--- passed 7: audit trail'; END
ELSE BEGIN PRINT CONCAT('--- FAILED 7: audit trail, got ', @Actual); END

ROLLBACK TRANSACTION;