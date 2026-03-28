USE SnapAccess;
GO

CREATE OR ALTER PROCEDURE qa.usp_Reconcile
    @RunID INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @started DATETIME2(0) = SYSDATETIME(), @asOf DATE = '2024-12-31',
        @read BIGINT, @loaded BIGINT, @quarantined BIGINT, @deduped BIGINT, @filtered BIGINT, @failed INT,
        @status NVARCHAR(20), @msg NVARCHAR(200);

    DELETE FROM qa.ReconResult WHERE RunID = @RunID;

    -- everything below is recounted from the tables, not taken from what the procs logged

    SELECT @read = COUNT(*) FROM raw.SnapRetailer;
    SELECT @filtered = COUNT(*)
    FROM raw.SnapRetailer r
    WHERE NOT EXISTS (SELECT 1 FROM stg.StateRef s WHERE s.StateAbbr = UPPER(TRIM(r.[State])));
    SELECT @deduped = ISNULL(SUM(n - 1), 0)
    FROM (
        SELECT COUNT(*) AS n
        FROM raw.SnapRetailer r
        WHERE EXISTS (SELECT 1 FROM stg.StateRef s WHERE s.StateAbbr = UPPER(TRIM(r.[State])))
        GROUP BY
            r.[Record ID], r.[Store Name], r.[Store Type], r.[Street Number], r.[Street Name],
            r.[Additional Address], r.[City], r.[State], r.[Zip Code], r.[Zip4], r.[County],
            r.[Latitude], r.[Longitude], r.[Authorization Date], r.[End Date]
    ) d;
    SELECT @loaded = COUNT(*) FROM stg.SnapRetailer;
    SELECT @quarantined = COUNT(*) FROM qa.Quarantine WHERE RunID = @RunID AND SourceTable = 'raw.SnapRetailer';

    INSERT INTO qa.ReconResult (RunID, CheckName, Expected, Actual, Passed, Detail)
    SELECT @RunID, 'row identity raw -> stg.SnapRetailer', @read, @loaded + @quarantined + @deduped + @filtered,
        IIF(@read = @loaded + @quarantined + @deduped + @filtered, 1, 0),
        CONCAT('loaded ', @loaded, ', quarantined ', @quarantined, ', deduped ', @deduped, ', filtered out by state ', @filtered);

    SELECT @read = COUNT(*) FROM raw.FoodAccessAtlas;
    SELECT @filtered = COUNT(*)
    FROM raw.FoodAccessAtlas a
    WHERE NOT EXISTS (SELECT 1 FROM stg.StateRef s WHERE s.StateName = TRIM(a.[State]));
    SELECT @loaded = COUNT(*) FROM stg.FoodAccessTract;
    SELECT @quarantined = COUNT(*) FROM qa.Quarantine WHERE RunID = @RunID AND SourceTable = 'raw.FoodAccessAtlas';

    INSERT INTO qa.ReconResult (RunID, CheckName, Expected, Actual, Passed, Detail)
    SELECT @RunID, 'row identity raw -> stg.FoodAccessTract', @read, @loaded + @quarantined + @filtered,
        IIF(@read = @loaded + @quarantined + @filtered, 1, 0),
        CONCAT('loaded ', @loaded, ', quarantined ', @quarantined, ', filtered out by state ', @filtered);

    SELECT @read = COUNT(*) FROM stg.SnapRetailer;
    SELECT @loaded = COUNT(*) FROM dw.FactRetailerAuthorization;

    INSERT INTO qa.ReconResult (RunID, CheckName, Expected, Actual, Passed, Detail)
    SELECT @RunID, 'row identity stg -> dw.FactRetailerAuthorization', @read, @loaded, IIF(@read = @loaded, 1, 0),
        CONCAT((SELECT COUNT(*) FROM dw.FactRetailerAuthorization WHERE CountyKey = -1), ' rows on the unknown county');

    SELECT @read = COUNT(DISTINCT RecordID) FROM stg.SnapRetailer;
    SELECT @loaded = COUNT(*) FROM dw.DimRetailer d WHERE d.IsCurrent = 1 AND d.RecordID IN (SELECT RecordID FROM stg.SnapRetailer);

    INSERT INTO qa.ReconResult (RunID, CheckName, Expected, Actual, Passed, Detail)
    SELECT @RunID, 'one current DimRetailer row per staged store', @read, @loaded, IIF(@read = @loaded, 1, 0),
        CONCAT((SELECT COUNT(*) FROM dw.DimRetailer), ' total versions');

    -- stg side is computed straight from staging, only borrowing the county mapping
    WITH s AS (
        SELECT ISNULL(x.CountyKey, -1) AS CountyKey, COUNT(DISTINCT st.RecordID) AS ActiveStores
        FROM stg.SnapRetailer st
        LEFT JOIN etl.CountyXref x ON x.StateAbbr = st.StateAbbr AND x.SnapCountyName = st.County
        WHERE st.AuthorizationDate <= @asOf
            AND (st.EndDate IS NULL OR st.EndDate > @asOf)
        GROUP BY ISNULL(x.CountyKey, -1)
    ),
    d AS (
        SELECT CountyKey, ActiveStores FROM dw.fn_ActiveStoresByCounty(@asOf)
    )
    INSERT INTO qa.ReconResult (RunID, CheckName, Expected, Actual, Passed, Detail)
    SELECT @RunID, 'active stores per county at 2024-12-31, dw vs stg',
        SUM(ISNULL(s.ActiveStores, 0)),
        SUM(ISNULL(d.ActiveStores, 0)),
        IIF(SUM(IIF(ISNULL(s.ActiveStores, 0) <> ISNULL(d.ActiveStores, 0), 1, 0)) = 0, 1, 0),
        CONCAT(COUNT(*), ' counties compared, ', SUM(IIF(ISNULL(s.ActiveStores, 0) <> ISNULL(d.ActiveStores, 0), 1, 0)), ' mismatched')
    FROM s
    FULL JOIN d ON d.CountyKey = s.CountyKey;

    WITH atlas AS (
        SELECT DISTINCT CountyFIPS, StateAbbr, CountyName FROM stg.FoodAccessTract
    )
    INSERT INTO qa.ReconResult (RunID, CheckName, Expected, Actual, Passed, Detail)
    SELECT @RunID, 'atlas counties matched to DimCounty and snap (or in review)',
        COUNT(*),
        SUM(IIF(ok.Matched = 1, 1, 0)),
        IIF(COUNT(*) = SUM(IIF(ok.Matched = 1, 1, 0)), 1, 0),
        CONCAT(SUM(ok.InReview), ' in review')
    FROM atlas a
    LEFT JOIN dw.DimCounty d ON d.CountyFIPS = a.CountyFIPS
    CROSS APPLY (
        SELECT
            IIF(EXISTS (SELECT 1 FROM qa.CountyReview r WHERE r.RunID = @RunID AND r.StateAbbr = a.StateAbbr AND r.CountyName = a.CountyName), 1, 0) AS InReview,
            IIF(d.CountyKey IS NOT NULL
                AND (EXISTS (SELECT 1 FROM etl.CountyXref x WHERE x.CountyKey = d.CountyKey)
                    OR EXISTS (SELECT 1 FROM qa.CountyReview r WHERE r.RunID = @RunID AND r.StateAbbr = a.StateAbbr AND r.CountyName = a.CountyName)),
                1, 0) AS Matched
    ) ok;

    SELECT @failed = COUNT(*) FROM qa.ReconResult WHERE RunID = @RunID AND Passed = 0;
    SET @status = IIF(@failed > 0, 'Failed', 'Succeeded');
    SET @msg = CONCAT(@failed, ' checks failed');

    EXEC etl.usp_LogStep @RunID, 'qa.Reconcile', @started, @Status = @status, @Message = @msg;

    IF @failed > 0
        THROW 50001, 'reconciliation failed, see qa.ReconResult for this run', 1;
END;
GO
