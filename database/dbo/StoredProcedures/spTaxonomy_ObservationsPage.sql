--=====================================================================================================
--                                        dbo spTaxonomy_ObservationsPage
--=====================================================================================================
-- Purpose:  One page of observations in a taxon's subtree, newest first, each with its first photo,
--           for the "load more" photo grid. Cursor pagination: pass the last row's ObservedDate and
--           ObservationID to get the next page. ID breaks ties between observations on the same date,
--           so no row is skipped or repeated. Page size is clamped to 1..100.
--           Requires taxonomy.view, only returns observations inside the session's scope.
-- History:
-- 2026-11-08  Jay Jorney Pua          Created the procedure.
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

    DECLARE @ID_User INT;

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

    SELECT
        scoped_taxa.ID
    INTO
        #scoped_taxa
    FROM
        dbo.fnSession_ScopedSubtreeTaxa(@ID_Session, @ID_Taxon) scoped_taxa;

    CREATE CLUSTERED INDEX IX_scoped_taxa ON #scoped_taxa (ID);

    SELECT TOP (@PageSize)
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
        dbo.Observation observations
    INNER JOIN
        #scoped_taxa scoped_taxa
        ON observations.ID_Taxon = scoped_taxa.ID
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
    OPTION (RECOMPILE);
END
GO