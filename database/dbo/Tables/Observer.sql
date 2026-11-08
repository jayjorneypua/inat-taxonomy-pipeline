--=====================================================================================================
--                                        dbo Observer
--=====================================================================================================
-- Purpose:  Serving copy of gold dim_observer. ID is the iNaturalist observer id.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE dbo.Observer (
    ID                  INT                             NOT NULL
  , Login               NVARCHAR(100)                   NOT NULL
  , Name                NVARCHAR(300)                   NULL
  , DisplayName         NVARCHAR(300)                   NOT NULL
  , SyncedDate          DATETIME2(3)                    NOT NULL    CONSTRAINT DF_Observer_SyncedDate  DEFAULT (SYSUTCDATETIME())
  , CONSTRAINT PK_Observer                PRIMARY KEY CLUSTERED (ID)
);
GO