--=====================================================================================================
--                                        dbo spTaxonomy_ObservationsPage
--=====================================================================================================
-- Purpose:  One page of observations in a taxon's subtree, newest first, each with its first photo,
--           for the "load more" photo grid. Cursor pagination: pass the last row's ObservedDate and
--           ObservationID to get the next page. ID breaks ties between observations on the same date,
--           so no row is skipped or repeated. Page size is clamped to 1..100.
--           Phase 1 finds only the page's ids, phase 2 joins names, observers and photos for them.
--           Phase 1 fast path: read the newest @ScanLimit observations after the cursor from
--           IX_Observation_ObservedDate and keep those whose taxon path is in the subtree and in the
--           session's scope. Big taxa (Animals, Plants) fill a page here in milliseconds.
--           Phase 1 fallback: if the fast path did not fill the page, list the scoped subtree taxa
--           first (cheap for small subtrees) and search all observations. Both paths use the same
--           filter and order, so pages stay consistent whichever path served them.
--           The scope rule in the fast path matches dbo.fnSession_ScopedSubtreeTaxa; keep them in sync.
--           Requires taxonomy.view, only returns observations inside the session's scope.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
-- 2026-11-15  Jay Jorney Pua          Two phases, so details are only looked up for one page.
-- 2026-11-19  Jay Jorney Pua          Fast path over the newest observations, subtree list only as
--                                     fallback (Animals went from about 5 s to under 100 ms).
--=====================================================================================================
CREATE PROCEDURE dbo.spTaxonomy_ObservationsPage
    @ID_Session             BIGINT
  , @ID_Taxon               INT
  , @PageSize               INT             = 24
  , @AfterObservedDate      DATE            = NULL
  , @AfterObservationID     INT             = NULL
  , @ClientIpAddress        VARCHAR(45)     = NULL
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @ID_User        INT;
    DECLARE @ScanLimit      INT             = 20000;
    DECLARE @SelectedPath   VARCHAR(850);
    DECLARE @FoundRows      INT;

    EXEC security.spSession_CheckAccess
        @ID_Session      = @ID_Session
      , @PermissionCode  = N'taxonomy.view'
      , @ClientIpAddress = @ClientIpAddress
      , @ID_User         = @ID_User OUTPUT;

    -- nobody gets millions of rows in one call
    SET @PageSize =
        CASE
            WHEN @PageSize IS NULL THEN 24
            WHEN @PageSize < 1     THEN 1
            WHEN @PageSize > 100   THEN 100
            ELSE @PageSize
        END;

    CREATE TABLE #page_observations (
        ID                  INT             NOT NULL
      , ObservedDate        DATE            NOT NULL
    );

    SELECT
        @SelectedPath = selected_taxon.Path
    FROM
        dbo.Taxon selected_taxon
    WHERE
        selected_taxon.ID = @ID_Taxon;

    -- phase 1 fast path: only the newest observations after the cursor
    INSERT INTO #page_observations (
        ID
      , ObservedDate
    )
    SELECT TOP (@PageSize)
        recent_observations.ID
      , recent_observations.ObservedDate
    FROM (
        SELECT TOP (@ScanLimit)
            observations.ID
          , observations.ObservedDate
          , observations.ID_Taxon
        FROM
            dbo.Observation observations
        WHERE
            @AfterObservedDate IS NULL
        OR  observations.ObservedDate < @AfterObservedDate
        OR  (
                observations.ObservedDate = @AfterObservedDate
            AND observations.ID < @AfterObservationID
            )
        ORDER BY
            observations.ObservedDate DESC
          , observations.ID DESC
    ) recent_observations
    INNER JOIN
        dbo.Taxon taxa
        ON recent_observations.ID_Taxon = taxa.ID
    WHERE
        (
            taxa.ID = @ID_Taxon
        OR  taxa.Path LIKE @SelectedPath + ',%'
        )
    AND EXISTS (
            SELECT 1
            FROM security.Session_TaxonScope scopes
            WHERE scopes.ID_Session = @ID_Session
            AND (
                    taxa.Path = scopes.TaxonPath
                 OR taxa.Path LIKE scopes.TaxonPath + ',%'
                )
        )
    ORDER BY
        recent_observations.ObservedDate DESC
      , recent_observations.ID DESC
    OPTION (RECOMPILE);

    SET @FoundRows = @@ROWCOUNT;

    -- phase 1 fallback: taxon is rare among recent observations
    IF @FoundRows < @PageSize
    BEGIN
        TRUNCATE TABLE #page_observations;

        SELECT
            scoped_taxa.ID
        INTO
            #scoped_taxa
        FROM
            dbo.fnSession_ScopedSubtreeTaxa(@ID_Session, @ID_Taxon) scoped_taxa;

        CREATE CLUSTERED INDEX IX_scoped_taxa ON #scoped_taxa (ID);

        INSERT INTO #page_observations (
            ID
          , ObservedDate
        )
        SELECT TOP (@PageSize)
            observations.ID
          , observations.ObservedDate
        FROM
            dbo.Observation observations
        WHERE
            EXISTS (
                SELECT 1
                FROM #scoped_taxa scoped_taxa
                WHERE scoped_taxa.ID = observations.ID_Taxon
            )
        AND (
                @AfterObservedDate IS NULL
            OR  observations.ObservedDate < @AfterObservedDate
            OR  (
                    observations.ObservedDate = @AfterObservedDate
                AND observations.ID < @AfterObservationID
                )
            )
        ORDER BY
            observations.ObservedDate DESC
          , observations.ID DESC
        OPTION (RECOMPILE);
    END

    -- phase 2: names, observer and first photo for those rows only
    SELECT
        observations.ID                     AS ObservationID
      , observations.ObservationUuid
      , observations.ObservedDate
      , observations.ID_Taxon
      , taxa.ScientificName
      , taxa.CommonName
      , observers.DisplayName               AS ObserverDisplayName
      , observations.PhotoCount
      , first_photo.SquareUrl
      , first_photo.MediumUrl
      , first_photo.Attribution
      , first_photo.License
    FROM
        #page_observations page_observations
    INNER JOIN
        dbo.Observation observations
        ON page_observations.ID = observations.ID
    INNER JOIN
        dbo.Taxon taxa
        ON observations.ID_Taxon = taxa.ID
    INNER JOIN
        dbo.Observer observers
        ON observations.ID_Observer = observers.ID
    OUTER APPLY (
        SELECT TOP (1)
            photos.SquareUrl
          , photos.MediumUrl
          , photos.Attribution
          , photos.License
        FROM
            dbo.Observation_Photo observation_photos
        INNER JOIN
            dbo.Photo photos
            ON observation_photos.ID_Photo = photos.ID
        WHERE
            observation_photos.ID_Observation = observations.ID
        ORDER BY
            observation_photos.PhotoPosition
    ) first_photo
    ORDER BY
        observations.ObservedDate DESC
      , observations.ID DESC;
END
GO