--=====================================================================================================
--                                        Security User_TaxonScope
--=====================================================================================================
-- Purpose:  Data scope given directly to a user: the taxon subtree they can see.
--           No scope rows means no data (default deny). Scope on the root taxon means everything.
--           Taxa are never deleted by the sync, so the foreign key to dbo.Taxon can't block it.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
-- 2026-11-15  Jay Jorney Pua          Added the foreign key to dbo.Taxon.
--=====================================================================================================
CREATE TABLE security.User_TaxonScope (
    ID                  INT             IDENTITY(1, 1)  NOT NULL
  , ID_User             INT                             NOT NULL
  , ID_Taxon            INT                             NOT NULL
  , StartDate           DATETIME2(3)                    NOT NULL    CONSTRAINT DF_User_TaxonScope_StartDate     DEFAULT (SYSUTCDATETIME())
  , EndDate             DATETIME2(3)                    NULL
  , ID_CreatedBy        INT                             NOT NULL
  , CreatedDate         DATETIME2(3)                    NOT NULL    CONSTRAINT DF_User_TaxonScope_CreatedDate   DEFAULT (SYSUTCDATETIME())
  , ID_UpdatedBy        INT                             NULL
  , UpdatedDate         DATETIME2(3)                    NULL
  , CONSTRAINT PK_User_TaxonScope             PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT FK_User_TaxonScope_User        FOREIGN KEY (ID_User)       REFERENCES security.[User] (ID)
  , CONSTRAINT FK_User_TaxonScope_Taxon       FOREIGN KEY (ID_Taxon)      REFERENCES dbo.Taxon (ID)
  , CONSTRAINT FK_User_TaxonScope_CreatedBy   FOREIGN KEY (ID_CreatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT FK_User_TaxonScope_UpdatedBy   FOREIGN KEY (ID_UpdatedBy)  REFERENCES security.[User] (ID)
  , CONSTRAINT CK_User_TaxonScope_Dates       CHECK (EndDate IS NULL OR EndDate > StartDate)
);
GO

CREATE UNIQUE NONCLUSTERED INDEX UX_User_TaxonScope_Current
    ON security.User_TaxonScope (ID_User, ID_Taxon)
    WHERE EndDate IS NULL;
GO