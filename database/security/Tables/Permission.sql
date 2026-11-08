--=====================================================================================================
--                                        Security Permission
--=====================================================================================================
-- Purpose:  One action on one resource. Code is what the api and ui check,
--           for example observations.export.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE security.Permission (
    ID                  INT             IDENTITY(1, 1)  NOT NULL
  , ID_Resource         INT                             NOT NULL
  , Action              NVARCHAR(50)                    NOT NULL
  , Code                NVARCHAR(200)                   NOT NULL
  , Description         NVARCHAR(500)                   NULL
  , Active              BIT                             NOT NULL    CONSTRAINT DF_Permission_Active           DEFAULT (1)
  , Deleted             BIT                             NOT NULL    CONSTRAINT DF_Permission_Deleted          DEFAULT (0)
  , DisplayOrder        INT                             NOT NULL    CONSTRAINT DF_Permission_DisplayOrder     DEFAULT (0)
  , ID_CreatedBy        INT                             NOT NULL
  , CreatedDate         DATETIME2(3)                    NOT NULL    CONSTRAINT DF_Permission_CreatedDate      DEFAULT (SYSUTCDATETIME())
  , ID_UpdatedBy        INT                             NULL
  , UpdatedDate         DATETIME2(3)                    NULL
  , CONSTRAINT PK_Permission              PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT FK_Permission_Resource     FOREIGN KEY (ID_Resource)   REFERENCES security.Resource (ID)
  , CONSTRAINT FK_Permission_CreatedBy    FOREIGN KEY (ID_CreatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT FK_Permission_UpdatedBy    FOREIGN KEY (ID_UpdatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT UQ_Permission_Code         UNIQUE (Code)
  , CONSTRAINT UQ_Permission_Resource_Action UNIQUE (ID_Resource, Action)
);
GO