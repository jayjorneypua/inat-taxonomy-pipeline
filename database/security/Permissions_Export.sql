-- the api role may run the export procedures, nothing else on Export_Job
GRANT EXECUTE ON OBJECT::dbo.spExport_Create TO app_api;
GO
GRANT EXECUTE ON OBJECT::dbo.spExport_Claim TO app_api;
GO
GRANT EXECUTE ON OBJECT::dbo.spExport_Rows TO app_api;
GO
GRANT EXECUTE ON OBJECT::dbo.spExport_Finish TO app_api;
GO
GRANT EXECUTE ON OBJECT::dbo.spExport_Get TO app_api;
GO
GRANT EXECUTE ON OBJECT::dbo.spExport_GetFile TO app_api;
GO
