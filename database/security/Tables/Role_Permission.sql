--=====================================================================================================
--                                        Security Role_Permission
--=====================================================================================================
-- Purpose:  Which permissions each role has.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE security.Role_Permission (
    ID                  INT             IDENTITY(1, 1)  NOT NULL
  , ID_Role             INT                             NOT NULL
  , ID_Permission       INT                             NOT NULL
  , ID_CreatedBy        INT                             NOT NULL
  , CreatedDate         DATETIME2(3)                    NOT NULL    CONSTRAINT DF_Role_Permission_CreatedDate DEFAULT (SYSUTCDATETIME())
  , CONSTRAINT PK_Role_Permission             PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT FK_Role_Permission_Role        FOREIGN KEY (ID_Role)       REFERENCES security.Role (ID)
  , CONSTRAINT FK_Role_Permission_Permission  FOREIGN KEY (ID_Permission) REFERENCES security.Permission (ID)
  , CONSTRAINT FK_Role_Permission_CreatedBy   FOREIGN KEY (ID_CreatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT UQ_Role_Permission             UNIQUE (ID_Role, ID_Permission)
);
GO

CREATE NONCLUSTERED INDEX IX_Role_Permission_Permission ON security.Role_Permission (ID_Permission);
GO