--=====================================================================================================
--                                        Security User_Group
--=====================================================================================================
-- Purpose:  Group membership with history. Moving a user closes the old row (EndDate)
--           and opens a new one, so past memberships are kept.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE security.User_Group (
    ID                  INT             IDENTITY(1, 1)  NOT NULL
  , ID_User             INT                             NOT NULL
  , ID_Group            INT                             NOT NULL
  , StartDate           DATETIME2(3)                    NOT NULL    CONSTRAINT DF_User_Group_StartDate     DEFAULT (SYSUTCDATETIME())
  , EndDate             DATETIME2(3)                    NULL
  , ID_CreatedBy        INT                             NOT NULL
  , CreatedDate         DATETIME2(3)                    NOT NULL    CONSTRAINT DF_User_Group_CreatedDate   DEFAULT (SYSUTCDATETIME())
  , ID_UpdatedBy        INT                             NULL
  , UpdatedDate         DATETIME2(3)                    NULL
  , CONSTRAINT PK_User_Group           PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT FK_User_Group_User      FOREIGN KEY (ID_User)       REFERENCES security.[User] (ID)
  , CONSTRAINT FK_User_Group_Group     FOREIGN KEY (ID_Group)      REFERENCES security.[Group] (ID)
  , CONSTRAINT FK_User_Group_CreatedBy FOREIGN KEY (ID_CreatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT FK_User_Group_UpdatedBy FOREIGN KEY (ID_UpdatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT CK_User_Group_Dates     CHECK (EndDate IS NULL OR EndDate > StartDate)
);
GO

-- only one open membership per user and group, closed ones are history
CREATE UNIQUE NONCLUSTERED INDEX UX_User_Group_Current
    ON security.User_Group (ID_User, ID_Group)
    WHERE EndDate IS NULL;
GO

CREATE NONCLUSTERED INDEX IX_User_Group_Group ON security.User_Group (ID_Group);
GO