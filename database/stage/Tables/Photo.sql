--=====================================================================================================
--                                        stage Photo
--=====================================================================================================
-- Purpose:  Landing table for gold dim_photo. Truncated and refilled on every sync.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE stage.Photo (
    ID                  BIGINT                          NULL
  , ID_Observer         INT                             NULL
  , License             VARCHAR(20)                     NULL
  , Extension           VARCHAR(10)                     NULL
  , Width               INT                             NULL
  , Height              INT                             NULL
  , SquareUrl           VARCHAR(300)                    NULL
  , MediumUrl           VARCHAR(300)                    NULL
  , Attribution         NVARCHAR(500)                   NULL
);
GO