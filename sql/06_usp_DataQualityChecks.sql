USE SnapAccess;
GO

CREATE OR ALTER PROCEDURE qa.usp_DataQualityChecks
    @RunID INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @started DATETIME2(0) = SYSDATETIME(),
        @today DATE = CAST(SYSDATETIME() AS DATE),
        @checked INT = (SELECT COUNT(*) FROM stg.SnapRetailer);

    DROP TABLE IF EXISTS #fail;
    CREATE TABLE #fail (CheckName NVARCHAR(100) NOT NULL, RecordID NVARCHAR(50) NULL);

    INSERT INTO #fail
    SELECT 'end date before authorization date', RecordID
    FROM stg.SnapRetailer
    WHERE EndDate < AuthorizationDate;

    INSERT INTO #fail
    SELECT 'authorization date in the future', RecordID
    FROM stg.SnapRetailer
    WHERE AuthorizationDate > @today;

    -- not in the original list, but 1/1/1930 is clearly a stand-in for "before records started"
    INSERT INTO #fail
    SELECT 'placeholder authorization date 1930-01-01', RecordID
    FROM stg.SnapRetailer
    WHERE AuthorizationDate = '1930-01-01';

    INSERT INTO #fail
    SELECT 'lat/long missing or outside state box', s.RecordID
    FROM stg.SnapRetailer s
    JOIN stg.StateRef r ON r.StateAbbr = s.StateAbbr
    WHERE s.Latitude IS NULL OR s.Longitude IS NULL
        OR s.Latitude NOT BETWEEN r.MinLat AND r.MaxLat
        OR s.Longitude NOT BETWEEN r.MinLon AND r.MaxLon;

    INSERT INTO #fail
    SELECT 'zip does not match state', s.RecordID
    FROM stg.SnapRetailer s
    JOIN stg.StateRef r ON r.StateAbbr = s.StateAbbr
    WHERE s.Zip5 IS NULL OR LEFT(s.Zip5, 3) NOT BETWEEN r.Zip3From AND r.Zip3To;

    INSERT INTO #fail
    SELECT 'missing address', RecordID
    FROM stg.SnapRetailer
    WHERE StreetNumber IS NULL OR StreetName IS NULL;

    -- staging already collapsed these, so look at raw for the same state filter
    INSERT INTO #fail
    SELECT 'exact duplicate rows', r.[Record ID]
    FROM raw.SnapRetailer r
    WHERE EXISTS (SELECT 1 FROM stg.StateRef s WHERE s.StateAbbr = UPPER(TRIM(r.[State])))
    GROUP BY
        r.[Record ID], r.[Store Name], r.[Store Type], r.[Street Number], r.[Street Name],
        r.[Additional Address], r.[City], r.[State], r.[Zip Code], r.[Zip4], r.[County],
        r.[Latitude], r.[Longitude], r.[Authorization Date], r.[End Date]
    HAVING COUNT(*) > 1;

    -- usda reuses store names after ownership changes, so name + address + zip together, not name alone.
    -- touching periods (end = next auth) are a normal re-authorization, not an overlap
    INSERT INTO #fail
    SELECT DISTINCT 'same store with overlapping authorization periods', a.RecordID
    FROM stg.SnapRetailer a
    JOIN stg.SnapRetailer b
        ON b.StoreNameNorm = a.StoreNameNorm
        AND b.AddressLine = a.AddressLine
        AND b.Zip5 = a.Zip5
        AND NOT (b.RecordID = a.RecordID AND b.AuthorizationDate = a.AuthorizationDate)
    WHERE a.AuthorizationDate < ISNULL(b.EndDate, '9999-12-31')
        AND b.AuthorizationDate < ISNULL(a.EndDate, '9999-12-31')
        AND ISNULL(a.EndDate, '9999-12-31') >= a.AuthorizationDate
        AND ISNULL(b.EndDate, '9999-12-31') >= b.AuthorizationDate;

    DELETE FROM qa.DqResult WHERE RunID = @RunID;

    -- counts are authorization rows, samples are distinct store ids
    INSERT INTO qa.DqResult (RunID, CheckName, FailCount, RowsChecked, SampleIDs)
    SELECT @RunID, c.CheckName, n.FailCount, @checked, smp.SampleIDs
    FROM (VALUES
        ('end date before authorization date'),
        ('authorization date in the future'),
        ('placeholder authorization date 1930-01-01'),
        ('lat/long missing or outside state box'),
        ('zip does not match state'),
        ('missing address'),
        ('exact duplicate rows'),
        ('same store with overlapping authorization periods')
    ) c (CheckName)
    CROSS APPLY (SELECT COUNT(*) AS FailCount FROM #fail f WHERE f.CheckName = c.CheckName) n
    OUTER APPLY (
        SELECT STRING_AGG(t.RecordID, ',') WITHIN GROUP (ORDER BY t.RecordID) AS SampleIDs
        FROM (SELECT DISTINCT TOP 10 f.RecordID FROM #fail f WHERE f.CheckName = c.CheckName ORDER BY f.RecordID) t
    ) smp;

    EXEC etl.usp_LogStep @RunID, 'qa.DataQualityChecks', @started, @RowsRead = @checked;
END;
GO
