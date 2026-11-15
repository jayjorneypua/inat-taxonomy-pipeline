--=====================================================================================================
--                                        sync spTaxonMonthlyCount_Refresh
--=====================================================================================================
-- Purpose:  Rebuilds dbo.Taxon_MonthlyCount from dbo.Observation.
--           1. counts observations per taxon per month (only the taxon itself)
--           2. rolls every count up to the taxon and all its ancestors: Path holds the ancestor ids
--              (self included), so STRING_SPLIT on Path gives every taxon the count belongs to
--           3. swaps the result in with TRUNCATE + INSERT in one short transaction
--           Taxa without a Path (not in the tree) are left out, same as the live query did.
--           EXECUTE AS OWNER because TRUNCATE needs ALTER on the table.
-- History:
-- 2026-11-15  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE sync.spTaxonMonthlyCount_Refresh
WITH EXECUTE AS OWNER
AS BEGIN
    SET NOCOUNT ON;

    SELECT
        observations.ID_Taxon
      , DATEFROMPARTS(YEAR(observations.ObservedDate), MONTH(observations.ObservedDate), 1)   AS MonthStart
      , COUNT(*)                                                                              AS ObservationCount
    INTO
        #direct_counts
    FROM
        dbo.Observation observations
    GROUP BY
        observations.ID_Taxon
      , DATEFROMPARTS(YEAR(observations.ObservedDate), MONTH(observations.ObservedDate), 1);

    SELECT
        CAST(ancestors.value AS INT)            AS ID_Taxon
      , direct_counts.MonthStart
      , SUM(direct_counts.ObservationCount)     AS ObservationCount
    INTO
        #rollup_counts
    FROM
        #direct_counts direct_counts
    INNER JOIN
        dbo.Taxon taxa
        ON taxa.ID = direct_counts.ID_Taxon
    CROSS APPLY
        STRING_SPLIT(taxa.Path, ',') ancestors
    WHERE
        taxa.Path IS NOT NULL
    GROUP BY
        CAST(ancestors.value AS INT)
      , direct_counts.MonthStart;

    BEGIN TRANSACTION;

    TRUNCATE TABLE dbo.Taxon_MonthlyCount;

    INSERT INTO dbo.Taxon_MonthlyCount WITH (TABLOCK) (
        ID_Taxon
      , MonthStart
      , ObservationCount
    )
    SELECT
        rollup_counts.ID_Taxon
      , rollup_counts.MonthStart
      , rollup_counts.ObservationCount
    FROM
        #rollup_counts rollup_counts;

    COMMIT TRANSACTION;
END
GO