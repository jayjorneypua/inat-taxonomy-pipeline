--=====================================================================================================
--                                        dbo Export_Job
--=====================================================================================================
-- Purpose:  Queue of CSV exports. The API inserts Queued rows, a background worker in any API
--           instance claims one (Running), writes the file and marks it Done or Failed.
-- History:
-- 2026-11-16  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE dbo.Export_Job
(
    ID                  INT             IDENTITY(1, 1)  NOT NULL
  , ID_User             INT             NOT NULL
  , ID_Session          BIGINT          NOT NULL
  , ID_Taxon            INT             NOT NULL
  , Status              VARCHAR(20)     NOT NULL    CONSTRAINT DF_Export_Job_Status        DEFAULT ('Queued')
  , AttemptCount        INT             NOT NULL    CONSTRAINT DF_Export_Job_AttemptCount  DEFAULT (0)
  , ClaimedBy           NVARCHAR(100)   NULL
  , ExportRowCount      INT             NULL
  , FileName            NVARCHAR(260)   NULL
  , ErrorMessage        NVARCHAR(4000)  NULL
  , CreatedDate         DATETIME2(3)    NOT NULL    CONSTRAINT DF_Export_Job_CreatedDate   DEFAULT (SYSUTCDATETIME())
  , StartedDate         DATETIME2(3)    NULL
  , FinishedDate        DATETIME2(3)    NULL
  , CONSTRAINT PK_Export_Job PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT FK_Export_Job_User FOREIGN KEY (ID_User) REFERENCES security.[User] (ID)
  , CONSTRAINT FK_Export_Job_Taxon FOREIGN KEY (ID_Taxon) REFERENCES dbo.Taxon (ID)
  , CONSTRAINT CK_Export_Job_Status CHECK (Status IN ('Queued', 'Running', 'Done', 'Failed'))
);
GO

-- the worker looks for the oldest Queued (or stale Running) job
CREATE NONCLUSTERED INDEX IX_Export_Job_Status
    ON dbo.Export_Job (Status, ID)
    INCLUDE (StartedDate, AttemptCount);
GO

-- the UI looks up a user's own jobs
CREATE NONCLUSTERED INDEX IX_Export_Job_User
    ON dbo.Export_Job (ID_User, ID);
GO