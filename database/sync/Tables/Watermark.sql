--=====================================================================================================
--                                        sync Watermark
--=====================================================================================================
-- Purpose:  Last UpdatedDate synced per table, for incremental extracts of the big tables.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE sync.Watermark (
    TableName           SYSNAME                         NOT NULL
  , LastUpdatedDate     DATETIME2(3)                    NULL
  , UpdatedDate         DATETIME2(3)                    NOT NULL    CONSTRAINT DF_Watermark_UpdatedDate DEFAULT (SYSUTCDATETIME())
  , CONSTRAINT PK_Watermark               PRIMARY KEY CLUSTERED (TableName)
);
GO