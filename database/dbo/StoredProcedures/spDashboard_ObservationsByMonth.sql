--=====================================================================================================
--                                        dbo spDashboard_ObservationsByMonth
--=====================================================================================================
-- Purpose:  Observation counts per month for a taxon's subtree (defaults to the root), for the
--           dashboard line chart. Requires dashboard.view, only counts inside the session's scope.
--           Reads dbo.Taxon_MonthlyCount, where each taxon's count already holds its whole subtree:
--           - taxon inside the scope: its own rows are the answer
--           - scope starts lower down: add up the rows of the highest scope taxa inside the subtree
--             (a scope taxon under another scope taxon is skipped, so nothing is counted twice)
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
-- 2026-11-15  Jay Jorney Pua          Reads the pre-aggregated monthly counts instead of counting observations.
--=====================================================================================================
CREATE PROCEDURE dbo.spDashboard_ObservationsByMonth
    @ID_Session         BIGINT
  , @ID_Taxon           INT             = NULL
  , @ClientIpAddress    VARCHAR(45)     = NULL
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @ID_User        INT;
    DECLARE @RootTaxonID    INT = 48460;
    DECLARE @SelectedPath   VARCHAR(850);

    EXEC security.spSession_CheckAccess
        @ID_Session      = @ID_Session
      , @PermissionCode  = N'dashboard.view'
      , @ClientIpAddress = @ClientIpAddress
      , @ID_User         = @ID_User OUTPUT;

    SET @ID_Taxon = COALESCE(@ID_Taxon, @RootTaxonID);

    SELECT
        @SelectedPath = taxa.Path
    FROM
        dbo.Taxon taxa
    WHERE
        taxa.ID = @ID_Taxon;

    CREATE TABLE #counted_taxa (
        ID                  INT             NOT NULL    PRIMARY KEY
    );

    IF EXISTS (
        SELECT 1
        FROM security.Session_TaxonScope scopes
        WHERE scopes.ID_Session = @ID_Session
        AND (
                @SelectedPath = scopes.TaxonPath
             OR @SelectedPath LIKE scopes.TaxonPath + ',%'
            )
    )
    BEGIN
        -- the selected taxon is inside the scope, so its whole subtree counts
        INSERT INTO #counted_taxa (ID) VALUES (@ID_Taxon);
    END
    ELSE
    BEGIN
        -- the scope starts lower down: the highest scope taxa inside the selected subtree
        INSERT INTO #counted_taxa (
            ID
        )
        SELECT DISTINCT
            scope_taxa.ID
        FROM
            security.Session_TaxonScope scopes
        INNER JOIN
            dbo.Taxon scope_taxa
            ON scope_taxa.Path = scopes.TaxonPath
        WHERE
            scopes.ID_Session = @ID_Session
        AND scopes.TaxonPath LIKE @SelectedPath + ',%'
        AND NOT EXISTS (
                SELECT 1
                FROM security.Session_TaxonScope outer_scopes
                WHERE outer_scopes.ID_Session = @ID_Session
                AND scopes.TaxonPath LIKE outer_scopes.TaxonPath + ',%'
            );
    END

    SELECT
        monthly_counts.MonthStart
      , SUM(monthly_counts.ObservationCount)    AS ObservationCount
    FROM
        dbo.Taxon_MonthlyCount monthly_counts
    INNER JOIN
        #counted_taxa counted_taxa
        ON monthly_counts.ID_Taxon = counted_taxa.ID
    GROUP BY
        monthly_counts.MonthStart
    ORDER BY
        monthly_counts.MonthStart;
END
GO