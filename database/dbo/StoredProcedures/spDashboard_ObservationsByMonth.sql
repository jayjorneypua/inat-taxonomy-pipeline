--=====================================================================================================
--                                        dbo spDashboard_ObservationsByMonth
--=====================================================================================================
-- Purpose:  Observation counts per month for a taxon's subtree (defaults to the root), for the
--           dashboard line chart. Requires dashboard.view, only counts inside the session's scope.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE dbo.spDashboard_ObservationsByMonth
    @ID_Session         BIGINT
  , @ID_Taxon           INT             = NULL
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

    SET @ID_Taxon = COALESCE(@ID_Taxon, @RootTaxonID);

    SELECT
        scoped_taxa.ID
    INTO
        #scoped_taxa
    FROM
        dbo.fnSession_ScopedSubtreeTaxa(@ID_Session, @ID_Taxon) scoped_taxa;

    CREATE CLUSTERED INDEX IX_scoped_taxa ON #scoped_taxa (ID);

    SELECT
        DATEFROMPARTS(YEAR(observations.ObservedDate), MONTH(observations.ObservedDate), 1)   AS MonthStart
      , COUNT(*)                                                                              AS ObservationCount
    FROM
        dbo.Observation observations
    INNER JOIN
        #scoped_taxa scoped_taxa
        ON observations.ID_Taxon = scoped_taxa.ID
    GROUP BY
        DATEFROMPARTS(YEAR(observations.ObservedDate), MONTH(observations.ObservedDate), 1)
    ORDER BY
        MonthStart;
END
GO