# Proyecto Integrador: GitHub Actions + Docker + Microsoft SQL Server

![CI - Despliegue y Pruebas](https://github.com/RamoES12/Proyecto-Integrador-GitHub-Actions-Docker-Microsoft-SQL-Server/actions/workflows/deploy.yml/badge.svg)
![CI - Reporte Programado CSV](https://github.com/RamoES12/Proyecto-Integrador-GitHub-Actions-Docker-Microsoft-SQL-Server/actions/workflows/reporte.yml/badge.svg)
![SQL Server](https://img.shields.io/badge/SQL%20Server-2022%20Developer-red?logo=microsoftsqlserver)
![Docker](https://img.shields.io/badge/Docker-Containerized-blue?logo=docker)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-CI%2FCD-black?logo=githubactions)

## 📌 Descripción del Proyecto

Este proyecto automatiza el ciclo de vida, despliegue y pruebas continuas de una base de datos relacional **Microsoft SQL Server 2022** utilizando **GitHub Actions** y **Docker**.

A través de pipelines de Integración Continua (CI), se orquesta una instancia en contenedor de SQL Server en un runner de Ubuntu, se inicializa la base de datos `EmpresaDB`, se crean las tablas de negocio, y se ejecuta la lógica transaccional mediante procedimientos almacenados, triggers orientados a conjuntos (*set-based*) y gestión segura de credenciales con **GitHub Secrets**.

---

## 🎯 Objetivos

1. **Automatización CI/CD:** Desplegar una instancia efímera de SQL Server mediante Docker en GitHub Actions para validar esquemas y reglas de negocio.
2. **Seguridad:** Proteger credenciales maestras de la base de datos (`MSSQL_SA_PASSWORD`) a través de Secrets enmascarados.
3. **Reto Principal (Set-Based Processing):** Modificar el trigger de auditoría para procesar inserciones múltiples en lote (*multi-row inserts*) utilizando la tabla lógica `inserted` y tipos de tabla (TVP), superando las limitaciones y riesgos del procesamiento fila a fila (*RBAR*).
4. **Reto Avanzado (Control de Inventario):** Implementar la tabla `Inventario` y actualizar automáticamente sus existencias desde el procedimiento almacenado en cada venta registrada, validando la suficiencia de stock.
5. **Verificación Automatizada:** Ejecutar aserciones en T-SQL (`verify.sql`) que garanticen la integridad referencial y consistencia de datos en cada `push`.
6. **Reportes y Artefactos:** Configurar un segundo workflow programado (*cron*) que genere un reporte de ventas en CSV y lo publique como un artefacto descargable (**Artifact**).

---

## 📁 Estructura del Proyecto

```text
proyecto-sqlserver-actions
│
├── .github
│   └── workflows
│       ├── deploy.yml         # Pipeline principal: Inicia Docker, despliega EmpresaDB y ejecuta verify.sql
│       └── reporte.yml        # Pipeline programado: Genera reporte CSV y lo publica como Artifact
│
├── docs
│   ├── documento_tecnico.md   # Documento técnico detallado con fundamentos teóricos y arquitectónicos
│   └── evidencias
│       └── README.md          # Guía paso a paso para la captura y presentación de evidencias
│
├── scripts
│   └── setup_db.sh            # Script de orquestación bash: levanta Docker, health check y corre scripts DDL/DML
│
├── sql
│   ├── create_database.sql    # DDL: Creación de la base de datos EmpresaDB
│   ├── create_tables.sql      # DDL: Tablas Ventas, AuditoriaVentas e Inventario (Reto Avanzado)
│   ├── create_procedure.sql   # DDL: Tipo TVP TipoVentasInsertadas y sp_RegistrarAuditoria
│   ├── create_trigger.sql     # DDL: Trigger trg_AuditarVenta adaptado para lotes (Reto Principal)
│   ├── test_data.sql          # DML: Stock inicial y pruebas de inserción simple y múltiple
│   ├── verify.sql             # QA: Aserciones automatizadas en T-SQL con validación de reglas
│   └── report.sql             # DQL: Consulta formateada para exportación de reporte en CSV
│
└── README.md                  # Manual general del proyecto y guía de uso
```

---

## 🔐 Configuración de Secretos y Variables de Entorno

Para ejecutar los flujos de trabajo en GitHub Actions, es indispensable configurar el secreto del repositorio:

1. Ingrese a su repositorio en GitHub.
2. Vaya a **Settings** → **Secrets and variables** → **Actions**.
3. Haga clic en **New repository secret**.
4. Configure el secreto:
   - **Name:** `MSSQL_SA_PASSWORD`
   - **Secret:** `Str0ngP@ssword2026!`

### Variables de Entorno en los Workflows
```yaml
env:
  ACCEPT_EULA: 'Y'
  MSSQL_PID: Developer
  MSSQL_SA_PASSWORD: ${{ secrets.MSSQL_SA_PASSWORD }}
```

---

## 💡 Solución a los Retos

### 1. Reto Principal: Inserciones Múltiples y Procesamiento por Conjuntos
- **Problema Inicial:** En SQL Server los triggers `AFTER INSERT` se ejecutan **por sentencia** y no por fila. La asignación `SELECT @VentaID = VentaID FROM inserted` sobrescribe la variable en cada fila y únicamente audita un solo registro arbitrario cuando se realiza un `INSERT` con múltiples tuplas, perdiendo la auditoría del resto.
- **Solución Implementada:** Se definió un tipo de tabla de usuario (`dbo.TipoVentasInsertadas`). El trigger vuelca todas las tuplas de la pseudotabla lógica `inserted` hacia el Table-Valued Parameter (TVP) y lo traslada a `sp_RegistrarAuditoria`.
- **Procesamiento por Conjuntos (*Set-Based*):** El procedimiento realiza una única operación `INSERT INTO AuditoriaVentas ... SELECT ... FROM @Ventas`, eliminando cursores y bucles iterativos lentos (*RBAR*), garantizando complejidad algorítmica óptima y trazabilidad del 100% de las ventas.

### 2. Reto Avanzado: Gestión Automatizada de Inventario
- Se creó la tabla `dbo.Inventario (Producto, Existencias)`.
- En `sp_RegistrarAuditoria`, los productos vendidos en el lote se agrupan mediante `GROUP BY Producto` calculando `SUM(Cantidad)`.
- Se descuenta el stock mediante una actualización atómica:
  ```sql
  UPDATE inv
  SET inv.Existencias = inv.Existencias - t.CantidadTotal
  FROM dbo.Inventario AS inv
  INNER JOIN @TotalesAgrupados AS t ON t.Producto = inv.Producto
  WHERE inv.Existencias >= t.CantidadTotal;
  ```
- Si algún producto no existe o el stock disponible es insuficiente, se lanza una excepción con `THROW`, revirtiendo la transacción y evitando estados inconsistentes o stock negativo.

---

## 🚀 Workflows de GitHub Actions

### Workflow 01: Despliegue y Pruebas Continuas (`deploy.yml`)
- **Disparadores:** `push` a la rama `main` y ejecución manual (`workflow_dispatch`).
- **Tareas que ejecuta:**
  1. Descarga el repositorio (`actions/checkout@v4`).
  2. Ejecuta `scripts/setup_db.sh`: inicia el contenedor Docker de SQL Server 2022 Developer y sondea activamente hasta que el puerto 1433 esté listo para conexiones (`SELECT 1;`).
  3. Ejecuta en orden los scripts SQL de inicialización.
  4. Ejecuta `sql/verify.sql`: valida que existan exactamente 5 ventas, 5 auditorías (1:1) y existencias finales de inventario:
     - **Laptop:** $10 - (3 + 2) = \mathbf{5}$
     - **Monitor:** $12 - (5 + 1) = \mathbf{6}$
     - **Mouse:** $20 - 4 = \mathbf{16}$

### Workflow 02: Reporte Programado y Artifacts (`reporte.yml`)
- **Disparadores:** Programación semanal `cron: '0 12 * * 1'` (lunes 12:00 UTC) y ejecución manual (`workflow_dispatch`).
- **Tareas que ejecuta:**
  1. Inicializa SQL Server y carga los datos mediante `setup_db.sh`.
  2. Ejecuta `sql/report.sql` formateando los campos y exportando a `reportes/reporte_ventas.csv`.
  3. Valida que el archivo contenga las 6 líneas (cabecera + 5 ventas).
  4. Publica el archivo como un artefacto descargable mediante `actions/upload-artifact@v4` con retención de 30 días.

---

## 📖 Documentación y Entregables

- 📄 [Documento Técnico Completo](docs/documento_tecnico.md): Fundamentación teórica sobre el motor relacional, la pseudotabla `inserted`, optimizador CBO, álgebra relacional y comparativa matemática Set-Based vs RBAR.
- 📸 [Guía de Evidencias](docs/evidencias/README.md): Lista de capturas requeridas y cómo verificarlas.

---

## 👤 Autor

- **Nombre:** Raziel Alejandro Marín Ojeda
- **Usuario GitHub:** [`RamoES12`](https://github.com/RamoES12)
