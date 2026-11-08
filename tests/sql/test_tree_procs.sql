-- tests the tree procs with sample groups inside a transaction that is rolled back at the end,
-- so no test data stays in the database
USE inat;
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

BEGIN TRANSACTION;

DECLARE @OrganizationTypeID INT = (SELECT ID FROM security.GroupType WHERE Name = N'Organization');
DECLARE @DepartmentTypeID   INT = (SELECT ID FROM security.GroupType WHERE Name = N'Department');
DECLARE @LocationTypeID     INT = (SELECT ID FROM security.GroupType WHERE Name = N'Location');
DECLARE @PandaID            INT;
DECLARE @MokongID           INT;
DECLARE @FinanceID          INT;
DECLARE @ManilaID           INT;

INSERT INTO security.[Group] (ID_Parent, ID_GroupType, Name, ID_CreatedBy) VALUES (NULL, @OrganizationTypeID, N'Panda', 1);
SET @PandaID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Group', @ID = @PandaID;

INSERT INTO security.[Group] (ID_Parent, ID_GroupType, Name, ID_CreatedBy) VALUES (NULL, @OrganizationTypeID, N'Mokong', 1);
SET @MokongID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Group', @ID = @MokongID;

INSERT INTO security.[Group] (ID_Parent, ID_GroupType, Name, ID_CreatedBy) VALUES (@PandaID, @DepartmentTypeID, N'Finance', 1);
SET @FinanceID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Group', @ID = @FinanceID;

INSERT INTO security.[Group] (ID_Parent, ID_GroupType, Name, ID_CreatedBy) VALUES (@FinanceID, @LocationTypeID, N'Manila', 1);
SET @ManilaID = SCOPE_IDENTITY();
EXEC security.spTreeNode_SetPath @TableName = N'Group', @ID = @ManilaID;

PRINT '--- before the move: Finance and Manila are under Panda';
SELECT
    Name
  , Path
  , Level
FROM
    security.[Group]
ORDER BY
    Path;

-- move Finance (and Manila with it) under Mokong
EXEC security.spTreeNode_Move
    @TableName    = N'Group'
  , @ID           = @FinanceID
  , @ID_NewParent = @MokongID
  , @ID_UpdatedBy = 1;

PRINT '--- after the move: Finance and Manila are under Mokong';
SELECT
    Name
  , Path
  , Level
FROM
    security.[Group]
ORDER BY
    Path;

-- try to move Mokong under Manila, its own descendant: must be refused
BEGIN TRY
    EXEC security.spTreeNode_Move
        @TableName    = N'Group'
      , @ID           = @MokongID
      , @ID_NewParent = @ManilaID
      , @ID_UpdatedBy = 1;

    PRINT '--- FAILED: the loop was allowed';
END TRY
BEGIN CATCH
    PRINT '--- correctly refused: ' + ERROR_MESSAGE();
END CATCH

-- try a table that is not on the whitelist: must be refused
BEGIN TRY
    EXEC security.spTreeNode_SetPath @TableName = N'Session', @ID = 1;

    PRINT '--- FAILED: a non tree table was allowed';
END TRY
BEGIN CATCH
    PRINT '--- correctly refused: ' + ERROR_MESSAGE();
END CATCH

ROLLBACK TRANSACTION;