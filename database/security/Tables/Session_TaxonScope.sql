--=====================================================================================================
--                                        Security Session_TaxonScope
--=====================================================================================================
-- Purpose:  Effective data scope computed at login. TaxonPath is copied from the taxon,
--           so dashboard procs filter with path LIKE TaxonPath + ',%' without extra joins.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE security.Session_TaxonScope (
    ID_Session          BIGINT                          NOT NULL
  , ID_Taxon            INT                             NOT NULL
  , TaxonPath           VARCHAR(850)                    NOT NULL
  , CONSTRAINT PK_Session_TaxonScope              PRIMARY KEY CLUSTERED (ID_Session, ID_Taxon)
  , CONSTRAINT FK_Session_TaxonScope_Session      FOREIGN KEY (ID_Session)    REFERENCES security.Session (ID) ON DELETE CASCADE
);
GO