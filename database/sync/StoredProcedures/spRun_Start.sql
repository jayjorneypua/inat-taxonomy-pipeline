--=====================================================================================================
--                                        sync spRun_Start
--=====================================================================================================
-- Purpose:  Opens a sync run and returns its id. Every table merge logs against this id.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE sync.spRun_Start
    @ID_Run             BIGINT          OUTPUT
AS BEGIN
    SET NOCOUNT ON;

    INSERT INTO sync.Run DEFAULT VALUES;

    SET @ID_Run = SCOPE_IDENTITY();
END
GO