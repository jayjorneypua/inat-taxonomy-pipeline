--=====================================================================================================
--                                        Security Resource
--=====================================================================================================
-- Purpose:  Pages, buttons and api endpoints as one tree (a page contains its buttons).
--           Code is the stable name the api and ui use, for example page.taxonomy.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE security.Resource (
    ID                  INT             IDENTITY(1, 1)  NOT NULL
  , ID_Parent           INT                             NULL
  , ID_ResourceType     INT                             NOT NULL
  , Code                NVARCHAR(200)                   NOT NULL
  , Name                NVARCHAR(200)                   NOT NULL
  , Description         NVARCHAR(500)                   NULL
  , Path                VARCHAR(850)                    NULL
  , Level               INT                             NULL
  , Active              BIT                             NOT NULL    CONSTRAINT DF_Resource_Active             DEFAULT (1)
  , Deleted             BIT                             NOT NULL    CONSTRAINT DF_Resource_Deleted            DEFAULT (0)
  , DisplayOrder        INT                             NOT NULL    CONSTRAINT DF_Resource_DisplayOrder       DEFAULT (0)
  , ID_CreatedBy        INT                             NOT NULL
  , CreatedDate         DATETIME2(3)                    NOT NULL    CONSTRAINT DF_Resource_CreatedDate        DEFAULT (SYSUTCDATETIME())
  , ID_UpdatedBy        INT                             NULL
  , UpdatedDate         DATETIME2(3)                    NULL
  , CONSTRAINT PK_Resource                PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT FK_Resource_Parent         FOREIGN KEY (ID_Parent)         REFERENCES security.Resource (ID)
  , CONSTRAINT FK_Resource_ResourceType   FOREIGN KEY (ID_ResourceType)   REFERENCES security.ResourceType (ID)
  , CONSTRAINT FK_Resource_CreatedBy      FOREIGN KEY (ID_CreatedBy)      REFERENCES security.[User] (ID)
  , CONSTRAINT FK_Resource_UpdatedBy      FOREIGN KEY (ID_UpdatedBy)      REFERENCES security.[User] (ID)
  , CONSTRAINT UQ_Resource_Code           UNIQUE (Code)
);
GO

CREATE NONCLUSTERED INDEX IX_Resource_Path ON security.Resource (Path);
GO