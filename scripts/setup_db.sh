#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${MSSQL_SA_PASSWORD:-}" ]]; then
  echo 'Falta la contraseña MSSQL_SA_PASSWORD'
  exit 1
fi

CONTENEDOR="empresa-sqlserver"
SQLCMD="/opt/mssql-tools18/bin/sqlcmd"

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

echo "Ejecutando scripts SQL..."
for archivo in sql/create_database.sql sql/create_tables.sql sql/create_procedure.sql sql/create_trigger.sql sql/test_data.sql; do
  echo "Ejecutando: $archivo"
  docker exec -i -e "SQLCMDPASSWORD=$MSSQL_SA_PASSWORD" "$CONTENEDOR" "$SQLCMD" -S localhost -U sa -C -b -d master -i /dev/stdin < "$archivo"
done

echo "Base de datos lista."
