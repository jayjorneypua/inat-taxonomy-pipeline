-- run as inat_api. every forbidden action must be refused, every allowed procedure must run.
USE inat;
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

PRINT CONCAT('--- connected as ', SUSER_SNAME());

PRINT '--- 1. read a table directly (expect denied)';
BEGIN TRY
    SELECT TOP (1) ID FROM dbo.Observation;
    PRINT '--- FAILED: table read was allowed';
END TRY
BEGIN CATCH
    PRINT '--- correctly denied: ' + ERROR_MESSAGE();
END CATCH

PRINT '--- 2. read the users table, password hashes included (expect denied)';
BEGIN TRY
    SELECT TOP (1) PasswordHash FROM security.[User];
    PRINT '--- FAILED: users table read was allowed';
END TRY
BEGIN CATCH
    PRINT '--- correctly denied: ' + ERROR_MESSAGE();
END CATCH

PRINT '--- 3. run a sync procedure (expect denied)';
BEGIN TRY
    DECLARE @ID_Run BIGINT;
    EXEC sync.spMerge_All @IsFullExtract = 0, @ID_Run = @ID_Run OUTPUT;
    PRINT '--- FAILED: sync procedure was allowed';
END TRY
BEGIN CATCH
    PRINT '--- correctly denied: ' + ERROR_MESSAGE();
END CATCH

PRINT '--- 4. run an internal tree procedure (expect denied)';
BEGIN TRY
    EXEC security.spTreeNode_SetPath @TableName = N'Group', @ID = 1;
    PRINT '--- FAILED: internal procedure was allowed';
END TRY
BEGIN CATCH
    PRINT '--- correctly denied: ' + ERROR_MESSAGE();
END CATCH

PRINT '--- 5. read a procedure''s source code (expect NULL, no VIEW DEFINITION)';
SELECT OBJECT_DEFINITION(OBJECT_ID(N'security.spSession_Create')) AS procedure_source;

PRINT '--- 6. allowed login procedure (expect it to run and return no row)';
EXEC security.spUser_GetLoginInfo @Username = N'nobody';

PRINT '--- 7. allowed dashboard procedure with a fake session (expect it to run, then deny access)';
BEGIN TRY
    EXEC dbo.spDashboard_TaxonChildrenCounts @ID_Session = -1;
    PRINT '--- FAILED: a fake session got data';
END TRY
BEGIN CATCH
    PRINT '--- ran, and the session check refused it: ' + ERROR_MESSAGE();
END CATCH