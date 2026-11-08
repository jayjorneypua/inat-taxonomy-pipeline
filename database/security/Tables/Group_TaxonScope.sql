--=====================================================================================================
--                                        Security Group_TaxonScope
--=====================================================================================================
-- Purpose:  Data scope given to a group, applying to its members and to members of groups under it.
--           Foreign key to the taxa table is added once the serving tables exist.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE security.Group_TaxonScope (
    ID                  INT             IDENTITY(1, 1)  NOT NULL
  , ID_Group            INT                             NOT NULL
  , ID_Taxon            INT                             NOT NULL
  , StartDate           DATETIME2(3)                    NOT NULL    CONSTRAINT DF_Group_TaxonScope_StartDate    DEFAULT (SYSUTCDATETIME())
  , EndDate             DATETIME2(3)                    NULL
  , ID_CreatedBy        INT                             NOT NULL
  , CreatedDate         DATETIME2(3)                    NOT NULL    CONSTRAINT DF_Group_TaxonScope_CreatedDate  DEFAULT (SYSUTCDATETIME())
  , ID_UpdatedBy        INT                             NULL
  , UpdatedDate         DATETIME2(3)                    NULL
  , CONSTRAINT PK_Group_TaxonScope            PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT FK_Group_TaxonScope_Group      FOREIGN KEY (ID_Group)      REFERENCES security.[Group] (ID)
  , CONSTRAINT FK_Group_TaxonScope_CreatedBy  FOREIGN KEY (ID_CreatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT FK_Group_TaxonScope_UpdatedBy  FOREIGN KEY (ID_UpdatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT CK_Group_TaxonScope_Dates      CHECK (EndDate IS NULL OR EndDate > StartDate)
);
GO

CREATE UNIQUE NONCLUSTERED INDEX UX_Group_TaxonScope_Current
    ON security.Group_TaxonScope (ID_Group, ID_Taxon)
    WHERE EndDate IS NULL;
GO