--=====================================================================================================
--                                        Security spTreeNode_SetPath
--=====================================================================================================
-- Purpose:  Sets Path and Level of one node from its parent. Call it right after inserting a node.
--           Works for every tree table (Group, User, Resource). The table name is whitelisted
--           and quoted, the id is passed as a parameter, so nothing can be injected.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE security.spTreeNode_SetPath
    @TableName          SYSNAME
  , @ID                 INT
AS BEGIN
    SET NOCOUNT ON;

    IF @TableName NOT IN (N'Group', N'User', N'Resource') BEGIN
        THROW 50001, N'spTreeNode_SetPath: only Group, User and Resource are tree tables.', 1;
    END

    DECLARE @Sql NVARCHAR(MAX) = N'
UPDATE child_node
SET
    Path  = CASE
                WHEN parent_node.ID IS NULL
                    THEN CAST(child_node.ID AS VARCHAR(20))
                ELSE parent_node.Path + '','' + CAST(child_node.ID AS VARCHAR(20))
            END
  , Level = CASE
                WHEN parent_node.ID IS NULL
                    THEN 1
                ELSE parent_node.Level + 1
            END
FROM
    security.' + QUOTENAME(@TableName) + N' child_node
LEFT JOIN
    security.' + QUOTENAME(@TableName) + N' parent_node
    ON child_node.ID_Parent = parent_node.ID
WHERE
    child_node.ID = @ID;';

    EXEC sys.sp_executesql
        @Sql
      , N'@ID INT'
      , @ID = @ID;
END

GO