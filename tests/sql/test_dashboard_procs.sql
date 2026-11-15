-- tests the drill-down and chart procs against the real serving data, inside a transaction rolled back at the end.
-- four users: one scoped to Amphibia and Anura (nested on purpose) with Viewer, one scoped to the whole tree
-- with Viewer, one with Viewer but no scope, one with no role.
-- the chart checks compare the pre-aggregated chart with a live count over dbo.Observation and fail on any difference.
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

BEGIN TRANSACTION;

DECLARE @OrganizationTypeID INT = (SELECT ID FROM security.GroupType WHERE Name = N'Organization');
DECLARE @ViewerRoleID       INT = (SELECT ID FROM security.Role      WHERE Name = N'Viewer');
DECLARE @HerpTeamID         INT;
DECLARE @FullTeamID         INT;
DECLARE @NoScopeTeamID      INT;
DECLARE @ScopedUserID       INT;
DECLARE @FullUserID         INT;
DECLARE @UnscopedUserID     INT;
DECLARE @NoRoleUserID       INT;
DECLARE @ScopedSessionID    BIGINT;
DECLARE @FullSessionID      BIGINT;
DECLARE @UnscopedSessionID  BIGINT;
DECLARE @NoRoleSessionID    BIGINT;

-- Herp Team: Viewer role, scope Amphibia (20978) and Anura (20979), which sits inside Amphibia
INSERT INTO security.[Group] (ID_Parent, ID_GroupType, Name, ID_CreatedBy) VALUES (NULL, @OrganizationTypeID, N'Herp Team', 1);
SET @HerpTeamID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Group', @ID = @HerpTeamID;
INSERT INTO security.Group_Role (ID_Group, ID_Role, ID_CreatedBy) VALUES (@HerpTeamID, @ViewerRoleID, 1);
INSERT INTO security.Group_TaxonScope (ID_Group, ID_Taxon, ID_CreatedBy) VALUES (@HerpTeamID, 20978, 1);
INSERT INTO security.Group_TaxonScope (ID_Group, ID_Taxon, ID_CreatedBy) VALUES (@HerpTeamID, 20979, 1);

-- Full Team: Viewer role, scope the whole tree (Life, 48460)
INSERT INTO security.[Group] (ID_Parent, ID_GroupType, Name, ID_CreatedBy) VALUES (NULL, @OrganizationTypeID, N'Full Team', 1);
SET @FullTeamID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Group', @ID = @FullTeamID;
INSERT INTO security.Group_Role (ID_Group, ID_Role, ID_CreatedBy) VALUES (@FullTeamID, @ViewerRoleID, 1);
INSERT INTO security.Group_TaxonScope (ID_Group, ID_Taxon, ID_CreatedBy) VALUES (@FullTeamID, 48460, 1);

-- No Scope Team: Viewer role, no scope at all
INSERT INTO security.[Group] (ID_Parent, ID_GroupType, Name, ID_CreatedBy) VALUES (NULL, @OrganizationTypeID, N'No Scope Team', 1);
SET @NoScopeTeamID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Group', @ID = @NoScopeTeamID;
INSERT INTO security.Group_Role (ID_Group, ID_Role, ID_CreatedBy) VALUES (@NoScopeTeamID, @ViewerRoleID, 1);

-- users
INSERT INTO security.[User] (FirstName, LastName, Username, Email, PasswordHash, ID_CreatedBy) VALUES (N'Herp', N'Tester', N'herp.tester', N'herp@example.com', N'x', 1);
SET @ScopedUserID = SCOPE_IDENTITY();
INSERT INTO security.User_Group (ID_User, ID_Group, ID_CreatedBy) VALUES (@ScopedUserID, @HerpTeamID, 1);

INSERT INTO security.[User] (FirstName, LastName, Username, Email, PasswordHash, ID_CreatedBy) VALUES (N'Full', N'Tester', N'full.tester', N'full@example.com', N'x', 1);
SET @FullUserID = SCOPE_IDENTITY();
INSERT INTO security.User_Group (ID_User, ID_Group, ID_CreatedBy) VALUES (@FullUserID, @FullTeamID, 1);

INSERT INTO security.[User] (FirstName, LastName, Username, Email, PasswordHash, ID_CreatedBy) VALUES (N'No', N'Scope', N'no.scope', N'noscope@example.com', N'x', 1);
SET @UnscopedUserID = SCOPE_IDENTITY();
INSERT INTO security.User_Group (ID_User, ID_Group, ID_CreatedBy) VALUES (@UnscopedUserID, @NoScopeTeamID, 1);

INSERT INTO security.[User] (FirstName, LastName, Username, Email, PasswordHash, ID_CreatedBy) VALUES (N'No', N'Role', N'no.role', N'norole@example.com', N'x', 1);
SET @NoRoleUserID = SCOPE_IDENTITY();

