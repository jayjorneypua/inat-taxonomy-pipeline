--=====================================================================================================
--                                        dbo spTaxonomy_TaxonPath
--=====================================================================================================
-- Purpose:  The breadcrumb for a taxon: every ancestor from the root down to the taxon itself,
--           in order. Requires taxonomy.view. A taxon is shown when it is inside the session's
--           scope or above it (so a scoped user can walk down from Life to reach their scope),
--           otherwise the result is empty. STRING_SPLIT with an ordinal keeps the path order.
-- History:
-- 2026-11-15  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE dbo.spTaxonomy_TaxonPath
    @ID_Session         BIGINT
  , @ID_Taxon           INT
  , @ClientIpAddress    VARCHAR(45) = NULL
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @ID_User    INT;
    DECLARE @TaxonPath  VARCHAR(850);

    EXEC security.spSession_CheckAccess
        @ID_Session      = @ID_Session
      , @PermissionCode  = N'taxonomy.view'
      , @ClientIpAddress = @ClientIpAddress
      , @ID_User         = @ID_User OUTPUT;

    SET @TaxonPath = (SELECT Path FROM dbo.Taxon WHERE ID = @ID_Taxon);

    -- an unknown taxon gives a null path, which splits into nothing: an empty result
    SELECT
        ancestors.ID
      , ancestors.ScientificName
      , ancestors.CommonName
      , ancestors.Rank
      , ancestors.Level
    FROM
        STRING_SPLIT(@TaxonPath, ',', 1) path_parts
    INNER JOIN
        dbo.Taxon ancestors
        ON ancestors.ID = CAST(path_parts.value AS INT)
    WHERE
        EXISTS (
            SELECT 1
            FROM security.Session_TaxonScope scopes
            WHERE scopes.ID_Session = @ID_Session
            AND (
                    @TaxonPath = scopes.TaxonPath
                 OR @TaxonPath LIKE scopes.TaxonPath + ',%'
                 OR scopes.TaxonPath LIKE @TaxonPath + ',%'
                )
        )
    ORDER BY
        path_parts.ordinal;

END

GO