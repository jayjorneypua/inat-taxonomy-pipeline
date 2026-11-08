--=====================================================================================================
--                                        Security Role
--=====================================================================================================
-- Purpose:  A named bundle of permissions, assigned to users or groups.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE security.Role (
    ID                  INT             IDENTITY(1, 1)  NOT NULL
  , Name                NVARCHAR(100)                   NOT NULL
  , Description         NVARCHAR(500)                   NULL
  , Active              BIT                             NOT NULL    CONSTRAINT DF_Role_Active                 DEFAULT (1)
  , Deleted             BIT                             NOT NULL    CONSTRAINT DF_Role_Deleted                DEFAULT (0)
  , DisplayOrder        INT                             NOT NULL    CONSTRAINT DF_Role_DisplayOrder           DEFAULT (0)
  , ID_CreatedBy        INT                             NOT NULL
  , CreatedDate         DATETIME2(3)                    NOT NULL    CONSTRAINT DF_Role_CreatedDate            DEFAULT (SYSUTCDATETIME())
  , ID_UpdatedBy        INT                             NULL
  , UpdatedDate         DATETIME2(3)                    NULL
  , CONSTRAINT PK_Role                    PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT FK_Role_CreatedBy          FOREIGN KEY (ID_CreatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT FK_Role_UpdatedBy          FOREIGN KEY (ID_UpdatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT UQ_Role_Name               UNIQUE (Name)
);
GO