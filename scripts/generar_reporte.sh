#!/usr/bin/env bash
set -euo pipefail

PASS="${MSSQL_SA_PASSWORD:-Str0ngP@ssword2026!}"

mkdir -p reportes
printf '"VentaID","Producto","Cantidad","Fecha"\n' > reportes/reporte_ventas.csv

docker exec -u 0 empresa-sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$PASS" -C -d EmpresaDB \
  -h -1 -W -i /tmp/sql/report.sql >> reportes/reporte_ventas.csv

cat reportes/reporte_ventas.csv
