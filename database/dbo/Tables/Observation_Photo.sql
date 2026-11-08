--=====================================================================================================
--                                        dbo Observation_Photo
--=====================================================================================================
-- Purpose:  Many-to-many bridge between observations and photos, with the photo's position
--           inside the observation. Serving copy of gold bridge_observation_photo.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE dbo.Observation_Photo (
    ID_Observation      INT                             NOT NULL
  , ID_Photo            BIGINT                          NOT NULL
  , PhotoPosition       INT                             NOT NULL
  , CONSTRAINT PK_Observation_Photo           PRIMARY KEY CLUSTERED (ID_Observation, ID_Photo)
  , CONSTRAINT FK_Observation_Photo_Observation FOREIGN KEY (ID_Observation) REFERENCES dbo.Observation (ID)
  , CONSTRAINT FK_Observation_Photo_Photo     FOREIGN KEY (ID_Photo)       REFERENCES dbo.Photo (ID)
);
GO

CREATE NONCLUSTERED INDEX IX_Observation_Photo_Photo ON dbo.Observation_Photo (ID_Photo);
GO