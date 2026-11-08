--=====================================================================================================
--                                        Security app_api role
--=====================================================================================================
-- Purpose:  The only permissions the c# api gets: execute on the procedures it calls.
--           No table access, no sync or internal procedures. Everything is owned by dbo, so
--           ownership chaining lets these procedures read and write the tables for the caller.
--           SQL projects need every GRANT in its own batch, hence a GO after each one.
-- History:
-- 2026-11-09  Jay Jorney Pua          Created the role and its grants.
--=====================================================================================================
CREATE ROLE [app_api] AUTHORIZATION [dbo];
GO

-- login and session
GRANT EXECUTE ON OBJECT::security.spUser_GetLoginInfo           TO [app_api];
GO
GRANT EXECUTE ON OBJECT::security.spUser_LoginFailed            TO [app_api];
GO
GRANT EXECUTE ON OBJECT::security.spSession_Create              TO [app_api];
GO
GRANT EXECUTE ON OBJECT::security.spSession_Refresh             TO [app_api];
GO
GRANT EXECUTE ON OBJECT::security.spSession_Revoke              TO [app_api];
GO

-- dashboard and taxonomy
GRANT EXECUTE ON OBJECT::dbo.spDashboard_TaxonChildrenCounts    TO [app_api];
GO
GRANT EXECUTE ON OBJECT::dbo.spDashboard_ObservationsByMonth    TO [app_api];
GO
GRANT EXECUTE ON OBJECT::dbo.spTaxonomy_ObservationsPage        TO [app_api];
GO