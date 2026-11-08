#!/usr/bin/env bash
# ==============================================================================
# Proyecto Integrador: GitHub Actions + Docker + Microsoft SQL Server
# Archivo: scripts/setup_db.sh
# Descripción: Inicialización del contenedor Docker con Microsoft SQL Server 2022,
# espera de disponibilidad (health check) y ejecución secuencial de scripts DDL/DML.
# ==============================================================================

set -euo pipefail

# 1. Validación de secreto de contraseña
if [[ -z "${MSSQL_SA_PASSWORD:-}" ]]; then
  echo '::error::Variable o Secret MSSQL_SA_PASSWORD no está definida.'
  exit 1
fi

CONTENEDOR="empresa-sqlserver"
SQLCMD="/opt/mssql-tools18/bin/sqlcmd"

echo "==> Iniciando contenedor Docker con Microsoft SQL Server 2022..."
docker run --detach \
  --name "$CONTENEDOR" \
  --env ACCEPT_EULA \
  --env MSSQL_PID \
  --env MSSQL_SA_PASSWORD \
  --publish 127.0.0.1:1433:1433 \
  mcr.microsoft.com/mssql/server:2022-latest

echo "==> Esperando a que el motor SQL Server esté listo para recibir conexiones..."
listo=0
for intento in $(seq 1 90); do
  if docker exec \
      -e "SQLCMDPASSWORD=$MSSQL_SA_PASSWORD" \
      "$CONTENEDOR" "$SQLCMD" \
      -S localhost -U sa -C -b -Q 'SELECT 1;' >/dev/null 2>&1; then
    listo=1
    break
  fi

  if [[ "$(docker inspect -f '{{.State.Running}}' "$CONTENEDOR")" == 'false' ]]; then
    echo '::error::El contenedor de SQL Server se detuvo inesperadamente.'
    docker logs "$CONTENEDOR" 2>&1 | tail -n 100
    exit 1
  fi

  sleep 2
done

if [[ "$listo" -ne 1 ]]; then
  echo '::error::Tiempo de espera agotado sin respuesta de SQL Server.'
  docker logs "$CONTENEDOR" 2>&1 | tail -n 100
  exit 1
fi

echo "==> SQL Server se encuentra operativo. Ejecutando scripts de inicialización..."

ARCHIVOS=(
  "sql/create_database.sql"
  "sql/create_tables.sql"
  "sql/create_procedure.sql"
  "sql/create_trigger.sql"
  "sql/test_data.sql"
)

for archivo in "${ARCHIVOS[@]}"; do
  echo "--> Ejecutando: $archivo"
  docker exec -i \
    -e "SQLCMDPASSWORD=$MSSQL_SA_PASSWORD" \
    "$CONTENEDOR" "$SQLCMD" \
    -S localhost -U sa -C -b -d master -i /dev/stdin < "$archivo"
done

echo "==> Base de datos EmpresaDB, objetos de negocio y datos de prueba desplegados con éxito."
