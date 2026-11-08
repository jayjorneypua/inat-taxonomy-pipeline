--=====================================================================================================
--                                        Security Session
--=====================================================================================================
-- Purpose:  One row per login. The api keeps the real refresh token, the database only keeps
--           its sha-256 hash, so a copy of this table can't be used to log in as anyone.
--           PreviousTokenHash keeps the token replaced at the last refresh: if it is ever
--           presented again, someone kept a copy, and the session is revoked.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
-- 2026-11-08  Jay Jorney Pua          Added PreviousTokenHash for refresh token reuse detection.
--=====================================================================================================
CREATE TABLE security.Session (
    ID                  BIGINT          IDENTITY(1, 1)  NOT NULL
  , ID_User             INT                             NOT NULL
  , TokenHash           VARBINARY(32)                   NOT NULL
  , PreviousTokenHash   VARBINARY(32)                   NULL
  , CreatedDate         DATETIME2(3)                    NOT NULL    CONSTRAINT DF_Session_CreatedDate   DEFAULT (SYSUTCDATETIME())
  , ExpiresDate         DATETIME2(3)                    NOT NULL
  , LastSeenDate        DATETIME2(3)                    NOT NULL    CONSTRAINT DF_Session_LastSeenDate  DEFAULT (SYSUTCDATETIME())
  , RevokedDate         DATETIME2(3)                    NULL
  , RevokedReason       NVARCHAR(200)                   NULL
  , ClientIpAddress     VARCHAR(45)                     NULL
  , UserAgent           NVARCHAR(500)                   NULL
  , CONSTRAINT PK_Session                 PRIMARY KEY CLUSTERED (ID)
  , CONSTRAINT FK_Session_User            FOREIGN KEY (ID_User)   REFERENCES security.[User] (ID)
  , CONSTRAINT CK_Session_Dates           CHECK (ExpiresDate > CreatedDate)
);
GO

CREATE UNIQUE NONCLUSTERED INDEX UX_Session_TokenHash ON security.Session (TokenHash);
GO

CREATE NONCLUSTERED INDEX IX_Session_PreviousTokenHash
    ON security.Session (PreviousTokenHash)
    WHERE PreviousTokenHash IS NOT NULL;
GO

CREATE NONCLUSTERED INDEX IX_Session_User ON security.Session (ID_User);
GO