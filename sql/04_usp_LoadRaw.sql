USE SnapAccess;
GO

CREATE OR ALTER PROCEDURE etl.usp_LogStep
    @RunID INT,
    @Step NVARCHAR(100),
    @StartedAt DATETIME2(0),
    @RowsRead INT = NULL,
    @RowsLoaded INT = NULL,
    @RowsQuarantined INT = NULL,
    @RowsDeduped INT = NULL,
    @RowsFiltered INT = NULL,
    @Status NVARCHAR(20) = 'Succeeded',
    @Message NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO etl.EtlRun (RunID, Step, StartedAt, EndedAt, RowsRead, RowsLoaded, RowsQuarantined, RowsDeduped, RowsFiltered, Status, Message)
    VALUES (@RunID, @Step, @StartedAt, SYSDATETIME(), @RowsRead, @RowsLoaded, @RowsQuarantined, @RowsDeduped, @RowsFiltered, @Status, @Message);
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_LoadRaw
    @RunID INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @started DATETIME2(0) = SYSDATETIME(), @rows INT;

    TRUNCATE TABLE raw.SnapRetailer;

    -- FORMAT = 'CSV' because ~15k store names are quoted and contain commas.
    -- CODEPAGE isn't supported on linux, the format file's utf8 collation is what keeps curly apostrophes intact
    BULK INSERT raw.SnapRetailer
    FROM '/data/Historical SNAP Retailer Locator Data 2005-2025.csv'
    WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', FORMATFILE = '/sql/format/snap_retailer.fmt', TABLOCK);

    SET @rows = @@ROWCOUNT;
    EXEC etl.usp_LogStep @RunID, 'raw.SnapRetailer', @started, @RowsRead = @rows, @RowsLoaded = @rows;

    SET @started = SYSDATETIME();
    TRUNCATE TABLE raw.FoodAccessAtlas;

    BULK INSERT raw.FoodAccessAtlas
    FROM '/data/FoodAccessResearchAtlasData2019.csv'
    WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', FORMATFILE = '/sql/format/food_access_atlas.fmt', TABLOCK);

    SET @rows = @@ROWCOUNT;
    EXEC etl.usp_LogStep @RunID, 'raw.FoodAccessAtlas', @started, @RowsRead = @rows, @RowsLoaded = @rows;
END;
GO
