--=====================================================================================================
--                                        dbo fnSession_ScopedSubtreeTaxa
--=====================================================================================================
-- Purpose:  Every taxon in the subtree of @ID_Taxon (itself included) that is also inside the
--           session's taxon scope. Shared by the dashboard and taxonomy procedures so the scope
--           rule lives in one place.
--           The taxon itself and its descendants are two separate SELECTs joined by UNION ALL
--           instead of one join with OR, so the descendant part can seek IX_Taxon_Path.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the function.
-- 2026-11-15  Jay Jorney Pua          Split the OR into UNION ALL so the path index is used.
--=====================================================================================================
CREATE FUNCTION dbo.fnSession_ScopedSubtreeTaxa (
    @ID_Session         BIGINT
  , @ID_Taxon           INT
)
RETURNS TABLE
AS
RETURN
-- the taxon itself
SELECT
    selected_taxon.ID
FROM
    dbo.Taxon selected_taxon
WHERE
    selected_taxon.ID = @ID_Taxon
AND EXISTS (
        SELECT 1
        FROM security.Session_TaxonScope scopes
        WHERE scopes.ID_Session = @ID_Session
        AND (
                selected_taxon.Path = scopes.TaxonPath
             OR selected_taxon.Path LIKE scopes.TaxonPath + ',%'
            )
    )

UNION ALL

-- every descendant: their path starts with the taxon's path and a comma
SELECT
    subtree_taxa.ID
FROM
    dbo.Taxon selected_taxon
INNER JOIN
    dbo.Taxon subtree_taxa
    ON subtree_taxa.Path LIKE selected_taxon.Path + ',%'
WHERE
    selected_taxon.ID = @ID_Taxon
AND EXISTS (
        SELECT 1
        FROM security.Session_TaxonScope scopes
        WHERE scopes.ID_Session = @ID_Session
        AND (
                subtree_taxa.Path = scopes.TaxonPath
             OR subtree_taxa.Path LIKE scopes.TaxonPath + ',%'
            )
    );
GO