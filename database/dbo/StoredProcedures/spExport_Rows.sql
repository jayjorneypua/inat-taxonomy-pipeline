--=====================================================================================================
--                                        dbo spExport_Rows
--=====================================================================================================
-- Purpose:  All rows of one export: observations in the job's taxon subtree, inside the scope of
--           the session that asked for it, newest first, with the first photo. Capped at @MaxRows.
--           Called by the export worker only, never directly by a user request.
-- History:
-- 2026-11-16  Jay Jorney Pua          Created the procedure.
--=====================================================================================================
CREATE PROCEDURE dbo.spExport_Rows
    @ID_Export_Job          INT
  , @MaxRows                INT             = 100000
AS BEGIN
    SET NOCOUNT ON;

    DECLARE @ID_Session BIGINT;
    DECLARE @ID_Taxon   INT;

    SELECT
        @ID_Session = export_jobs.ID_Session
      , @ID_Taxon   = export_jobs.ID_Taxon
    FROM
        dbo.Export_Job export_jobs
    WHERE
        export_jobs.ID = @ID_Export_Job;

    SELECT
        scoped_taxa.ID
    INTO
        #scoped_taxa
    FROM
        dbo.fnSession_ScopedSubtreeTaxa(@ID_Session, @ID_Taxon) scoped_taxa;

    CREATE CLUSTERED INDEX IX_scoped_taxa ON #scoped_taxa (ID);

    SELECT TOP (@MaxRows)
        observations.ID                     AS ObservationID
      , observations.ObservationUuid
      , observations.ObservedDate
      , observations.ID_Taxon
      , taxa.ScientificName
      , taxa.CommonName
      , taxa.Rank
      , observers.DisplayName               AS ObserverDisplayName
      , observations.PhotoCount
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
            photos.MediumUrl
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
      , observations.ID DESC
    OPTION (RECOMPILE);
END
GO