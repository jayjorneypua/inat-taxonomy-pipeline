--=====================================================================================================
--                                        stage Taxon
--=====================================================================================================
-- Purpose:  Landing table for gold dim_taxon. No keys or constraints so bulk loads are fast.
--           Truncated and refilled on every sync, read only by the merge procedures.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE stage.Taxon (
    ID                  INT                             NULL
  , ID_Parent           INT                             NULL
  , ScientificName      NVARCHAR(300)                   NULL
  , CommonName          NVARCHAR(300)                   NULL
  , Rank                NVARCHAR(50)                    NULL
  , RankLevel           DECIMAL(4, 1)                   NULL
  , Path                VARCHAR(850)                    NULL
  , Level               INT                             NULL
  , HasChildren         BIT                             NULL
  , Active              BIT                             NULL
  , IsInTree            BIT                             NULL
  , SnapshotDate        DATE                            NULL
);
GO