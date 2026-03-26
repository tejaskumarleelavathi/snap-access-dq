USE SnapAccess;
GO

CREATE OR ALTER PROCEDURE etl.usp_LoadDimRetailer
    @RunID INT
AS
BEGIN
    SET NOCOUNT ON;
    -- ValidFrom/ValidTo are load time, not business time. the file has no change history of its own
    DECLARE @started DATETIME2(0) = SYSDATETIME(), @now DATETIME2(0) = SYSDATETIME(),
        @read INT, @keysBefore INT, @newKeys INT, @newVersions INT, @loaded INT, @msg NVARCHAR(200);

    DROP TABLE IF EXISTS #src;

    -- one row per store, latest authorization wins
    WITH latest AS (
        SELECT s.*, ROW_NUMBER() OVER (PARTITION BY s.RecordID ORDER BY s.AuthorizationDate DESC) AS rn
        FROM stg.SnapRetailer s
    )
    SELECT
        RecordID, StoreName, StoreType, AddressLine, City, StateAbbr, Zip5,
        HASHBYTES('SHA2_256', CONCAT(StoreName, '|', StoreType, '|', AddressLine, '|', City, '|', StateAbbr, '|', Zip5)) AS RowHash
    INTO #src
    FROM latest
    WHERE rn = 1;

    SET @read = @@ROWCOUNT;

    SELECT @keysBefore = COUNT(DISTINCT RecordID) FROM dw.DimRetailer;

    -- MERGE expires changed rows and inserts brand new stores, the outer insert adds the new version
    INSERT INTO dw.DimRetailer (RecordID, StoreName, StoreType, AddressLine, City, StateAbbr, Zip5, RowHash, ValidFrom, ValidTo, IsCurrent)
    SELECT RecordID, StoreName, StoreType, AddressLine, City, StateAbbr, Zip5, RowHash, @now, '9999-12-31', 1
    FROM (
        MERGE dw.DimRetailer AS t
        USING #src AS s
            ON t.RecordID = s.RecordID AND t.IsCurrent = 1
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (RecordID, StoreName, StoreType, AddressLine, City, StateAbbr, Zip5, RowHash, ValidFrom, ValidTo, IsCurrent)
            VALUES (s.RecordID, s.StoreName, s.StoreType, s.AddressLine, s.City, s.StateAbbr, s.Zip5, s.RowHash, @now, '9999-12-31', 1)
        WHEN MATCHED AND t.RowHash <> s.RowHash THEN
            UPDATE SET IsCurrent = 0, ValidTo = @now
        OUTPUT $action AS MergeAction, s.*
    ) AS m
    WHERE m.MergeAction = 'UPDATE';

    SET @newVersions = @@ROWCOUNT;

    SELECT @newKeys = COUNT(DISTINCT RecordID) - @keysBefore FROM dw.DimRetailer;
    SET @loaded = @newKeys + @newVersions;
    SET @msg = CONCAT('new stores ', @newKeys, ', new versions ', @newVersions, ', unchanged ', @read - @newKeys - @newVersions);

    -- TODO: stores that drop out of the file entirely never get expired. fine while we always load the full history file
    EXEC etl.usp_LogStep @RunID, 'dw.DimRetailer', @started,
        @RowsRead = @read, @RowsLoaded = @loaded, @Message = @msg;
END;
GO
