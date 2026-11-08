--=====================================================================================================
--                                        dbo Photo
--=====================================================================================================
-- Purpose:  Serving copy of gold dim_photo. One row per photo, a photo shared by several
--           observations appears once. ID is the iNaturalist photo id.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE dbo.Photo (
    ID                  BIGINT                          NOT NULL
  , ID_Observer         INT                             NULL
  , License             VARCHAR(20)                     NOT NULL
  , Extension           VARCHAR(10)                     NOT NULL
  , Width               INT                             NULL
  , Height              INT                             NULL
  , SquareUrl           VARCHAR(300)                    NOT NULL
  , MediumUrl           VARCHAR(300)                    NOT NULL
  , Attribution         NVARCHAR(500)                   NOT NULL
  , SyncedDate          DATETIME2(3)                    NOT NULL    CONSTRAINT DF_Photo_SyncedDate     DEFAULT (SYSUTCDATETIME())
  , CONSTRAINT PK_Photo                   PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT FK_Photo_Observer          FOREIGN KEY (ID_Observer)   REFERENCES dbo.Observer (ID)
);
GO