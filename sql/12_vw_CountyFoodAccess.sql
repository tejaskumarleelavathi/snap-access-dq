USE SnapAccess;
GO

-- views can't hold an order, so query it with ORDER BY PriorityRank
CREATE OR ALTER VIEW dw.vw_CountyFoodAccess
AS
WITH counts AS (
    SELECT
        c.CountyKey,
        c.StateAbbr,
        c.CountyName,
        fa.Population2010,
        fa.LowIncomeLowAccessPct,
        ISNULL(a14.ActiveStores, 0) AS Stores2014,
        ISNULL(a19.ActiveStores, 0) AS Stores2019,
        ISNULL(a24.ActiveStores, 0) AS Stores2024
    FROM dw.DimCounty c
    JOIN dw.CountyFoodAccess fa ON fa.CountyKey = c.CountyKey
    LEFT JOIN dw.fn_ActiveStoresByCounty('2014-12-31') a14 ON a14.CountyKey = c.CountyKey
    LEFT JOIN dw.fn_ActiveStoresByCounty('2019-12-31') a19 ON a19.CountyKey = c.CountyKey
    LEFT JOIN dw.fn_ActiveStoresByCounty('2024-12-31') a24 ON a24.CountyKey = c.CountyKey
)
SELECT
    StateAbbr,
    CountyName,
    Population2010,
    Stores2014,
    Stores2019,
    Stores2024,
    Stores2024 - Stores2014 AS NetChange,
    -- population is the 2010 census figure the atlas was built on
    CAST(10000.0 * Stores2024 / NULLIF(Population2010, 0) AS DECIMAL(8,2)) AS StoresPer10K,
    LowIncomeLowAccessPct,
    ROW_NUMBER() OVER (
        ORDER BY IIF(Stores2024 < Stores2014, 0, 1), LowIncomeLowAccessPct DESC, Stores2024 - Stores2014
    ) AS PriorityRank
FROM counts;
GO
