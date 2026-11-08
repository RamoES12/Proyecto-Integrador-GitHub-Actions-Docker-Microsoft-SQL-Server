#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${MSSQL_SA_PASSWORD:-}" ]]; then
  echo 'Falta la contraseña MSSQL_SA_PASSWORD'
  exit 1
fi

CONTENEDOR="empresa-sqlserver"
SQLCMD="/opt/mssql-tools18/bin/sqlcmd"

echo "Limpiando contenedor previo si existe..."
docker rm -f "$CONTENEDOR" >/dev/null 2>&1 || true

echo "Iniciando SQL Server en Docker..."
docker run --detach \
  --name "$CONTENEDOR" \
  --env ACCEPT_EULA \
  --env MSSQL_PID \
  --env MSSQL_SA_PASSWORD \
  --publish 127.0.0.1:1433:1433 \
  mcr.microsoft.com/mssql/server:2022-latest

echo "Esperando que SQL Server este listo..."
listo=0
for intento in $(seq 1 90); do
  if docker exec -e "SQLCMDPASSWORD=$MSSQL_SA_PASSWORD" "$CONTENEDOR" "$SQLCMD" -S localhost -U sa -C -b -Q 'SELECT 1;' >/dev/null 2>&1; then
    listo=1
    break
  fi
  sleep 2
done

if [[ "$listo" -ne 1 ]]; then
  echo 'No se pudo conectar a SQL Server'
  exit 1
fi

echo "Copiando scripts SQL dentro del contenedor..."
docker exec -u 0 "$CONTENEDOR" mkdir -p /tmp/sql
docker cp sql/. "$CONTENEDOR":/tmp/sql/
docker exec -u 0 "$CONTENEDOR" chmod -R 777 /tmp/sql

echo "Ejecutando scripts SQL..."
for archivo in create_database.sql create_tables.sql create_procedure.sql create_trigger.sql test_data.sql; do
  echo "Ejecutando: $archivo"
  docker exec -u 0 -e "SQLCMDPASSWORD=$MSSQL_SA_PASSWORD" "$CONTENEDOR" "$SQLCMD" -S localhost -U sa -C -b -d master -i "/tmp/sql/$archivo"
done

echo "Base de datos lista."
