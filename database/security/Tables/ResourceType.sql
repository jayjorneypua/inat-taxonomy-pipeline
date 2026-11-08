--=====================================================================================================
--                                        Security ResourceType
--=====================================================================================================
-- Purpose:  Lookup for resource kinds: Page, Button, Api.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE security.ResourceType (
    ID                  INT             IDENTITY(1, 1)  NOT NULL
  , Name                NVARCHAR(100)                   NOT NULL
  , Description         NVARCHAR(500)                   NULL
  , Active              BIT                             NOT NULL    CONSTRAINT DF_ResourceType_Active         DEFAULT (1)
  , Deleted             BIT                             NOT NULL    CONSTRAINT DF_ResourceType_Deleted        DEFAULT (0)
  , DisplayOrder        INT                             NOT NULL    CONSTRAINT DF_ResourceType_DisplayOrder   DEFAULT (0)
  , ID_CreatedBy        INT                             NOT NULL
  , CreatedDate         DATETIME2(3)                    NOT NULL    CONSTRAINT DF_ResourceType_CreatedDate    DEFAULT (SYSUTCDATETIME())
  , ID_UpdatedBy        INT                             NULL
  , UpdatedDate         DATETIME2(3)                    NULL
  , CONSTRAINT PK_ResourceType            PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT FK_ResourceType_CreatedBy  FOREIGN KEY (ID_CreatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT FK_ResourceType_UpdatedBy  FOREIGN KEY (ID_UpdatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT UQ_ResourceType_Name       UNIQUE (Name)
);
GO