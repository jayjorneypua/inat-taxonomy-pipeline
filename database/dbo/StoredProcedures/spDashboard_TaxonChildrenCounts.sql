--=====================================================================================================
--                                        dbo spDashboard_TaxonChildrenCounts
--=====================================================================================================
-- Purpose:  Drill-down for the dashboard and the taxonomy tree: the children of a taxon, each with
--           the number of observations in its whole subtree. Defaults to the root (Life).
--           Requires dashboard.view, and only counts observations inside the session's taxon scope.
--           Counts per taxon first, then rolls them up through Path, instead of matching millions
--           of observations against paths.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE dbo.spDashboard_TaxonChildrenCounts
    @ID_Session         BIGINT
  , @ID_ParentTaxon     INT             = NULL
  , @ClientIpAddress    VARCHAR(45)     = NULL
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @ID_User        INT;
    DECLARE @RootTaxonID    INT = 48460;

    EXEC security.spSession_CheckAccess
        @ID_Session      = @ID_Session
      , @PermissionCode  = N'dashboard.view'
      , @ClientIpAddress = @ClientIpAddress
      , @ID_User         = @ID_User OUTPUT;

    SET @ID_ParentTaxon = COALESCE(@ID_ParentTaxon, @RootTaxonID);

    -- observation count per taxon, only for taxa inside the session's scope
    SELECT
        taxa.Path
      , observed_taxa.ObservationCount
    INTO
        #scoped_taxa
    FROM (
        SELECT
            observations.ID_Taxon
          , COUNT(*)                AS ObservationCount
        FROM
            dbo.Observation observations
        GROUP BY
            observations.ID_Taxon
    ) observed_taxa
    INNER JOIN
        dbo.Taxon taxa
        ON observed_taxa.ID_Taxon = taxa.ID
    WHERE
        EXISTS (
            SELECT 1
            FROM security.Session_TaxonScope scopes
            WHERE scopes.ID_Session = @ID_Session
            AND (
                    taxa.Path = scopes.TaxonPath
                 OR taxa.Path LIKE scopes.TaxonPath + ',%'
                )
        );

    -- roll the counts up to each child of the requested taxon
    SELECT
        children.ID
      , children.ScientificName
      , children.CommonName
      , children.Rank
      , children.HasChildren
      , SUM(scoped_taxa.ObservationCount)  AS ObservationCount
    FROM
        dbo.Taxon children
    INNER JOIN
        #scoped_taxa scoped_taxa
        ON scoped_taxa.Path = children.Path
        OR scoped_taxa.Path LIKE children.Path + ',%'
    WHERE
        children.ID_Parent = @ID_ParentTaxon
    AND children.IsInTree = 1
    GROUP BY
        children.ID
      , children.ScientificName
      , children.CommonName
      , children.Rank
      , children.HasChildren
    ORDER BY
        ObservationCount DESC;
END
GO