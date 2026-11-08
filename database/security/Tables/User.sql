--=====================================================================================================
--                                        Security User
--=====================================================================================================
-- Purpose:  People who can log in, with a reporting line (ID_Parent, Path, Level).
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE security.[User] (
    ID                  INT             IDENTITY(1, 1)  NOT NULL
  , ID_Parent           INT                             NULL
  , FirstName           NVARCHAR(100)                   NOT NULL
  , MiddleName          NVARCHAR(100)                   NULL
  , LastName            NVARCHAR(100)                   NOT NULL
  , Username            NVARCHAR(100)                   NOT NULL
  , Email               NVARCHAR(256)                   NOT NULL
  , PasswordHash        NVARCHAR(512)                   NULL
  , HasChangedPassword  BIT                             NOT NULL    CONSTRAINT DF_User_HasChangedPassword  DEFAULT (0)
  , LoginCount          INT                             NOT NULL    CONSTRAINT DF_User_LoginCount          DEFAULT (0)
  , FailedLoginCount    INT                             NOT NULL    CONSTRAINT DF_User_FailedLoginCount    DEFAULT (0)
  , LockedUntil         DATETIME2(3)                    NULL
  , LastLoginDate       DATETIME2(3)                    NULL
  , Path                VARCHAR(850)                    NULL
  , Level               INT                             NULL
  , Active              BIT                             NOT NULL    CONSTRAINT DF_User_Active              DEFAULT (1)
  , Deleted             BIT                             NOT NULL    CONSTRAINT DF_User_Deleted             DEFAULT (0)
  , DisplayOrder        INT                             NOT NULL    CONSTRAINT DF_User_DisplayOrder        DEFAULT (0)
  , ID_CreatedBy        INT                             NOT NULL
  , CreatedDate         DATETIME2(3)                    NOT NULL    CONSTRAINT DF_User_CreatedDate         DEFAULT (SYSUTCDATETIME())
  , ID_UpdatedBy        INT                             NULL
  , UpdatedDate         DATETIME2(3)                    NULL
  , CONSTRAINT PK_User                PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT FK_User_Parent         FOREIGN KEY (ID_Parent)     REFERENCES security.[User] (ID)
  , CONSTRAINT FK_User_CreatedBy      FOREIGN KEY (ID_CreatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT FK_User_UpdatedBy      FOREIGN KEY (ID_UpdatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT UQ_User_Username       UNIQUE (Username)
  , CONSTRAINT UQ_User_Email          UNIQUE (Email)
);
GO

CREATE NONCLUSTERED INDEX IX_User_Path ON security.[User] (Path);
GO
