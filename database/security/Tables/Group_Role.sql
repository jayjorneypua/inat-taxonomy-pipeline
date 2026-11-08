--=====================================================================================================
--                                        Security Group_Role
--=====================================================================================================
-- Purpose:  Roles given to everyone in a group and in the groups under it (found through Path).
--           EndDate allows time limited access and keeps history.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE security.Group_Role (
    ID                  INT             IDENTITY(1, 1)  NOT NULL
  , ID_Group            INT                             NOT NULL
  , ID_Role             INT                             NOT NULL
  , StartDate           DATETIME2(3)                    NOT NULL    CONSTRAINT DF_Group_Role_StartDate        DEFAULT (SYSUTCDATETIME())
  , EndDate             DATETIME2(3)                    NULL
  , ID_CreatedBy        INT                             NOT NULL
  , CreatedDate         DATETIME2(3)                    NOT NULL    CONSTRAINT DF_Group_Role_CreatedDate      DEFAULT (SYSUTCDATETIME())
  , ID_UpdatedBy        INT                             NULL
  , UpdatedDate         DATETIME2(3)                    NULL
  , CONSTRAINT PK_Group_Role              PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT FK_Group_Role_Group        FOREIGN KEY (ID_Group)      REFERENCES security.[Group] (ID)
  , CONSTRAINT FK_Group_Role_Role         FOREIGN KEY (ID_Role)       REFERENCES security.Role (ID)
  , CONSTRAINT FK_Group_Role_CreatedBy    FOREIGN KEY (ID_CreatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT FK_Group_Role_UpdatedBy    FOREIGN KEY (ID_UpdatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT CK_Group_Role_Dates        CHECK (EndDate IS NULL OR EndDate > StartDate)
);
GO

CREATE UNIQUE NONCLUSTERED INDEX UX_Group_Role_Current
    ON security.Group_Role (ID_Group, ID_Role)
    WHERE EndDate IS NULL;
GO

CREATE NONCLUSTERED INDEX IX_Group_Role_Role ON security.Group_Role (ID_Role);
GO