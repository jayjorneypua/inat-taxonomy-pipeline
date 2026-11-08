--=====================================================================================================
--                                        Security Group
--=====================================================================================================
-- Purpose:  Organizations, departments, locations and teams as one tree (ID_Parent, Path, Level).
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE security.[Group] (
    ID                  INT             IDENTITY(1, 1)  NOT NULL
  , ID_Parent           INT                             NULL
  , ID_GroupType        INT                             NOT NULL
  , Name                NVARCHAR(200)                   NOT NULL
  , Description         NVARCHAR(500)                   NULL
  , Path                VARCHAR(850)                    NULL
  , Level               INT                             NULL
  , Active              BIT                             NOT NULL    CONSTRAINT DF_Group_Active             DEFAULT (1)
  , Deleted             BIT                             NOT NULL    CONSTRAINT DF_Group_Deleted            DEFAULT (0)
  , DisplayOrder        INT                             NOT NULL    CONSTRAINT DF_Group_DisplayOrder       DEFAULT (0)
  , ID_CreatedBy        INT                             NOT NULL
  , CreatedDate         DATETIME2(3)                    NOT NULL    CONSTRAINT DF_Group_CreatedDate        DEFAULT (SYSUTCDATETIME())
  , ID_UpdatedBy        INT                             NULL
  , UpdatedDate         DATETIME2(3)                    NULL
  , CONSTRAINT PK_Group               PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT FK_Group_Parent        FOREIGN KEY (ID_Parent)     REFERENCES security.[Group] (ID)
  , CONSTRAINT FK_Group_GroupType     FOREIGN KEY (ID_GroupType)  REFERENCES security.GroupType (ID)
  , CONSTRAINT FK_Group_CreatedBy     FOREIGN KEY (ID_CreatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT FK_Group_UpdatedBy     FOREIGN KEY (ID_UpdatedBy)  REFERENCES security.[User] (ID)
);
GO

CREATE NONCLUSTERED INDEX IX_Group_Path ON security.[Group] (Path);
GO

