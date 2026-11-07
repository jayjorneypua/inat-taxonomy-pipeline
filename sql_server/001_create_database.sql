-- creates the serving database and its schemas. safe to rerun

IF DB_ID(N'inat') IS NULL BEGIN
    CREATE DATABASE inat;
END
GO

-- the serving database can always be rebuilt from gold, so full log backups add nothing.
-- simple recovery also keeps the log small during big bulk loads
ALTER DATABASE inat SET RECOVERY SIMPLE;
GO

USE inat;
GO

-- create schema must be the only statement in its batch, hence exec
IF SCHEMA_ID(N'stage') IS NULL BEGIN
    EXEC (N'CREATE SCHEMA stage AUTHORIZATION dbo;');
END

IF SCHEMA_ID(N'sync') IS NULL BEGIN
    EXEC (N'CREATE SCHEMA sync AUTHORIZATION dbo;');
END

IF SCHEMA_ID(N'security') IS NULL BEGIN
    EXEC (N'CREATE SCHEMA security AUTHORIZATION dbo;');
END
GO

SELECT
    schemas.name AS schema_name
FROM
    sys.schemas schemas
WHERE
    schemas.name IN (N'dbo', N'stage', N'sync', N'security')
ORDER BY
    schemas.name;
GO