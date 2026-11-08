--=====================================================================================================
--                                        Security User_Role
--=====================================================================================================
-- Purpose:  Roles given directly to a user. EndDate allows time limited access
--           and keeps history of past assignments.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE security.User_Role (
    ID                  INT             IDENTITY(1, 1)  NOT NULL
  , ID_User             INT                             NOT NULL
  , ID_Role             INT                             NOT NULL
  , StartDate           DATETIME2(3)                    NOT NULL    CONSTRAINT DF_User_Role_StartDate         DEFAULT (SYSUTCDATETIME())
  , EndDate             DATETIME2(3)                    NULL
  , ID_CreatedBy        INT                             NOT NULL
  , CreatedDate         DATETIME2(3)                    NOT NULL    CONSTRAINT DF_User_Role_CreatedDate       DEFAULT (SYSUTCDATETIME())
  , ID_UpdatedBy        INT                             NULL
  , UpdatedDate         DATETIME2(3)                    NULL
  , CONSTRAINT PK_User_Role               PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT FK_User_Role_User          FOREIGN KEY (ID_User)       REFERENCES security.[User] (ID)
  , CONSTRAINT FK_User_Role_Role          FOREIGN KEY (ID_Role)       REFERENCES security.Role (ID)
  , CONSTRAINT FK_User_Role_CreatedBy     FOREIGN KEY (ID_CreatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT FK_User_Role_UpdatedBy     FOREIGN KEY (ID_UpdatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT CK_User_Role_Dates         CHECK (EndDate IS NULL OR EndDate > StartDate)
);
GO

-- the same role can't be open twice for one user, ended assignments are history
CREATE UNIQUE NONCLUSTERED INDEX UX_User_Role_Current
    ON security.User_Role (ID_User, ID_Role)
    WHERE EndDate IS NULL;
GO

CREATE NONCLUSTERED INDEX IX_User_Role_Role ON security.User_Role (ID_Role);
GO