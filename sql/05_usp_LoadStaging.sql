USE SnapAccess;
GO

CREATE OR ALTER PROCEDURE etl.usp_LoadStaging
    @RunID INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @started DATETIME2(0) = SYSDATETIME(),
        @read INT, @filtered INT, @deduped INT, @quarantined INT, @loaded INT;

    TRUNCATE TABLE stg.SnapRetailer;
    DROP TABLE IF EXISTS #snap, #typed;

    SELECT @read = COUNT(*) FROM raw.SnapRetailer;

    SELECT @filtered = COUNT(*)
    FROM raw.SnapRetailer r
    WHERE NOT EXISTS (SELECT 1 FROM stg.StateRef s WHERE s.StateAbbr = UPPER(TRIM(r.[State])));

    -- exact duplicates collapse here, Copies keeps the count
    SELECT
        r.[Record ID], r.[Store Name], r.[Store Type], r.[Street Number], r.[Street Name],
        r.[Additional Address], r.[City], r.[State], r.[Zip Code], r.[Zip4], r.[County],
        r.[Latitude], r.[Longitude], r.[Authorization Date], r.[End Date],
        COUNT(*) AS Copies
    INTO #snap
    FROM raw.SnapRetailer r
    WHERE EXISTS (SELECT 1 FROM stg.StateRef s WHERE s.StateAbbr = UPPER(TRIM(r.[State])))
    GROUP BY
        r.[Record ID], r.[Store Name], r.[Store Type], r.[Street Number], r.[Street Name],
        r.[Additional Address], r.[City], r.[State], r.[Zip Code], r.[Zip4], r.[County],
        r.[Latitude], r.[Longitude], r.[Authorization Date], r.[End Date];

    SELECT @deduped = ISNULL(SUM(Copies - 1), 0) FROM #snap;

    SELECT
        s.*,
        TRY_CONVERT(INT, TRIM(s.[Record ID])) AS RecordID,
        etl.fn_CleanText(s.[Store Name]) AS StoreName,
        -- open authorizations have a single space as end date, and '' converts to 1900-01-01
        TRY_CONVERT(DATE, NULLIF(TRIM(s.[Authorization Date]), ''), 101) AS AuthorizationDate,
        TRY_CONVERT(DATE, NULLIF(TRIM(s.[End Date]), ''), 101) AS EndDate,
        CAST(NULL AS NVARCHAR(400)) AS Reason
    INTO #typed
    FROM #snap s;

    -- same store re-authorized gets a new row with the same record id, so the key is id + auth date
    WITH k AS (
        SELECT t.*, COUNT(*) OVER (PARTITION BY t.RecordID, t.AuthorizationDate) AS KeyRows
        FROM #typed t
    )
    UPDATE k
    SET Reason = NULLIF(CONCAT_WS('; ',
        CASE WHEN RecordID IS NULL THEN 'record id missing or not numeric' END,
        CASE WHEN StoreName IS NULL THEN 'store name missing' END,
        CASE WHEN AuthorizationDate IS NULL THEN 'authorization date missing or unparseable' END,
        CASE WHEN EndDate IS NULL AND TRIM([End Date]) <> '' THEN 'end date unparseable' END,
        CASE WHEN KeyRows > 1 AND RecordID IS NOT NULL AND AuthorizationDate IS NOT NULL
            THEN 'conflicting rows for same record id and authorization date' END
    ), '');

    INSERT INTO qa.Quarantine (RunID, SourceTable, SourceKey, Reason, RawValues)
    SELECT
        @RunID, 'raw.SnapRetailer', t.[Record ID], t.Reason,
        (SELECT t.[Record ID], t.[Store Name], t.[Store Type], t.[Street Number], t.[Street Name],
            t.[Additional Address], t.[City], t.[State], t.[Zip Code], t.[Zip4], t.[County],
            t.[Latitude], t.[Longitude], t.[Authorization Date], t.[End Date], t.Copies
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM #typed t
    WHERE t.Reason IS NOT NULL;

    SET @quarantined = @@ROWCOUNT;

    INSERT INTO stg.SnapRetailer (
        RecordID, StoreName, StoreNameNorm, StoreType, StreetNumber, StreetName, AddressLine,
        AdditionalAddress, City, StateAbbr, Zip5, Zip4, County, Latitude, Longitude,
        AuthorizationDate, EndDate, RunID)
    SELECT
        t.RecordID,
        t.StoreName,
        ISNULL(etl.fn_CleanText(TRANSLATE(t.StoreName, '.,''&-', '     ')), t.StoreName),
        ISNULL(etl.fn_CleanText(REPLACE(t.[Store Type], '''', '')), 'UNKNOWN'),
        a.StreetNumber,
        etl.fn_CleanText(t.[Street Name]),
        NULLIF(CONCAT_WS(' ', a.StreetNumber, st.StreetNorm), ''),
        etl.fn_CleanText(t.[Additional Address]),
        etl.fn_CleanText(t.City),
        UPPER(TRIM(t.[State])),
        z.Zip5,
        z.Zip4,
        etl.fn_CleanText(t.County),
        -- 0,0 is what usda puts in when the geocode failed
        NULLIF(TRY_CONVERT(DECIMAL(9,6), TRIM(t.Latitude)), 0),
        NULLIF(TRY_CONVERT(DECIMAL(9,6), TRIM(t.Longitude)), 0),
        t.AuthorizationDate,
        t.EndDate,
        @RunID
    FROM #typed t
    CROSS APPLY (
        SELECT
            etl.fn_CleanText(t.[Street Number]) AS StreetNumber,
            REPLACE(TRIM(t.[Zip Code]), '-', '') AS ZipRaw,
            TRIM(t.Zip4) AS Zip4Raw
    ) a
    CROSS APPLY (
        SELECT
            -- zips that passed through excel somewhere lose their leading zero
            CASE
                WHEN a.ZipRaw LIKE '[0-9][0-9][0-9][0-9][0-9]%' AND a.ZipRaw NOT LIKE '%[^0-9]%' THEN LEFT(a.ZipRaw, 5)
                WHEN a.ZipRaw NOT LIKE '%[^0-9]%' AND LEN(a.ZipRaw) BETWEEN 3 AND 4 THEN RIGHT('00000' + a.ZipRaw, 5)
            END AS Zip5,
            CASE
                WHEN a.Zip4Raw NOT LIKE '%[^0-9]%' AND LEN(a.Zip4Raw) BETWEEN 1 AND 4 THEN RIGHT('0000' + a.Zip4Raw, 4)
            END AS Zip4
    ) z
    -- token by token so 'Main Street NE' still gets its suffix fixed
    OUTER APPLY (
        SELECT STRING_AGG(ISNULL(sx.Standard, w.value), ' ') WITHIN GROUP (ORDER BY w.ordinal) AS StreetNorm
        FROM STRING_SPLIT(etl.fn_CleanText(TRANSLATE(t.[Street Name], '.,', '  ')), ' ', 1) w
        LEFT JOIN stg.StreetSuffix sx ON sx.Variant = w.value
    ) st
    WHERE t.Reason IS NULL;

    SET @loaded = @@ROWCOUNT;

    EXEC etl.usp_LogStep @RunID, 'stg.SnapRetailer', @started,
        @RowsRead = @read, @RowsLoaded = @loaded, @RowsQuarantined = @quarantined,
        @RowsDeduped = @deduped, @RowsFiltered = @filtered;

    -- atlas
    SET @started = SYSDATETIME();
    TRUNCATE TABLE stg.FoodAccessTract;
    DROP TABLE IF EXISTS #atlas;

    SELECT @read = COUNT(*) FROM raw.FoodAccessAtlas;

    SELECT @filtered = COUNT(*)
    FROM raw.FoodAccessAtlas a
    WHERE NOT EXISTS (SELECT 1 FROM stg.StateRef s WHERE s.StateName = TRIM(a.[State]));

    -- the atlas writes the literal string NULL where a tract isn't low access.
    -- going through float because a few values come out of excel in E notation
    SELECT
        a.[CensusTract], a.[State], a.[County], a.[Urban], a.[Pop2010], a.[LowIncomeTracts],
        a.[LILATracts_1And10], a.[LAPOP1_10], a.[LALOWI1_10], a.[PovertyRate],
        a.[MedianFamilyIncome], a.[TractSNAP],
        s.StateAbbr,
        TRIM(a.[CensusTract]) AS Tract,
        TRIM(a.[County]) AS CountyName,
        TRY_CONVERT(INT, a.[Pop2010]) AS Pop,
        COUNT(*) OVER (PARTITION BY TRIM(a.[CensusTract])) AS TractRows,
        CAST(NULL AS NVARCHAR(400)) AS Reason
    INTO #atlas
    FROM raw.FoodAccessAtlas a
    JOIN stg.StateRef s ON s.StateName = TRIM(a.[State]);

    UPDATE #atlas
    SET Reason = NULLIF(CONCAT_WS('; ',
        CASE WHEN Tract IS NULL OR Tract NOT LIKE REPLICATE('[0-9]', 11) THEN 'census tract not 11 digits' END,
        CASE WHEN Pop IS NULL THEN 'Pop2010 missing or not an integer' END,
        CASE WHEN NULLIF(CountyName, '') IS NULL THEN 'county missing' END,
        CASE WHEN TractRows > 1 THEN 'census tract appears more than once' END
    ), '');

    INSERT INTO qa.Quarantine (RunID, SourceTable, SourceKey, Reason, RawValues)
    SELECT
        @RunID, 'raw.FoodAccessAtlas', a.[CensusTract], a.Reason,
        (SELECT a.[CensusTract], a.[State], a.[County], a.[Urban], a.[Pop2010], a.[LowIncomeTracts],
            a.[LILATracts_1And10], a.[LAPOP1_10], a.[LALOWI1_10], a.[PovertyRate],
            a.[MedianFamilyIncome], a.[TractSNAP]
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM #atlas a
    WHERE a.Reason IS NOT NULL;

    SET @quarantined = @@ROWCOUNT;

    INSERT INTO stg.FoodAccessTract (
        CensusTract, CountyFIPS, StateAbbr, StateName, CountyName, IsUrban, Pop2010, IsLowIncome,
        IsLila1And10, LowAccessPop1And10, LowIncomeLowAccessPop1And10, PovertyRate,
        MedianFamilyIncome, SnapHouseholds, RunID)
    SELECT
        a.Tract,
        LEFT(a.Tract, 5),
        a.StateAbbr,
        TRIM(a.[State]),
        a.CountyName,
        TRY_CONVERT(BIT, a.[Urban]),
        a.Pop,
        TRY_CONVERT(BIT, a.[LowIncomeTracts]),
        TRY_CONVERT(BIT, a.[LILATracts_1And10]),
        TRY_CONVERT(DECIMAL(12,2), TRY_CONVERT(FLOAT, NULLIF(a.[LAPOP1_10], 'NULL'))),
        TRY_CONVERT(DECIMAL(12,2), TRY_CONVERT(FLOAT, NULLIF(a.[LALOWI1_10], 'NULL'))),
        TRY_CONVERT(DECIMAL(6,2), TRY_CONVERT(FLOAT, NULLIF(a.[PovertyRate], 'NULL'))),
        TRY_CONVERT(INT, TRY_CONVERT(FLOAT, NULLIF(a.[MedianFamilyIncome], 'NULL'))),
        TRY_CONVERT(INT, TRY_CONVERT(FLOAT, NULLIF(a.[TractSNAP], 'NULL'))),
        @RunID
    FROM #atlas a
    WHERE a.Reason IS NULL;

    SET @loaded = @@ROWCOUNT;

    EXEC etl.usp_LogStep @RunID, 'stg.FoodAccessTract', @started,
        @RowsRead = @read, @RowsLoaded = @loaded, @RowsQuarantined = @quarantined,
        @RowsDeduped = 0, @RowsFiltered = @filtered;
END;
GO
