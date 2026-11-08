--=====================================================================================================
--                                        sync spMerge_All
--=====================================================================================================
-- Purpose:  Runs every merge in foreign key order (Observer, Taxon, Photo, Observation, bridge)
--           as one logged run. Each table commits on its own to keep the log small. If one
--           fails, the run is marked Failed with the error; every merge is safe to rerun,
--           so the next run completes the job.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE sync.spMerge_All
    @IsFullExtract      BIT
  , @ID_Run             BIGINT          OUTPUT
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @ErrorMessage NVARCHAR(4000);

    EXEC sync.spRun_Start @ID_Run = @ID_Run OUTPUT;

    BEGIN TRY
        EXEC sync.spMerge_Observer         @ID_Run = @ID_Run;
        EXEC sync.spMerge_Taxon            @ID_Run = @ID_Run;
        EXEC sync.spMerge_Photo            @ID_Run = @ID_Run, @IsFullExtract = @IsFullExtract;
        EXEC sync.spMerge_Observation      @ID_Run = @ID_Run, @IsFullExtract = @IsFullExtract;
        EXEC sync.spMerge_ObservationPhoto @ID_Run = @ID_Run, @IsFullExtract = @IsFullExtract;

        EXEC sync.spRun_Finish @ID_Run = @ID_Run, @Status = 'Succeeded';
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();

        IF XACT_STATE() <> 0 BEGIN
            ROLLBACK TRANSACTION;
        END

        EXEC sync.spRun_Finish @ID_Run = @ID_Run, @Status = 'Failed', @ErrorMessage = @ErrorMessage;

        THROW;
    END CATCH
END
GO