USE SnapAccess;
GO

CREATE OR ALTER PROCEDURE etl.usp_LoadFacts
    @RunID INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @started DATETIME2(0) = SYSDATETIME(), @read INT, @loaded INT;

    SELECT @read = COUNT(*) FROM stg.SnapRetailer;

    -- full reload each run, the source is the full history anyway
    TRUNCATE TABLE dw.FactRetailerAuthorization;

    INSERT INTO dw.FactRetailerAuthorization (RecordID, AuthorizationDate, EndDate, RetailerKey, CountyKey, Latitude, Longitude, RunID)
    SELECT s.RecordID, s.AuthorizationDate, s.EndDate, r.RetailerKey, ISNULL(x.CountyKey, -1), s.Latitude, s.Longitude, @RunID
    FROM stg.SnapRetailer s
    JOIN dw.DimRetailer r ON r.RecordID = s.RecordID AND r.IsCurrent = 1
    LEFT JOIN etl.CountyXref x ON x.StateAbbr = s.StateAbbr AND x.SnapCountyName = s.County;

    SET @loaded = @@ROWCOUNT;

    EXEC etl.usp_LogStep @RunID, 'dw.FactRetailerAuthorization', @started, @RowsRead = @read, @RowsLoaded = @loaded;

    SET @started = SYSDATETIME();
    SELECT @read = COUNT(*) FROM stg.FoodAccessTract;

    TRUNCATE TABLE dw.CountyFoodAccess;

    -- TODO: tract-level join needs geography polygons for the stores, county is good enough for now
    INSERT INTO dw.CountyFoodAccess (CountyKey, TractCount, Population2010, LilaTractCount, LowIncomeLowAccessPop, LowIncomeLowAccessPct, SnapHouseholds, RunID)
    SELECT
        c.CountyKey,
        COUNT(*),
        SUM(t.Pop2010),
        SUM(CASE WHEN t.IsLila1And10 = 1 THEN 1 ELSE 0 END),
        -- NULL here means the tract isn't low access, so zero people
        ROUND(SUM(ISNULL(t.LowIncomeLowAccessPop1And10, 0)), 0),
        CAST(100.0 * SUM(ISNULL(t.LowIncomeLowAccessPop1And10, 0)) / NULLIF(SUM(t.Pop2010), 0) AS DECIMAL(5,2)),
        SUM(t.SnapHouseholds),
        @RunID
    FROM stg.FoodAccessTract t
    JOIN dw.DimCounty c ON c.CountyFIPS = t.CountyFIPS
    GROUP BY c.CountyKey;

    SET @loaded = @@ROWCOUNT;

    EXEC etl.usp_LogStep @RunID, 'dw.CountyFoodAccess', @started, @RowsRead = @read, @RowsLoaded = @loaded,
        @Message = 'rows read are tracts, rows loaded are counties';
END;
GO

CREATE OR ALTER FUNCTION dw.fn_ActiveStoresByCounty (@AsOf DATE)
RETURNS TABLE
AS
RETURN
    -- an end date on the as-of day means it was gone by close of business
    SELECT f.CountyKey, COUNT(DISTINCT f.RecordID) AS ActiveStores
    FROM dw.FactRetailerAuthorization f
    WHERE f.AuthorizationDate <= @AsOf
        AND (f.EndDate IS NULL OR f.EndDate > @AsOf)
    GROUP BY f.CountyKey;
GO
