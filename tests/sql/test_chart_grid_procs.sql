-- tests the monthly chart and the photo grid against the real serving data,
-- inside a transaction rolled back at the end. One user scoped to Amphibia.
USE inat;
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

BEGIN TRANSACTION;

DECLARE @OrganizationTypeID INT = (SELECT ID FROM security.GroupType WHERE Name = N'Organization');
DECLARE @ViewerRoleID       INT = (SELECT ID FROM security.Role      WHERE Name = N'Viewer');
DECLARE @HerpTeamID         INT;
DECLARE @ScopedUserID       INT;
DECLARE @ScopedSessionID    BIGINT;
DECLARE @LastObservedDate   DATE;
DECLARE @LastObservationID  INT;

CREATE TABLE #grid_page (
    ObservationID           INT
  , ObservationUuid         UNIQUEIDENTIFIER
  , ObservedDate            DATE
  , ID_Taxon                INT
  , ScientificName          NVARCHAR(300)
  , CommonName              NVARCHAR(300)
  , ObserverDisplayName     NVARCHAR(300)
  , PhotoCount              INT
  , SquareUrl               VARCHAR(300)
  , MediumUrl               VARCHAR(300)
  , Attribution             NVARCHAR(500)
  , License                 VARCHAR(20)
  , PageNumber              INT NULL
);

INSERT INTO security.[Group] (ID_Parent, ID_GroupType, Name, ID_CreatedBy) VALUES (NULL, @OrganizationTypeID, N'Herp Team', 1);
SET @HerpTeamID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Group', @ID = @HerpTeamID;
INSERT INTO security.Group_Role (ID_Group, ID_Role, ID_CreatedBy) VALUES (@HerpTeamID, @ViewerRoleID, 1);
INSERT INTO security.Group_TaxonScope (ID_Group, ID_Taxon, ID_CreatedBy) VALUES (@HerpTeamID, 20978, 1);

INSERT INTO security.[User] (FirstName, LastName, Username, Email, PasswordHash, ID_CreatedBy) VALUES (N'Herp', N'Tester', N'herp.tester', N'herp@example.com', N'x', 1);
SET @ScopedUserID = SCOPE_IDENTITY();
INSERT INTO security.User_Group (ID_User, ID_Group, ID_CreatedBy) VALUES (@ScopedUserID, @HerpTeamID, 1);

EXEC security.spSession_Create @ID_User = @ScopedUserID, @TokenHash = 0x01, @ExpiresDate = '2099-01-01', @ID_Session = @ScopedSessionID OUTPUT;

PRINT '--- 1. amphibian observations per month (the counts should add up to 52116)';
EXEC dbo.spDashboard_ObservationsByMonth @ID_Session = @ScopedSessionID, @ID_Taxon = 20978;

-- page 1 of the grid, 5 rows
INSERT INTO #grid_page (ObservationID, ObservationUuid, ObservedDate, ID_Taxon, ScientificName, CommonName, ObserverDisplayName, PhotoCount, SquareUrl, MediumUrl, Attribution, License)
EXEC dbo.spTaxonomy_ObservationsPage @ID_Session = @ScopedSessionID, @ID_Taxon = 20978, @PageSize = 5;
UPDATE #grid_page SET PageNumber = 1 WHERE PageNumber IS NULL;

-- the cursor is the last row of page 1
SELECT TOP (1)
    @LastObservedDate  = ObservedDate
  , @LastObservationID = ObservationID
FROM
    #grid_page
WHERE
    PageNumber = 1
ORDER BY
    ObservedDate ASC
  , ObservationID ASC;

-- page 2, continuing after the cursor
INSERT INTO #grid_page (ObservationID, ObservationUuid, ObservedDate, ID_Taxon, ScientificName, CommonName, ObserverDisplayName, PhotoCount, SquareUrl, MediumUrl, Attribution, License)
EXEC dbo.spTaxonomy_ObservationsPage
    @ID_Session         = @ScopedSessionID
  , @ID_Taxon           = 20978
  , @PageSize           = 5
  , @AfterObservedDate  = @LastObservedDate
  , @AfterObservationID = @LastObservationID;
UPDATE #grid_page SET PageNumber = 2 WHERE PageNumber IS NULL;

PRINT '--- 2. pages 1 and 2 (expect 10 rows, newest first, each with a photo url and credit)';
SELECT
    PageNumber
  , ObservedDate
  , ObservationID
  , ScientificName
  , ObserverDisplayName
  , MediumUrl
FROM
    #grid_page
ORDER BY
    PageNumber
  , ObservedDate DESC
  , ObservationID DESC;

PRINT '--- 3. rows that appear on both pages (expect 0)';
SELECT
    COUNT(*) AS duplicated_rows
FROM (
    SELECT ObservationID
    FROM #grid_page
    GROUP BY ObservationID
    HAVING COUNT(*) > 1
) duplicates;

PRINT '--- 4. a taxon outside the scope, Plantae (expect no rows)';
EXEC dbo.spTaxonomy_ObservationsPage @ID_Session = @ScopedSessionID, @ID_Taxon = 47126, @PageSize = 5;

ROLLBACK TRANSACTION;