-- sessions
EXEC security.spSession_Create @ID_User = @ScopedUserID,   @TokenHash = 0x01, @ExpiresDate = '2099-01-01', @ID_Session = @ScopedSessionID OUTPUT;
EXEC security.spSession_Create @ID_User = @UnscopedUserID, @TokenHash = 0x02, @ExpiresDate = '2099-01-01', @ID_Session = @UnscopedSessionID OUTPUT;
EXEC security.spSession_Create @ID_User = @NoRoleUserID,   @TokenHash = 0x03, @ExpiresDate = '2099-01-01', @ID_Session = @NoRoleSessionID OUTPUT;
EXEC security.spSession_Create @ID_User = @FullUserID,     @TokenHash = 0x04, @ExpiresDate = '2099-01-01', @ID_Session = @FullSessionID OUTPUT;

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

PRINT '--- 6. chart from the monthly counts table vs a live count over dbo.Observation (any difference fails)';

CREATE TABLE #chart_cases (
    ID                  INT             IDENTITY(1, 1)  NOT NULL
  , Label               VARCHAR(100)                    NOT NULL
  , ID_Session          BIGINT                          NOT NULL
  , ID_Taxon            INT                             NOT NULL
);

INSERT INTO #chart_cases (Label, ID_Session, ID_Taxon)
VALUES
    ('full scope at the root',                         @FullSessionID,     48460)
  , ('full scope at Amphibia',                         @FullSessionID,     20978)
  , ('Herp Team at the root (scope starts lower)',     @ScopedSessionID,   48460)
  , ('Herp Team at Amphibia (nested Anura scope)',     @ScopedSessionID,   20978)
  , ('Herp Team at Anura',                             @ScopedSessionID,   20979)
  , ('Herp Team at Plantae (outside scope, no rows)',  @ScopedSessionID,   47126)
  , ('no scope at the root (no rows)',                 @UnscopedSessionID, 48460);

CREATE TABLE #expected (
    MonthStart          DATE            NOT NULL
  , ObservationCount    INT             NOT NULL
);

CREATE TABLE #actual (
    MonthStart          DATE            NOT NULL
  , ObservationCount    INT             NOT NULL
);

DECLARE @CaseID             INT = 1;
DECLARE @CaseCount          INT;
DECLARE @CaseLabel          VARCHAR(100);
DECLARE @CaseSessionID      BIGINT;
DECLARE @CaseTaxonID        INT;
DECLARE @CaseMonths         INT;
DECLARE @CaseObservations   INT;
DECLARE @MismatchMessage    NVARCHAR(400);

SELECT @CaseCount = COUNT(*) FROM #chart_cases;

WHILE @CaseID <= @CaseCount
BEGIN
    SELECT
        @CaseLabel     = chart_cases.Label
      , @CaseSessionID = chart_cases.ID_Session
      , @CaseTaxonID   = chart_cases.ID_Taxon
    FROM
        #chart_cases chart_cases
    WHERE
        chart_cases.ID = @CaseID;

    TRUNCATE TABLE #expected;
    TRUNCATE TABLE #actual;

    -- the old way: count every observation in the scoped subtree
    INSERT INTO #expected (
        MonthStart
      , ObservationCount
    )
    SELECT
        DATEFROMPARTS(YEAR(observations.ObservedDate), MONTH(observations.ObservedDate), 1)
      , COUNT(*)
    FROM
        dbo.Observation observations
    INNER JOIN
        dbo.fnSession_ScopedSubtreeTaxa(@CaseSessionID, @CaseTaxonID) scoped_taxa
        ON observations.ID_Taxon = scoped_taxa.ID
    GROUP BY
        DATEFROMPARTS(YEAR(observations.ObservedDate), MONTH(observations.ObservedDate), 1);

    -- the new way: the chart procedure reading dbo.Taxon_MonthlyCount
    INSERT INTO #actual (
        MonthStart
      , ObservationCount
    )
    EXEC dbo.spDashboard_ObservationsByMonth @ID_Session = @CaseSessionID, @ID_Taxon = @CaseTaxonID;

    IF EXISTS (SELECT MonthStart, ObservationCount FROM #expected EXCEPT SELECT MonthStart, ObservationCount FROM #actual)
    OR EXISTS (SELECT MonthStart, ObservationCount FROM #actual EXCEPT SELECT MonthStart, ObservationCount FROM #expected)
    BEGIN
        SET @MismatchMessage = N'chart does not match the live count: ' + @CaseLabel;
        THROW 50000, @MismatchMessage, 1;
    END

    SELECT
        @CaseMonths       = COUNT(*)
      , @CaseObservations = COALESCE(SUM(actual.ObservationCount), 0)
    FROM
        #actual actual;

    PRINT '--- chart matches: ' + @CaseLabel + ' (' + CAST(@CaseMonths AS VARCHAR(10)) + ' months, ' + CAST(@CaseObservations AS VARCHAR(20)) + ' observations)';

    SET @CaseID = @CaseID + 1;
END

ROLLBACK TRANSACTION;