-- creates the server login and database user for the c# api and puts it in the app_api role.
-- the password comes from the ApiPassword scripting variable, which sqlcmd reads from an
-- environment variable, so it is never written in this file, the repo or the command history.
USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'inat_api') BEGIN
    CREATE LOGIN [inat_api]
    WITH
        PASSWORD         = N'$(ApiPassword)'
      , DEFAULT_DATABASE = [inat]
      , CHECK_POLICY     = ON
      , CHECK_EXPIRATION = OFF;
END
GO

USE inat;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'inat_api') BEGIN
    CREATE USER [inat_api] FOR LOGIN [inat_api];
END

ALTER ROLE [app_api] ADD MEMBER [inat_api];
GO

SELECT
    members.name                    AS member_name
  , roles.name                      AS role_name
FROM
    sys.database_role_members role_members
INNER JOIN
    sys.database_principals roles
    ON role_members.role_principal_id = roles.principal_id
INNER JOIN
    sys.database_principals members
    ON role_members.member_principal_id = members.principal_id
WHERE
    members.name = N'inat_api';
GO