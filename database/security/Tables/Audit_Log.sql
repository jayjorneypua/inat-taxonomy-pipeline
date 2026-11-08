--=====================================================================================================
--                                        Security Audit_Log
--=====================================================================================================
-- Purpose:  Security events. No foreign key to Session on purpose: the log must outlive
--           purged sessions and never block cleanup. ID_User is null for failed logins
--           on usernames that don't exist, Username keeps what was attempted.
--           The event type check is written the way SQL Server stores it (an OR chain),
--           otherwise every publish sees a difference and drops and recreates it.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
-- 2026-11-08  Jay Jorney Pua          Rewrote the event type check in SQL Server's stored form.
--=====================================================================================================
CREATE TABLE security.Audit_Log (
    ID                  BIGINT          IDENTITY(1, 1)  NOT NULL
  , EventDate           DATETIME2(3)                    NOT NULL    CONSTRAINT DF_Audit_Log_EventDate   DEFAULT (SYSUTCDATETIME())
  , EventType           NVARCHAR(50)                    NOT NULL
  , ID_User             INT                             NULL
  , Username            NVARCHAR(100)                   NULL
  , ID_Session          BIGINT                          NULL
  , ResourceCode        NVARCHAR(200)                   NULL
  , ClientIpAddress     VARCHAR(45)                     NULL
  , Details             NVARCHAR(2000)                  NULL
  , CONSTRAINT PK_Audit_Log               PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT FK_Audit_Log_User          FOREIGN KEY (ID_User)   REFERENCES security.[User] (ID)
  , CONSTRAINT CK_Audit_Log_EventType     CHECK ([EventType]=N'PermissionChanged' OR [EventType]=N'AccessDenied' OR [EventType]=N'SessionRevoked' OR [EventType]=N'SessionRefreshed' OR [EventType]=N'Logout' OR [EventType]=N'LoginLocked' OR [EventType]=N'LoginFailed' OR [EventType]=N'LoginSucceeded')
);
GO

CREATE NONCLUSTERED INDEX IX_Audit_Log_EventDate ON security.Audit_Log (EventDate);
GO

CREATE NONCLUSTERED INDEX IX_Audit_Log_User ON security.Audit_Log (ID_User, EventDate);
GO