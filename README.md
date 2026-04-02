# snap-access-dq

SQL Server pipeline that loads the USDA SNAP retailer history and the USDA Food Access Research Atlas, cleans and checks them, and builds a county-level view of SNAP store counts against food access for Oregon, Washington, Idaho and Nevada. All transformation, validation and reconciliation is T-SQL.

## Data

Both files go in `./data`.

- **SNAP retailer historical data**, USDA Food and Nutrition Service: https://www.fns.usda.gov/snap/retailer/historical-data
  File: `snap-retailer-locator-data2005-2025.zip`, which contains `Historical SNAP Retailer Locator Data 2005-2025.csv`. 703,441 rows, one per store authorization period: record id, name, store type, address, county, lat/long, authorization date and end date. A store that gets re-authorized keeps its record id and gets a new row.
- **Food Access Research Atlas 2019**, USDA Economic Research Service: https://www.ers.usda.gov/data-products/food-access-research-atlas/download-the-data
  File: `FoodAccessResearchAtlasData2019.xlsx`. ERS now lists it as the "Large Retailer Access Map (LRAM), formerly known as the Food Access Research Atlas". 72,531 census tracts, 147 columns, 2010 census population. The tract id's first five digits are the county FIPS code.

`scripts/xlsx_to_csv.py` turns the atlas data sheet into CSV (standard library only). That and unzipping are the only steps outside SQL.

## Running it

Needs Docker and python3.

```
./run_all.sh
```

That unzips and converts the files if needed, starts SQL Server 2022 in Docker (host port 14330, override with `SQL_PORT`), runs `sql/*.sql` in order, executes `etl.usp_RunPipeline`, then prints the results from `sql/report/results.sql`. It is safe to run again. Each run reloads raw and staging, and DimRetailer only changes if the source does.

Layers: `raw` (all NVARCHAR, as received) -> `stg` (typed, standardized, filtered to the four states) -> `dw` (DimRetailer SCD2, DimCounty, FactRetailerAuthorization, CountyFoodAccess). Rejected rows, DQ results, county match reviews and reconciliation results go in `qa`. Every step logs to `etl.EtlRun`.

To connect directly: `localhost,14330`, user `sa`, password from `MSSQL_SA_PASSWORD` (default in `docker-compose.yml`).

## Data problems found

Counts are from run 2, for the 30,130 rows in OR/WA/ID/NV. Run 1 was identical.

| check | rows |
|---|---|
| authorization date is the placeholder 1930-01-01 | 480 |
| same store (name + address + zip) with overlapping authorization periods | 407 |
| lat/long missing (0,0) or outside the state's box | 199 |
| missing street number or street name | 125 |
| end date before authorization date | 4 |
| exact duplicate rows | 0 |
| zip doesn't match state | 0 |
| authorization date in the future | 0 |

Other things that came up while loading:

- Record ID isn't unique. 1,878 PNW stores have more than one authorization row, so the fact grain is record id + authorization date and DimRetailer has one row per record id.
- Open authorizations have a single space as the end date, not a blank. A plain `TRY_CONVERT` turns an empty string into 1900-01-01, so it has to go through `NULLIF` first.
- The 1930 placeholder isn't harmless. 213 of those rows are still active at the end of 2024, so they count in every snapshot even though their real start date is unknown.
- Most overlaps are an old record left open after the store was re-authorized under a new record id, which looks like an ownership change where the old record wasn't closed in time.
- 15.7K store names nationally are quoted and contain commas. 87 rows have non-ASCII characters (curly apostrophes, non-breaking spaces), and at least one name is already double-encoded in USDA's file (`La PiÃ?Â±ata`). SQL Server on Linux doesn't support `CODEPAGE` on BULK INSERT, so the format files in `sql/format` declare a UTF-8 collation per field.
- Store names switch from all caps in older records to mixed case in newer ones. Staging upper-cases them so SCD2 doesn't treat a case change as a new version.
- The atlas writes the literal string `NULL` for tracts that aren't low access.
- Nothing was quarantined. Every PNW row had a usable record id, store name and authorization date, and no record id + authorization date pair conflicted. All 136 counties in the four states matched between the two sources, so the county review table is empty.

Reconciliation, all passing:

| check | expected | actual |
|---|---|---|
| raw -> stg.SnapRetailer (loaded 30,130 + quarantined 0 + deduped 0 + filtered 673,311) | 703,441 | 703,441 |
| raw -> stg.FoodAccessTract (loaded 3,249 + quarantined 0 + filtered 69,282) | 72,531 | 72,531 |
| stg -> FactRetailerAuthorization | 30,130 | 30,130 |
| one current DimRetailer row per staged store | 28,065 | 28,065 |
| active stores at 2024-12-31, dw vs stg, per county (134 counties, 0 mismatched) | 11,403 | 11,403 |
| atlas counties matched (or in review) | 136 | 136 |

The second run added no DimRetailer versions: 28,065 unchanged, 0 new, still 28,065 rows in total.

## County view

`SELECT * FROM dw.vw_CountyFoodAccess ORDER BY PriorityRank`. Counties that lost stores since 2014 come first, ordered by low-income/low-access share.

| state | county | pop 2010 | 2014 | 2019 | 2024 | net | per 10K | LILA % |
|---|---|---|---|---|---|---|---|---|
| OR | Wheeler | 1,441 | 4 | 3 | 3 | -1 | 20.82 | 51.06 |
| ID | Camas | 1,117 | 1 | 0 | 0 | -1 | 0.00 | 44.47 |
| NV | Esmeralda | 783 | 1 | 0 | 0 | -1 | 0.00 | 43.74 |
| OR | Gilliam | 1,871 | 4 | 3 | 3 | -1 | 16.03 | 20.81 |
| OR | Grant | 7,445 | 17 | 12 | 13 | -4 | 17.46 | 14.51 |
| OR | Baker | 16,134 | 23 | 23 | 21 | -2 | 13.02 | 14.51 |
| WA | Columbia | 4,078 | 6 | 5 | 5 | -1 | 12.26 | 14.23 |
| ID | Boise | 7,028 | 10 | 8 | 7 | -3 | 9.96 | 13.85 |
| WA | Stevens | 43,531 | 42 | 38 | 41 | -1 | 9.42 | 12.50 |
| WA | Lincoln | 10,570 | 11 | 9 | 9 | -2 | 8.51 | 12.14 |

LILA % is the atlas low-income, low-access population (1 mile urban / 10 miles rural) as a share of the county's 2010 population.

## What it suggests

Across the four states the number of SNAP-authorized stores is roughly flat: 11,122 at the end of 2014, 10,804 in 2019 and 11,403 in 2024. 39 of 136 counties ended with fewer stores than in 2014. The largest losses in absolute terms were in the Seattle and Portland metros (King -94, Multnomah -87), where low-access shares are low. The counties at the top of the view are small rural ones where a single store is a large part of the base, and Camas (ID) and Esmeralda (NV) had no active SNAP retailer at the end of 2024. As a group, counties with 10% or more of residents low-income and low-access didn't lose stores (1,002 to 1,078) and have slightly more stores per resident than the rest. That points to distance, not store count, as the access problem there, which is what the atlas measures. This is a county-level comparison using 2010 population and the 2019 atlas, and it counts a convenience store the same as a supermarket, so treat it as a list of places to look at, not a conclusion.
