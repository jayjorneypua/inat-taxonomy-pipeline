--=====================================================================================================
--                                        stage Observer
--=====================================================================================================
-- Purpose:  Landing table for gold dim_observer. Truncated and refilled on every sync.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE stage.Observer (
    ID                  INT                             NULL
  , Login               NVARCHAR(100)                   NULL
  , Name                NVARCHAR(300)                   NULL
  , DisplayName         NVARCHAR(300)                   NULL
);
GO