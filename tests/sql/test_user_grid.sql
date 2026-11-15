-- tests the users grid inside a transaction that is rolled back at the end.
-- five test users whose usernames start with gridtest, so the real users don't affect the results:
--   alice  Anders  Finance, Viewer
--   bob    Baker   Finance, Analyst
--   carol  Cruz    Herp Team
--   dave   Diaz    no group, locked
--   erin   Evans   no group, inactive
-- plus grid.admin (Administrator) to call the grid with
USE inat;
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

BEGIN TRANSACTION;

DECLARE @OrganizationTypeID INT = (SELECT ID FROM security.GroupType WHERE Name = N'Organization');
DECLARE @ViewerRoleID       INT = (SELECT ID FROM security.Role      WHERE Name = N'Viewer');
DECLARE @AnalystRoleID      INT = (SELECT ID FROM security.Role      WHERE Name = N'Analyst');
DECLARE @AdminRoleID        INT = (SELECT ID FROM security.Role      WHERE Name = N'Administrator');
DECLARE @FinanceID          INT;
DECLARE @HerpTeamID         INT;
DECLARE @AliceID            INT;
DECLARE @BobID              INT;
DECLARE @CarolID            INT;
DECLARE @AdminID            INT;
DECLARE @AdminSessionID     BIGINT;
DECLARE @AliceSessionID     BIGINT;

INSERT INTO security.[Group] (ID_GroupType, Name, ID_CreatedBy) VALUES (@OrganizationTypeID, N'Finance', 1);
SET @FinanceID = SCOPE_IDENTITY();
INSERT INTO security.[Group] (ID_GroupType, Name, ID_CreatedBy) VALUES (@OrganizationTypeID, N'Herp Team Test', 1);
SET @HerpTeamID = SCOPE_IDENTITY();

INSERT INTO security.[User] (FirstName, LastName, Username, Email, PasswordHash, ID_CreatedBy) VALUES (N'Alice', N'Anders', N'gridtest.alice', N'alice@example.com', N'x', 1);
SET @AliceID = SCOPE_IDENTITY();
INSERT INTO security.[User] (FirstName, LastName, Username, Email, PasswordHash, ID_CreatedBy) VALUES (N'Bob', N'Baker', N'gridtest.bob', N'bob@example.com', N'x', 1);
SET @BobID = SCOPE_IDENTITY();
INSERT INTO security.[User] (FirstName, LastName, Username, Email, PasswordHash, ID_CreatedBy) VALUES (N'Carol', N'Cruz', N'gridtest.carol', N'carol@example.com', N'x', 1);
SET @CarolID = SCOPE_IDENTITY();
INSERT INTO security.[User] (FirstName, LastName, Username, Email, PasswordHash, LockedUntil, ID_CreatedBy) VALUES (N'Dave', N'Diaz', N'gridtest.dave', N'dave@example.com', N'x', DATEADD(HOUR, 1, SYSUTCDATETIME()), 1);
INSERT INTO security.[User] (FirstName, LastName, Username, Email, PasswordHash, Active, ID_CreatedBy) VALUES (N'Erin', N'Evans', N'gridtest.erin', N'erin@example.com', N'x', 0, 1);
INSERT INTO security.[User] (FirstName, LastName, Username, Email, PasswordHash, ID_CreatedBy) VALUES (N'Grid', N'Admin', N'grid.admin', N'grid.admin@example.com', N'x', 1);
SET @AdminID = SCOPE_IDENTITY();

INSERT INTO security.User_Group (ID_User, ID_Group, ID_CreatedBy) VALUES (@AliceID, @FinanceID, 1);
INSERT INTO security.User_Group (ID_User, ID_Group, ID_CreatedBy) VALUES (@BobID, @FinanceID, 1);
INSERT INTO security.User_Group (ID_User, ID_Group, ID_CreatedBy) VALUES (@CarolID, @HerpTeamID, 1);

INSERT INTO security.User_Role (ID_User, ID_Role, ID_CreatedBy) VALUES (@AliceID, @ViewerRoleID, 1);
INSERT INTO security.User_Role (ID_User, ID_Role, ID_CreatedBy) VALUES (@BobID, @AnalystRoleID, 1);
INSERT INTO security.User_Role (ID_User, ID_Role, ID_CreatedBy) VALUES (@AdminID, @AdminRoleID, 1);

