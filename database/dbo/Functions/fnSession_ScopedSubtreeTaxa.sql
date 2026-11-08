--=====================================================================================================
--                                        dbo fnSession_ScopedSubtreeTaxa
--=====================================================================================================
-- Purpose:  Every taxon in the subtree of @ID_Taxon (itself included) that is also inside the
--           session's taxon scope. Shared by the dashboard and taxonomy procedures so the scope
--           rule lives in one place.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the function.
--=====================================================================================================
CREATE FUNCTION dbo.fnSession_ScopedSubtreeTaxa (
    @ID_Session         BIGINT
  , @ID_Taxon           INT
)
RETURNS TABLE
AS
RETURN
SELECT
    subtree_taxa.ID
FROM
    dbo.Taxon selected_taxon
INNER JOIN
    dbo.Taxon subtree_taxa
    ON subtree_taxa.Path = selected_taxon.Path
    OR subtree_taxa.Path LIKE selected_taxon.Path + ',%'
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