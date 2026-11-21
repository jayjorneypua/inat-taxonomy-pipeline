--=====================================================================================================
--                                        dbo MigrationHistory
--=====================================================================================================
-- Purpose:  One row per one-time data migration (Scripts\Migrations\Post) that already ran on this
--           database. PostDeployment.sql checks it so every migration runs exactly once, even though
--           the post-deployment script itself runs on every publish.
-- History:
-- 2026-11-21  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE dbo.MigrationHistory (
    ID                  INT             IDENTITY(1, 1)  NOT NULL
  , ScriptName          NVARCHAR(200)                   NOT NULL
  , AppliedDate         DATETIME2(3)                    NOT NULL    CONSTRAINT DF_MigrationHistory_AppliedDate DEFAULT (SYSUTCDATETIME())
  , AppliedBy           NVARCHAR(128)                   NOT NULL    CONSTRAINT DF_MigrationHistory_AppliedBy   DEFAULT (SUSER_SNAME())
  , CONSTRAINT PK_MigrationHistory            PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT UQ_MigrationHistory_ScriptName UNIQUE (ScriptName)
);
GO