--=====================================================================================================
--                                        Security spTreeNode_Move
--=====================================================================================================
-- Purpose:  Moves a node under a new parent (or to the top with NULL) and rewrites Path and Level
--           of the node and its whole subtree in one transaction. Refuses to move a node under
--           itself or its descendants. Table name is whitelisted and quoted, values are parameters.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE security.spTreeNode_Move
    @TableName          SYSNAME
  , @ID                 INT
  , @ID_NewParent       INT
  , @ID_UpdatedBy       INT
  
AS BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @TableName NOT IN (N'Group', N'User', N'Resource') BEGIN
        THROW 50001, N'spTreeNode_Move: only Group, User and Resource are tree tables.', 1;
    END

    DECLARE @Sql NVARCHAR(MAX) = N'
DECLARE @OldPath          VARCHAR(850);
DECLARE @OldLevel         INT;
DECLARE @NewParentPath    VARCHAR(850);
DECLARE @NewParentLevel   INT;

SELECT
    @OldPath  = Path
  , @OldLevel = Level
FROM
    security.' + QUOTENAME(@TableName) + N'
WHERE
    ID = @ID;

IF @OldPath IS NULL BEGIN
    THROW 50002, N''spTreeNode_Move: node not found or it has no path yet.'', 1;
END

IF @ID_NewParent IS NOT NULL BEGIN
    SELECT
        @NewParentPath  = Path
      , @NewParentLevel = Level
    FROM
        security.' + QUOTENAME(@TableName) + N'
    WHERE
        ID = @ID_NewParent;

    IF @NewParentPath IS NULL BEGIN
        THROW 50003, N''spTreeNode_Move: new parent not found or it has no path yet.'', 1;
    END

    -- moving a node under itself or one of its descendants would create a loop
    IF @NewParentPath = @OldPath OR @NewParentPath LIKE @OldPath + '',%'' BEGIN
        THROW 50004, N''spTreeNode_Move: a node cannot move under itself or its own descendants.'', 1;
    END
END

DECLARE @NewPath VARCHAR(850) =
    CASE
        WHEN @ID_NewParent IS NULL
            THEN CAST(@ID AS VARCHAR(20))
        ELSE @NewParentPath + '','' + CAST(@ID AS VARCHAR(20))
    END;

DECLARE @LevelDifference INT =
    CASE
        WHEN @ID_NewParent IS NULL
            THEN 1
        ELSE @NewParentLevel + 1
    END - @OldLevel;

BEGIN TRANSACTION;

UPDATE security.' + QUOTENAME(@TableName) + N'
SET
    ID_Parent    = @ID_NewParent
  , ID_UpdatedBy = @ID_UpdatedBy
  , UpdatedDate  = SYSUTCDATETIME()
WHERE
    ID = @ID;

-- the node and its whole subtree: swap the old path prefix for the new one
UPDATE security.' + QUOTENAME(@TableName) + N'
SET
    Path  = @NewPath + SUBSTRING(Path, LEN(@OldPath) + 1, 850)
  , Level = Level + @LevelDifference
WHERE
    Path = @OldPath
OR  Path LIKE @OldPath + '',%'';

COMMIT TRANSACTION;';

    EXEC sys.sp_executesql
        @Sql
      , N'@ID INT, @ID_NewParent INT, @ID_UpdatedBy INT'
      , @ID           = @ID
      , @ID_NewParent = @ID_NewParent
      , @ID_UpdatedBy = @ID_UpdatedBy;
END

GO