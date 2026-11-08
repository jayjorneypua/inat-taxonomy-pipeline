--=====================================================================================================
--                                        Security Session_Permission
--=====================================================================================================
-- Purpose:  Effective permissions computed once at login (direct roles plus group roles),
--           so every proc checks access with one indexed lookup. Derived data, rebuilt from
--           the normalized tables at each login and token refresh.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the table.
--=====================================================================================================
CREATE TABLE security.Session_Permission (
    ID_Session          BIGINT                          NOT NULL
  , ID_Permission       INT                             NOT NULL
  , CONSTRAINT PK_Session_Permission              PRIMARY KEY CLUSTERED (ID_Session, ID_Permission)
  , CONSTRAINT FK_Session_Permission_Session      FOREIGN KEY (ID_Session)    REFERENCES security.Session (ID) ON DELETE CASCADE
  , CONSTRAINT FK_Session_Permission_Permission   FOREIGN KEY (ID_Permission) REFERENCES security.Permission (ID)
);
GO