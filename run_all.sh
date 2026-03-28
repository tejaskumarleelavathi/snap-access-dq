#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

PW="${MSSQL_SA_PASSWORD:-SnapAccess_dq1}"
SNAP_CSV="data/Historical SNAP Retailer Locator Data 2005-2025.csv"
ATLAS_XLSX="data/FoodAccessResearchAtlasData2019.xlsx"
ATLAS_CSV="data/FoodAccessResearchAtlasData2019.csv"

if [ ! -f "$SNAP_CSV" ]; then
  unzip -o -q data/snap-retailer-locator-data*.zip -d data
fi
if [ ! -f "$ATLAS_CSV" ]; then
  python3 scripts/xlsx_to_csv.py "$ATLAS_XLSX" "Food Access Research Atlas" "$ATLAS_CSV"
fi

docker compose up -d

sqlcmd() {
  docker compose exec -T sql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$PW" -C -b -I "$@"
}

echo "waiting for sql server"
ready=0
for _ in $(seq 1 90); do
  if sqlcmd -Q "SELECT 1" >/dev/null 2>&1; then ready=1; break; fi
  sleep 2
done
if [ "$ready" -ne 1 ]; then
  echo "sql server never came up, check: docker compose logs sql" >&2
  exit 1
fi

for f in sql/*.sql; do
  echo "running $f"
  sqlcmd -i "/$f"
done

echo "running pipeline"
sqlcmd -d SnapAccess -Q "EXEC etl.usp_RunPipeline"

sqlcmd -d SnapAccess -i /sql/report/results.sql -W -s " | "
