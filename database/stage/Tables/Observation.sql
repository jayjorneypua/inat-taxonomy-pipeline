--=====================================================================================================
--                                        stage Observation
--=====================================================================================================
-- Purpose:  Landing table for gold fct_observations. Truncated and refilled on every sync.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE stage.Observation (
    ObservationUuid     UNIQUEIDENTIFIER                NULL
  , InatObservationID   BIGINT                          NULL
  , ID_Taxon            INT                             NULL
  , ID_Observer         INT                             NULL
  , ObservedDate        DATE                            NULL
  , Latitude            DECIMAL(10, 7)                  NULL
  , Longitude           DECIMAL(10, 7)                  NULL
  , PositionalAccuracy  INT                             NULL
  , PhotoCount          INT                             NULL
  , Source              VARCHAR(10)                     NULL
  , UpdatedDate         DATETIME2(3)                    NULL
);
GO