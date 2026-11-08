--=====================================================================================================
--                                        sync Run_Table
--=====================================================================================================
-- Purpose:  Row counts and duration for each table in each sync run.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE sync.Run_Table (
    ID                  BIGINT          IDENTITY(1, 1)  NOT NULL
  , ID_Run              BIGINT                          NOT NULL
  , TableName           SYSNAME                         NOT NULL
  , RowsExtracted       INT                             NULL
  , RowsInserted        INT                             NULL
  , RowsUpdated         INT                             NULL
  , RowsDeleted         INT                             NULL
  , StartedDate         DATETIME2(3)                    NOT NULL    CONSTRAINT DF_Run_Table_StartedDate DEFAULT (SYSUTCDATETIME())
  , FinishedDate        DATETIME2(3)                    NULL
  , CONSTRAINT PK_Run_Table               PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT FK_Run_Table_Run           FOREIGN KEY (ID_Run)    REFERENCES sync.Run (ID)
);
GO