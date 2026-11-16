--=====================================================================================================
--                                        dbo ExportStatus
--=====================================================================================================
-- Purpose:  Lookup for export job states: Queued, Running, Done, Failed.
-- History:
-- 2026-11-16  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE dbo.ExportStatus (
    ID                  INT             IDENTITY(1, 1)  NOT NULL
  , Name                NVARCHAR(100)                   NOT NULL
  , Description         NVARCHAR(500)                   NULL
  , Active              BIT                             NOT NULL    CONSTRAINT DF_ExportStatus_Active         DEFAULT (1)
  , Deleted             BIT                             NOT NULL    CONSTRAINT DF_ExportStatus_Deleted        DEFAULT (0)
  , DisplayOrder        INT                             NOT NULL    CONSTRAINT DF_ExportStatus_DisplayOrder   DEFAULT (0)
  , ID_CreatedBy        INT                             NOT NULL
  , CreatedDate         DATETIME2(3)                    NOT NULL    CONSTRAINT DF_ExportStatus_CreatedDate    DEFAULT (SYSUTCDATETIME())
  , ID_UpdatedBy        INT                             NULL
  , UpdatedDate         DATETIME2(3)                    NULL
  , CONSTRAINT PK_ExportStatus           PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT FK_ExportStatus_CreatedBy FOREIGN KEY (ID_CreatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT FK_ExportStatus_UpdatedBy FOREIGN KEY (ID_UpdatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT UQ_ExportStatus_Name      UNIQUE (Name)
);
GO
