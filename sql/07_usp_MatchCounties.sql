USE SnapAccess;
GO

CREATE OR ALTER PROCEDURE etl.usp_MatchCounties
    @RunID INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @started DATETIME2(0) = SYSDATETIME(), @read INT, @matched INT, @review INT;

    -- atlas is the county authority since its tract ids carry the fips code
    MERGE dw.DimCounty AS t
    USING (
        SELECT CountyFIPS, MAX(StateAbbr) AS StateAbbr, MAX(StateName) AS StateName, MAX(CountyName) AS CountyName
        FROM stg.FoodAccessTract
        GROUP BY CountyFIPS
    ) AS s
        ON t.CountyFIPS = s.CountyFIPS
    WHEN MATCHED AND t.CountyName <> s.CountyName THEN
        UPDATE SET CountyName = s.CountyName, CountyNameNorm = etl.fn_NormCountyName(s.CountyName)
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (CountyFIPS, StateAbbr, StateName, CountyName, CountyNameNorm)
        VALUES (s.CountyFIPS, s.StateAbbr, s.StateName, s.CountyName, etl.fn_NormCountyName(s.CountyName));

    DROP TABLE IF EXISTS #snap, #cand;

    SELECT DISTINCT StateAbbr, County, etl.fn_NormCountyName(County) AS CountyNorm
    INTO #snap
    FROM stg.SnapRetailer
    WHERE County IS NOT NULL;

    SET @read = @@ROWCOUNT;

    SELECT
        s.StateAbbr,
        s.County,
        d.CountyKey,
        d.CountyName,
        CASE WHEN UPPER(d.CountyName) IN (s.County, s.County + ' COUNTY') THEN 'exact' ELSE 'normalized' END AS MatchMethod,
        COUNT(*) OVER (PARTITION BY s.StateAbbr, s.County) AS Candidates
    INTO #cand
    FROM #snap s
    JOIN dw.DimCounty d
        ON d.StateAbbr = s.StateAbbr
        AND d.CountyNameNorm COLLATE Latin1_General_100_CI_AI = s.CountyNorm COLLATE Latin1_General_100_CI_AI;

    DELETE FROM etl.CountyXref;

    INSERT INTO etl.CountyXref (StateAbbr, SnapCountyName, CountyKey, MatchMethod, RunID)
    SELECT StateAbbr, County, CountyKey, MatchMethod, @RunID
    FROM #cand
    WHERE Candidates = 1;

    SET @matched = @@ROWCOUNT;

    DELETE FROM qa.CountyReview WHERE RunID = @RunID;

    -- more than one candidate means the normalization is too loose for that name, don't pick one
    INSERT INTO qa.CountyReview (RunID, Source, StateAbbr, CountyName, Reason, Candidates)
    SELECT @RunID, 'snap', StateAbbr, County, 'matches more than one atlas county', STRING_AGG(CountyName, ', ')
    FROM #cand
    WHERE Candidates > 1
    GROUP BY StateAbbr, County;

    INSERT INTO qa.CountyReview (RunID, Source, StateAbbr, CountyName, Reason)
    SELECT @RunID, 'snap', s.StateAbbr, s.County, 'no atlas county after normalizing'
    FROM #snap s
    WHERE NOT EXISTS (SELECT 1 FROM #cand c WHERE c.StateAbbr = s.StateAbbr AND c.County = s.County);

    INSERT INTO qa.CountyReview (RunID, Source, StateAbbr, CountyName, Reason)
    SELECT @RunID, 'atlas', d.StateAbbr, d.CountyName, 'no snap retailers mapped to this county'
    FROM dw.DimCounty d
    WHERE d.CountyKey > 0
        AND d.StateAbbr IN (SELECT StateAbbr FROM stg.StateRef)
        AND NOT EXISTS (SELECT 1 FROM etl.CountyXref x WHERE x.CountyKey = d.CountyKey);

    SELECT @review = COUNT(*) FROM qa.CountyReview WHERE RunID = @RunID AND Source = 'snap';

    EXEC etl.usp_LogStep @RunID, 'etl.MatchCounties', @started,
        @RowsRead = @read, @RowsLoaded = @matched, @RowsQuarantined = @review;
END;
GO
