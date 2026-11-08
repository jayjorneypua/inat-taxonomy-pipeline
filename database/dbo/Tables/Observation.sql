--=====================================================================================================
--                                        dbo Observation
--=====================================================================================================
-- Purpose:  Serving copy of gold fct_observations. ID is an internal identity for small, fast
--           joins, ObservationUuid matches gold. No foreign key to Taxon on purpose: taxa created
--           after the last taxa snapshot only arrive with the next monthly dump.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE dbo.Observation (
    ID                  INT             IDENTITY(1, 1)  NOT NULL
  , ObservationUuid     UNIQUEIDENTIFIER                NOT NULL
  , InatObservationID   BIGINT                          NULL
  , ID_Taxon            INT                             NOT NULL
  , ID_Observer         INT                             NOT NULL
  , ObservedDate        DATE                            NOT NULL
  , Latitude            DECIMAL(10, 7)                  NULL
  , Longitude           DECIMAL(10, 7)                  NULL
  , PositionalAccuracy  INT                             NULL
  , PhotoCount          INT                             NOT NULL    CONSTRAINT DF_Observation_PhotoCount   DEFAULT (0)
  , Source              VARCHAR(10)                     NOT NULL
  , UpdatedDate         DATETIME2(3)                    NULL
  , SyncedDate          DATETIME2(3)                    NOT NULL    CONSTRAINT DF_Observation_SyncedDate   DEFAULT (SYSUTCDATETIME())
  , CONSTRAINT PK_Observation             PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT FK_Observation_Observer    FOREIGN KEY (ID_Observer)   REFERENCES dbo.Observer (ID)
  , CONSTRAINT UQ_Observation_Uuid        UNIQUE (ObservationUuid)
);
GO

CREATE NONCLUSTERED INDEX IX_Observation_Taxon ON dbo.Observation (ID_Taxon) INCLUDE (ObservedDate);
GO

CREATE NONCLUSTERED INDEX IX_Observation_ObservedDate ON dbo.Observation (ObservedDate);
GO

CREATE NONCLUSTERED INDEX IX_Observation_Observer ON dbo.Observation (ID_Observer);
GO