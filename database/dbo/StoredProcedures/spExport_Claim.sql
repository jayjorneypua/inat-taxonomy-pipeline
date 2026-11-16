--=====================================================================================================
--                                        dbo spExport_Claim
--=====================================================================================================
-- Purpose:  Gives the calling worker the oldest waiting export and marks it Running. UPDLOCK and
--           READPAST make two workers skip each other's row, so every job runs once. A job Running
--           for over 10 minutes belongs to a worker that died, so it is taken again, up to 3 tries.
--           Returns no row when there is nothing to do.
-- History:
-- 2026-11-16  Jay Jorney Pua          Created the procedure.
-- 2026-11-16  Jay Jorney Pua          Status from dbo.ExportStatus.
--=====================================================================================================
CREATE PROCEDURE dbo.spExport_Claim
    @ClaimedBy              NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @ID_ExportStatus_Queued  INT = (SELECT ID FROM dbo.ExportStatus WHERE Name = N'Queued');
    DECLARE @ID_ExportStatus_Running INT = (SELECT ID FROM dbo.ExportStatus WHERE Name = N'Running');
    DECLARE @StaleBefore             DATETIME2(3) = DATEADD(MINUTE, -10, SYSUTCDATETIME());

    WITH next_job AS (
        SELECT TOP (1)
            export_jobs.ID
          , export_jobs.ID_Session
          , export_jobs.ID_Taxon
          , export_jobs.ID_ExportStatus
          , export_jobs.ClaimedBy
          , export_jobs.StartedDate
          , export_jobs.AttemptCount
        FROM
            dbo.Export_Job export_jobs WITH (UPDLOCK, READPAST, ROWLOCK)
        WHERE
            export_jobs.ID_ExportStatus = @ID_ExportStatus_Queued
        OR  (
                export_jobs.ID_ExportStatus = @ID_ExportStatus_Running
            AND export_jobs.StartedDate     < @StaleBefore
            AND export_jobs.AttemptCount    < 3
            )
        ORDER BY
            export_jobs.ID
    )
    UPDATE
        next_job
    SET
        ID_ExportStatus = @ID_ExportStatus_Running
      , ClaimedBy       = @ClaimedBy
      , StartedDate     = SYSUTCDATETIME()
      , AttemptCount    = AttemptCount + 1
    OUTPUT
        inserted.ID
      , inserted.ID_Session
      , inserted.ID_Taxon;
END
GO
