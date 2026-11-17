--=====================================================================================================
--                                        Security spUser_Grid
--=====================================================================================================
-- Purpose:  The admin users grid: offset paging, search, json filters and sorting, returning the page
--           with TotalCount (every matching row, not just this page). Requires admin.users.manage.
--           Search matches username, names, email, group names and role names.
--           Status is Locked, Inactive or Active (in that order of priority), and the Status "in" filter
--           takes a comma separated list, so the page can ask for any combination.
--           Safe dynamic sql:
--             - sort column and direction come from a whitelist, anything else is refused
--             - each filter must match an allowed column and operator pair, which maps to a fixed
--               piece of sql; the json only chooses from that list
--             - filter and search values are passed to sp_executesql as parameters, never as text
--             - LIKE wildcards (% _ [) in values are escaped, so a search for _ means a literal _
--           Signed with the ProcSigning certificate (see PostDeployment.sql): ownership chaining doesn't
--           cover dynamic sql, and the api login has no table access. The certificate's user may only read
--           the five security tables the query uses, and the only variable sql text comes from the whitelists above.
--           Only accounts that can log in are listed, so the System account never shows up.
-- History:
-- 2026-11-15  Jay Jorney Pua          Created the procedure.
-- 2026-11-15  Jay Jorney Pua          WITH EXECUTE AS OWNER: ownership chaining doesn't cover dynamic sql.
-- 2026-11-15  Jay Jorney Pua          Search matches groups and roles, contains filters, Status in filter.
-- 2026-11-17  Jay Jorney Pua          Certificate signing instead of WITH EXECUTE AS OWNER.
--=====================================================================================================
CREATE PROCEDURE security.spUser_Grid
    @ID_Session             BIGINT
  , @Page                   INT             = 1
  , @PageSize               INT             = 25
  , @Search                 NVARCHAR(100)   = NULL
  , @Filters                NVARCHAR(MAX)   = NULL
  , @SortColumn             NVARCHAR(50)    = N'Username'
  , @SortDirection          NVARCHAR(4)     = N'asc'
  , @ClientIpAddress        VARCHAR(45)     = NULL
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @ID_User                INT;
    DECLARE @MaxFilters             INT             = 10;
    DECLARE @OrderByExpression      NVARCHAR(100);
    DECLARE @SortDirectionKeyword   NVARCHAR(4);
    DECLARE @SearchPattern          NVARCHAR(400);
    DECLARE @WhereClause            NVARCHAR(MAX);
    DECLARE @InvalidFilter          NVARCHAR(100);
    DECLARE @Message                NVARCHAR(400);
    DECLARE @Sql                    NVARCHAR(MAX);
    DECLARE @FilterValue0           NVARCHAR(800);
    DECLARE @FilterValue1           NVARCHAR(800);
    DECLARE @FilterValue2           NVARCHAR(800);
    DECLARE @FilterValue3           NVARCHAR(800);
    DECLARE @FilterValue4           NVARCHAR(800);
    DECLARE @FilterValue5           NVARCHAR(800);
    DECLARE @FilterValue6           NVARCHAR(800);
    DECLARE @FilterValue7           NVARCHAR(800);
    DECLARE @FilterValue8           NVARCHAR(800);
    DECLARE @FilterValue9           NVARCHAR(800);

    EXEC security.spSession_CheckAccess
        @ID_Session      = @ID_Session
      , @PermissionCode  = N'admin.users.manage'
      , @ClientIpAddress = @ClientIpAddress
      , @ID_User         = @ID_User OUTPUT;

    ------------------------------------------------------------------------------------
    -- paging
    ------------------------------------------------------------------------------------
    SET @Page =
        CASE
            WHEN @Page IS NULL OR @Page < 1 THEN 1
            ELSE @Page
        END;

    SET @PageSize =
        CASE
            WHEN @PageSize IS NULL THEN 25
            WHEN @PageSize < 1     THEN 1
            WHEN @PageSize > 100   THEN 100
            ELSE @PageSize
        END;

    ------------------------------------------------------------------------------------
    -- sorting: whitelist only
    ------------------------------------------------------------------------------------
    SET @OrderByExpression =
        CASE @SortColumn
            WHEN N'Username'      THEN N'user_rows.Username'
            WHEN N'FirstName'     THEN N'user_rows.FirstName'
            WHEN N'LastName'      THEN N'user_rows.LastName'
            WHEN N'Email'         THEN N'user_rows.Email'
            WHEN N'LastLoginDate' THEN N'user_rows.LastLoginDate'
            WHEN N'LoginCount'    THEN N'user_rows.LoginCount'
        END;

    IF @OrderByExpression IS NULL BEGIN
        SET @Message = CONCAT(N'spUser_Grid: ', @SortColumn, N' is not a sortable column.');
        THROW 50040, @Message, 1;
    END

    SET @SortDirectionKeyword =
        CASE LOWER(@SortDirection)
            WHEN N'asc'  THEN N'ASC'
            WHEN N'desc' THEN N'DESC'
        END;

    IF @SortDirectionKeyword IS NULL BEGIN
        THROW 50041, N'spUser_Grid: sort direction must be asc or desc.', 1;
    END

    ------------------------------------------------------------------------------------
    -- search: escaped so % _ [ are literal characters
    ------------------------------------------------------------------------------------
    IF @Search IS NOT NULL AND TRIM(@Search) <> N'' BEGIN
        SET @SearchPattern =
            N'%'
          + REPLACE(REPLACE(REPLACE(TRIM(@Search), N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]')
          + N'%';
    END

    ------------------------------------------------------------------------------------
    -- filters: parsed from json, checked against the allowed list
    ------------------------------------------------------------------------------------
    CREATE TABLE #filters (
        FilterNumber        INT             IDENTITY(0, 1)  NOT NULL
      , ColumnName          NVARCHAR(50)                    NULL
      , Operator            NVARCHAR(20)                    NULL
      , FilterValue         NVARCHAR(200)                   NULL
      , ParameterValue      NVARCHAR(800)                   NULL
    );

    IF @Filters IS NOT NULL BEGIN
        IF ISJSON(@Filters) = 0 BEGIN
            THROW 50042, N'spUser_Grid: filters must be valid json.', 1;
        END

        INSERT INTO #filters (
            ColumnName
          , Operator
          , FilterValue
        )
        SELECT
            filter_items.ColumnName
          , LOWER(filter_items.Operator)
          , filter_items.FilterValue
        FROM
            OPENJSON(@Filters)
            WITH (
                ColumnName      NVARCHAR(50)    '$.column'
              , Operator        NVARCHAR(20)    '$.operator'
              , FilterValue     NVARCHAR(200)   '$.value'
            ) filter_items;
    END

    IF (SELECT COUNT(*) FROM #filters) > @MaxFilters BEGIN
        THROW 50043, N'spUser_Grid: no more than 10 filters are allowed.', 1;
    END

    -- the value each operator compares with: wildcards added for contains and startswith,
    -- after escaping the user's own wildcards. eq and in use the value as it is
    UPDATE #filters
    SET
        ParameterValue =
            CASE Operator
                WHEN N'contains'
                    THEN N'%' + REPLACE(REPLACE(REPLACE(FilterValue, N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%'
                WHEN N'startswith'
                    THEN REPLACE(REPLACE(REPLACE(FilterValue, N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%'
                ELSE FilterValue
            END;

    -- the only column and operator pairs allowed, each a fixed piece of sql.
    -- {value} becomes a parameter name, never the user's text
    CREATE TABLE #allowed_filters (
        ColumnName          NVARCHAR(50)    NOT NULL
      , Operator            NVARCHAR(20)    NOT NULL
      , PredicateTemplate   NVARCHAR(1000)  NOT NULL
    );

    INSERT INTO #allowed_filters (
        ColumnName
      , Operator
      , PredicateTemplate
    )
    VALUES
        (N'Username',  N'eq',         N'user_rows.Username = {value}')
      , (N'Username',  N'contains',   N'user_rows.Username LIKE {value}')
      , (N'Username',  N'startswith', N'user_rows.Username LIKE {value}')
      , (N'Email',     N'eq',         N'user_rows.Email = {value}')
      , (N'Email',     N'contains',   N'user_rows.Email LIKE {value}')
      , (N'Email',     N'startswith', N'user_rows.Email LIKE {value}')
      , (N'FirstName', N'eq',         N'user_rows.FirstName = {value}')
      , (N'FirstName', N'contains',   N'user_rows.FirstName LIKE {value}')
      , (N'FirstName', N'startswith', N'user_rows.FirstName LIKE {value}')
      , (N'LastName',  N'eq',         N'user_rows.LastName = {value}')
      , (N'LastName',  N'contains',   N'user_rows.LastName LIKE {value}')
      , (N'LastName',  N'startswith', N'user_rows.LastName LIKE {value}')
      , (N'Status',    N'in',         N'user_rows.Status IN (SELECT TRIM(status_values.value) FROM STRING_SPLIT({value}, N'','') status_values)')
      , (N'GroupName', N'eq',         N'EXISTS (SELECT 1 FROM security.User_Group memberships INNER JOIN security.[Group] member_groups ON memberships.ID_Group = member_groups.ID WHERE memberships.ID_User = user_rows.ID AND memberships.EndDate IS NULL AND member_groups.Name = {value})')
      , (N'GroupName', N'contains',   N'EXISTS (SELECT 1 FROM security.User_Group memberships INNER JOIN security.[Group] member_groups ON memberships.ID_Group = member_groups.ID WHERE memberships.ID_User = user_rows.ID AND memberships.EndDate IS NULL AND member_groups.Name LIKE {value})')
      , (N'RoleName',  N'eq',         N'EXISTS (SELECT 1 FROM security.User_Role user_roles INNER JOIN security.Role roles ON user_roles.ID_Role = roles.ID WHERE user_roles.ID_User = user_rows.ID AND user_roles.EndDate IS NULL AND roles.Name = {value})')
      , (N'RoleName',  N'contains',   N'EXISTS (SELECT 1 FROM security.User_Role user_roles INNER JOIN security.Role roles ON user_roles.ID_Role = roles.ID WHERE user_roles.ID_User = user_rows.ID AND user_roles.EndDate IS NULL AND roles.Name LIKE {value})');

    SELECT TOP (1)
        @InvalidFilter = CONCAT(requested_filters.ColumnName, N' ', requested_filters.Operator)
    FROM
        #filters requested_filters
    WHERE
        NOT EXISTS (
            SELECT 1
            FROM #allowed_filters allowed_filters
            WHERE allowed_filters.ColumnName = requested_filters.ColumnName
            AND allowed_filters.Operator = requested_filters.Operator
        );

    IF @InvalidFilter IS NOT NULL BEGIN
        SET @Message = CONCAT(N'spUser_Grid: filter "', @InvalidFilter, N'" is not allowed.');
        THROW 50044, @Message, 1;
    END

    SELECT
        @WhereClause = STRING_AGG(
            CAST(N' AND ' + REPLACE(allowed_filters.PredicateTemplate, N'{value}', N'@FilterValue' + CAST(requested_filters.FilterNumber AS NVARCHAR(2))) AS NVARCHAR(MAX))
          , N''
        ) WITHIN GROUP (ORDER BY requested_filters.FilterNumber)
    FROM
        #filters requested_filters
    INNER JOIN
        #allowed_filters allowed_filters
        ON allowed_filters.ColumnName = requested_filters.ColumnName
        AND allowed_filters.Operator = requested_filters.Operator;

    SET @WhereClause = COALESCE(@WhereClause, N'');

    SET @FilterValue0 = (SELECT ParameterValue FROM #filters WHERE FilterNumber = 0);
    SET @FilterValue1 = (SELECT ParameterValue FROM #filters WHERE FilterNumber = 1);
    SET @FilterValue2 = (SELECT ParameterValue FROM #filters WHERE FilterNumber = 2);
    SET @FilterValue3 = (SELECT ParameterValue FROM #filters WHERE FilterNumber = 3);
    SET @FilterValue4 = (SELECT ParameterValue FROM #filters WHERE FilterNumber = 4);
    SET @FilterValue5 = (SELECT ParameterValue FROM #filters WHERE FilterNumber = 5);
    SET @FilterValue6 = (SELECT ParameterValue FROM #filters WHERE FilterNumber = 6);
    SET @FilterValue7 = (SELECT ParameterValue FROM #filters WHERE FilterNumber = 7);
    SET @FilterValue8 = (SELECT ParameterValue FROM #filters WHERE FilterNumber = 8);
    SET @FilterValue9 = (SELECT ParameterValue FROM #filters WHERE FilterNumber = 9);

    ------------------------------------------------------------------------------------
    -- the query: every piece of text below is either constant or from a whitelist
    ------------------------------------------------------------------------------------
    SET @Sql = N'
WITH user_rows AS (
    SELECT
        users.ID
      , users.Username
      , users.FirstName
      , users.LastName
      , users.Email
      , users.Active
      , users.LoginCount
      , users.LastLoginDate
      , CAST(CASE WHEN users.LockedUntil > SYSUTCDATETIME() THEN 1 ELSE 0 END AS BIT) AS IsLocked
      , CASE
            WHEN users.LockedUntil > SYSUTCDATETIME() THEN N''Locked''
            WHEN users.Active = 0 THEN N''Inactive''
            ELSE N''Active''
        END                                 AS Status
    FROM
        security.[User] users
    WHERE
        users.Deleted = 0
    AND users.PasswordHash IS NOT NULL
)
SELECT
    user_rows.ID
  , user_rows.Username
  , user_rows.FirstName
  , user_rows.LastName
  , user_rows.Email
  , user_rows.Active
  , user_rows.IsLocked
  , user_rows.LoginCount
  , user_rows.LastLoginDate
  , (
        SELECT
            STRING_AGG(member_groups.Name, N'', '') WITHIN GROUP (ORDER BY member_groups.Name)
        FROM
            security.User_Group memberships
        INNER JOIN
            security.[Group] member_groups
            ON memberships.ID_Group = member_groups.ID
        WHERE
            memberships.ID_User = user_rows.ID
        AND memberships.EndDate IS NULL
    )                                       AS GroupNames
  , (
        SELECT
            STRING_AGG(roles.Name, N'', '') WITHIN GROUP (ORDER BY roles.Name)
        FROM
            security.User_Role user_roles
        INNER JOIN
            security.Role roles
            ON user_roles.ID_Role = roles.ID
        WHERE
            user_roles.ID_User = user_rows.ID
        AND user_roles.EndDate IS NULL
    )                                       AS RoleNames
  , COUNT(*) OVER ()                        AS TotalCount
FROM
    user_rows
WHERE
    (
        @SearchPattern IS NULL
     OR user_rows.Username LIKE @SearchPattern
     OR user_rows.FirstName LIKE @SearchPattern
     OR user_rows.LastName LIKE @SearchPattern
     OR user_rows.Email LIKE @SearchPattern
     OR EXISTS (
            SELECT 1
            FROM security.User_Group memberships
            INNER JOIN security.[Group] member_groups
                ON memberships.ID_Group = member_groups.ID
            WHERE memberships.ID_User = user_rows.ID
            AND memberships.EndDate IS NULL
            AND member_groups.Name LIKE @SearchPattern
        )
     OR EXISTS (
            SELECT 1
            FROM security.User_Role user_roles
            INNER JOIN security.Role roles
                ON user_roles.ID_Role = roles.ID
            WHERE user_roles.ID_User = user_rows.ID
            AND user_roles.EndDate IS NULL
            AND roles.Name LIKE @SearchPattern
        )
    )' + @WhereClause + N'
ORDER BY
    ' + @OrderByExpression + N' ' + @SortDirectionKeyword + N'
  , user_rows.ID
OFFSET (@Page - 1) * @PageSize ROWS
FETCH NEXT @PageSize ROWS ONLY;';

    EXEC sys.sp_executesql
        @Sql
      , N'@SearchPattern NVARCHAR(400), @Page INT, @PageSize INT
        , @FilterValue0 NVARCHAR(800), @FilterValue1 NVARCHAR(800), @FilterValue2 NVARCHAR(800), @FilterValue3 NVARCHAR(800), @FilterValue4 NVARCHAR(800)
        , @FilterValue5 NVARCHAR(800), @FilterValue6 NVARCHAR(800), @FilterValue7 NVARCHAR(800), @FilterValue8 NVARCHAR(800), @FilterValue9 NVARCHAR(800)'
      , @SearchPattern = @SearchPattern
      , @Page          = @Page
      , @PageSize      = @PageSize
      , @FilterValue0  = @FilterValue0
      , @FilterValue1  = @FilterValue1
      , @FilterValue2  = @FilterValue2
      , @FilterValue3  = @FilterValue3
      , @FilterValue4  = @FilterValue4
      , @FilterValue5  = @FilterValue5
      , @FilterValue6  = @FilterValue6
      , @FilterValue7  = @FilterValue7
      , @FilterValue8  = @FilterValue8
      , @FilterValue9  = @FilterValue9;
END
GO