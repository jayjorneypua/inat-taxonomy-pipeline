--=====================================================================================================
--                                        dbo Taxon
--=====================================================================================================
-- Purpose:  Serving copy of gold dim_taxon, filled by the sync. ID is the iNaturalist taxon id,
--           not an identity. ID_Parent is a real foreign key, so the sync loads parents before
--           children, level by level.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE dbo.Taxon (
    ID                  INT                             NOT NULL
  , ID_Parent           INT                             NULL
  , ScientificName      NVARCHAR(300)                   NOT NULL
  , CommonName          NVARCHAR(300)                   NULL
  , Rank                NVARCHAR(50)                    NOT NULL
  , RankLevel           DECIMAL(4, 1)                   NULL
  , Path                VARCHAR(850)                    NULL
  , Level               INT                             NULL
  , HasChildren         BIT                             NOT NULL    CONSTRAINT DF_Taxon_HasChildren    DEFAULT (0)
  , Active              BIT                             NOT NULL    CONSTRAINT DF_Taxon_Active         DEFAULT (1)
  , IsInTree            BIT                             NOT NULL    CONSTRAINT DF_Taxon_IsInTree       DEFAULT (0)
  , SnapshotDate        DATE                            NULL
  , SyncedDate          DATETIME2(3)                    NOT NULL    CONSTRAINT DF_Taxon_SyncedDate     DEFAULT (SYSUTCDATETIME())
  , CONSTRAINT PK_Taxon                   PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT FK_Taxon_Parent            FOREIGN KEY (ID_Parent)     REFERENCES dbo.Taxon (ID)
);
GO

CREATE NONCLUSTERED INDEX IX_Taxon_Path ON dbo.Taxon (Path);
GO

CREATE NONCLUSTERED INDEX IX_Taxon_Parent ON dbo.Taxon (ID_Parent);
GO