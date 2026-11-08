--=====================================================================================================
--                                        sync Run
--=====================================================================================================
-- Purpose:  One row per sync run, with its status and the error message if it failed.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE sync.Run (
    ID                  BIGINT          IDENTITY(1, 1)  NOT NULL
  , StartedDate         DATETIME2(3)                    NOT NULL    CONSTRAINT DF_Run_StartedDate  DEFAULT (SYSUTCDATETIME())
  , FinishedDate        DATETIME2(3)                    NULL
  , Status              VARCHAR(20)                     NOT NULL    CONSTRAINT DF_Run_Status       DEFAULT ('Running')
  , ErrorMessage        NVARCHAR(4000)                  NULL
  , CONSTRAINT PK_Run                     PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT CK_Run_Status              CHECK ([Status]='Failed' OR [Status]='Succeeded' OR [Status]='Running')
);
GO