EXEC security.spSession_Create @ID_User = @AdminID, @TokenHash = 0x01, @ExpiresDate = '2099-01-01', @ID_Session = @AdminSessionID OUTPUT;
EXEC security.spSession_Create @ID_User = @AliceID, @TokenHash = 0x02, @ExpiresDate = '2099-01-01', @ID_Session = @AliceSessionID OUTPUT;

PRINT '--- 1. search gridtest (expect 5 users, alice to erin, TotalCount 5, groups and roles listed)';
EXEC security.spUser_Grid @ID_Session = @AdminSessionID, @Search = N'gridtest';

PRINT '--- 2. filter GroupName = Finance (expect alice and bob)';
EXEC security.spUser_Grid @ID_Session = @AdminSessionID, @Search = N'gridtest',
    @Filters = N'[{"column":"GroupName","operator":"eq","value":"Finance"}]';

PRINT '--- 3. sort by LastName descending (expect Evans, Diaz, Cruz, Baker, Anders)';
EXEC security.spUser_Grid @ID_Session = @AdminSessionID, @Search = N'gridtest', @SortColumn = N'LastName', @SortDirection = N'desc';

PRINT '--- 4. page 2 with 2 per page (expect carol and dave, TotalCount still 5)';
EXEC security.spUser_Grid @ID_Session = @AdminSessionID, @Search = N'gridtest', @Page = 2, @PageSize = 2;

PRINT '--- 5. Status in Locked (expect dave)';
EXEC security.spUser_Grid @ID_Session = @AdminSessionID, @Search = N'gridtest',
    @Filters = N'[{"column":"Status","operator":"in","value":"Locked"}]';

PRINT '--- 6. username contains an underscore (expect no rows: _ is a literal, not a wildcard)';
EXEC security.spUser_Grid @ID_Session = @AdminSessionID, @Search = N'gridtest',
    @Filters = N'[{"column":"Username","operator":"contains","value":"_"}]';

PRINT '--- 7. sql in a filter value (expect no rows: it is only a value)';
EXEC security.spUser_Grid @ID_Session = @AdminSessionID, @Search = N'gridtest',
    @Filters = N'[{"column":"Username","operator":"eq","value":"x'' OR 1=1 --"}]';

PRINT '--- 8. sql in the sort column (expect refused)';
BEGIN TRY
    EXEC security.spUser_Grid @ID_Session = @AdminSessionID, @SortColumn = N'Username; DROP TABLE security.Audit_Log --';
    PRINT '--- FAILED: the sort column was accepted';
END TRY
BEGIN CATCH
    PRINT '--- correctly refused: ' + ERROR_MESSAGE();
END CATCH

PRINT '--- 9. filter on a column that is not allowed (expect refused)';
BEGIN TRY
    EXEC security.spUser_Grid @ID_Session = @AdminSessionID,
        @Filters = N'[{"column":"PasswordHash","operator":"eq","value":"x"}]';
    PRINT '--- FAILED: the filter was accepted';
END TRY
BEGIN CATCH
    PRINT '--- correctly refused: ' + ERROR_MESSAGE();
END CATCH

PRINT '--- 10. alice is not an administrator (expect access denied)';
BEGIN TRY
    EXEC security.spUser_Grid @ID_Session = @AliceSessionID;
    PRINT '--- FAILED: access was allowed';
END TRY
BEGIN CATCH
    PRINT '--- correctly denied: ' + ERROR_MESSAGE();
END CATCH

PRINT '--- 11. search Fin (expect alice and bob: no name matches, their group Finance does)';
EXEC security.spUser_Grid @ID_Session = @AdminSessionID, @Search = N'Fin';

PRINT '--- 12. group contains "Herp Team T" (expect carol)';
EXEC security.spUser_Grid @ID_Session = @AdminSessionID, @Search = N'gridtest',
    @Filters = N'[{"column":"GroupName","operator":"contains","value":"Herp Team T"}]';

PRINT '--- 13. Status in Inactive (expect erin)';
EXEC security.spUser_Grid @ID_Session = @AdminSessionID, @Search = N'gridtest',
    @Filters = N'[{"column":"Status","operator":"in","value":"Inactive"}]';

PRINT '--- 14. Status in Locked and Inactive (expect dave and erin)';
EXEC security.spUser_Grid @ID_Session = @AdminSessionID, @Search = N'gridtest',
    @Filters = N'[{"column":"Status","operator":"in","value":"Locked,Inactive"}]';

ROLLBACK TRANSACTION;