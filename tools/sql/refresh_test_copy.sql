-- makes inat_test_copy a fresh copy of inat: a copy-only compressed backup, restored under a new name.
-- copy-only means it doesn't disturb any real backup chain. file locations come from the server's defaults.
SET NOCOUNT ON;

DECLARE @BackupFolder       NVARCHAR(400) = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(400));
DECLARE @DataFolder         NVARCHAR(400) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(400));
DECLARE @LogFolder          NVARCHAR(400) = CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS NVARCHAR(400));
DECLARE @BackupFile         NVARCHAR(500);
DECLARE @DataFile           NVARCHAR(500);
DECLARE @LogFile            NVARCHAR(500);
DECLARE @DataLogicalName    SYSNAME = (SELECT name FROM sys.master_files WHERE database_id = DB_ID(N'inat') AND type_desc = N'ROWS');
DECLARE @LogLogicalName     SYSNAME = (SELECT name FROM sys.master_files WHERE database_id = DB_ID(N'inat') AND type_desc = N'LOG');

IF RIGHT(@BackupFolder, 1) <> N'\' BEGIN
    SET @BackupFolder = @BackupFolder + N'\';
END

IF RIGHT(@DataFolder, 1) <> N'\' BEGIN
    SET @DataFolder = @DataFolder + N'\';
END

IF RIGHT(@LogFolder, 1) <> N'\' BEGIN
    SET @LogFolder = @LogFolder + N'\';
END

SET @BackupFile = @BackupFolder + N'inat_for_tests.bak';
SET @DataFile   = @DataFolder + N'inat_test_copy.mdf';
SET @LogFile    = @LogFolder + N'inat_test_copy_log.ldf';

PRINT CONCAT('backing up inat to ', @BackupFile);
BACKUP DATABASE inat TO DISK = @BackupFile WITH COPY_ONLY, COMPRESSION, INIT, STATS = 25;

IF DB_ID(N'inat_test_copy') IS NOT NULL BEGIN
    ALTER DATABASE inat_test_copy SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
END

PRINT 'restoring as inat_test_copy';
RESTORE DATABASE inat_test_copy
FROM DISK = @BackupFile
WITH
    REPLACE
  , STATS = 25
  , MOVE @DataLogicalName TO @DataFile
  , MOVE @LogLogicalName TO @LogFile;

ALTER DATABASE inat_test_copy SET MULTI_USER;
PRINT 'inat_test_copy is ready';