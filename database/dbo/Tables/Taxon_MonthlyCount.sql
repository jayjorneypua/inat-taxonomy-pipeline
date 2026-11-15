--=====================================================================================================
--                                        dbo Taxon_MonthlyCount
--=====================================================================================================
-- Purpose:  Observation counts per taxon per month, where each taxon's count includes its whole
--           subtree (Animalia's count holds every animal). Rebuilt by sync.spTaxonMonthlyCount_Refresh
--           at the end of every sync, so the dashboard chart reads a few hundred rows instead of
--           counting millions of observations.
-- History:
-- 2026-11-15  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE dbo.Taxon_MonthlyCount (
    ID_Taxon            INT                             NOT NULL
  , MonthStart          DATE                            NOT NULL
  , ObservationCount    INT                             NOT NULL
  , CONSTRAINT PK_Taxon_MonthlyCount      PRIMARY KEY CLUSTERED (ID_Taxon, MonthStart)
);
GO