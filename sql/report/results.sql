SET NOCOUNT ON;

DECLARE @run INT = (SELECT MAX(RunID) FROM etl.EtlRun WHERE Step = 'pipeline');

PRINT 'etl log';
SELECT RunID, Step, Status, RowsRead, RowsLoaded, RowsQuarantined, RowsDeduped, RowsFiltered, Message
FROM etl.EtlRun
WHERE RunID = @run
ORDER BY EtlRunID;

PRINT 'dq results';
SELECT CheckName, FailCount, RowsChecked, SampleIDs
FROM qa.DqResult
WHERE RunID = @run
ORDER BY FailCount DESC;

PRINT 'quarantine';
SELECT SourceTable, Reason, COUNT(*) AS Rows
FROM qa.Quarantine
WHERE RunID = @run
GROUP BY SourceTable, Reason;

PRINT 'county review';
SELECT Source, StateAbbr, CountyName, Reason, Candidates
FROM qa.CountyReview
WHERE RunID = @run;

PRINT 'reconciliation';
SELECT CheckName, Expected, Actual, Passed, Detail
FROM qa.ReconResult
WHERE RunID = @run;

PRINT 'dim retailer versions';
SELECT COUNT(*) AS TotalRows, SUM(CAST(IsCurrent AS INT)) AS CurrentRows, COUNT(DISTINCT RecordID) AS Stores
FROM dw.DimRetailer;

PRINT 'county view, top 10';
SELECT TOP 10 StateAbbr, CountyName, Population2010, Stores2014, Stores2019, Stores2024, NetChange, StoresPer10K, LowIncomeLowAccessPct
FROM dw.vw_CountyFoodAccess
ORDER BY PriorityRank;
