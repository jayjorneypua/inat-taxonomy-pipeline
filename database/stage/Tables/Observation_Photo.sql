--=====================================================================================================
--                                        stage Observation_Photo
--=====================================================================================================
-- Purpose:  Landing table for gold bridge_observation_photo. Keyed by uuid here, the merge
--           procedure translates it to dbo.Observation.ID. Truncated and refilled on every sync.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE stage.Observation_Photo (
    ObservationUuid     UNIQUEIDENTIFIER                NULL
  , ID_Photo            BIGINT                          NULL
  , PhotoPosition       INT                             NULL
);
GO