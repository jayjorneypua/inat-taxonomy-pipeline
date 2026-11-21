# Migrations

The dacpac handles schema changes by itself. This folder is for the two things it cannot do.

| Folder | Runs | Use it for | Runs once because |
|---|---|---|---|
| `Pre\` | before the schema change, every publish | saving data a change would lose (rename, split, type change) | the script checks the schema state itself |
| `Post\` | after the schema change, every publish | one-time data fixes and backfills | `dbo.MigrationHistory` records it |

Rules:

- Name files `NNNN_short_name.sql` (`0001_backfill_taxon_rank.sql`), numbers never reused.
- Add one `:r` line per file to `Scripts\PreDeployment.sql` or `Scripts\PostDeployment.sql`, in number order. SQLCMD has no wildcards.
- Never edit a Post script after it ran anywhere: add a new one.
- Every script must also work on an empty database (`inat_test_empty` is rebuilt by `tools\run_tests.ps1`).
- `BlockOnPossibleDataLoss` stays on. A Pre script is how a data-losing change gets through safely.

## Post template

```sql
-- 0001_short_name: what it does and why
IF NOT EXISTS (SELECT 1 FROM dbo.MigrationHistory WHERE ScriptName = N'0001_short_name') BEGIN
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;

    -- the one-time change goes here

    INSERT INTO dbo.MigrationHistory (ScriptName) VALUES (N'0001_short_name');
    COMMIT TRANSACTION;
    PRINT '0001_short_name applied';
END
```

## Pre template

```sql
-- 0001_short_name: what it saves and why
IF COL_LENGTH(N'dbo.SomeTable', N'OldColumn') IS NOT NULL BEGIN
    -- copy the data somewhere safe before the dacpac changes the schema
    PRINT '0001_short_name applied';
END
```