# Documento Técnico: Automatización de Despliegue y Lógica de Negocio con GitHub Actions, Docker y Microsoft SQL Server

**Proyecto Integrador**  
**Autor:** Raziel Alejandro Marín Ojeda (`RamoES12`)  
**Fecha:** Noviembre 2026  
**Repositorio:** `Proyecto-Integrador-GitHub-Actions-Docker-Microsoft-SQL-Server`  

---

## 1. Introducción y Objetivo General

En el desarrollo moderno de software orientado a datos, la integración continua (CI) aplicada a bases de datos relacionales garantiza que los esquemas, objetos de negocio (procedimientos almacenados, funciones, triggers) y restricciones de integridad se validen automáticamente en cada cambio de código.

El objetivo general de este proyecto es construir una solución completa y robusta de Integración Continua (CI/CD) que:
1. Inicie una instancia efímera de **Microsoft SQL Server 2022** en un contenedor **Docker** dentro de un runner de **GitHub Actions**.
2. Despliegue una base de datos denominada `EmpresaDB` con su esquema relacional (`Ventas`, `AuditoriaVentas` e `Inventario`).
3. Resuelva el **Reto Principal**: modificar el trigger de auditoría para procesar inserciones masivas de datos en lote (*multi-row inserts*) mediante el paradigma orientado a conjuntos (*set-based*), eliminando el fallo del código inicial y prescindiendo de cursores o bucles lentos (*RBAR*).
4. Resuelva el **Reto Avanzado**: integrar la tabla `Inventario` y actualizar automáticamente sus existencias desde el procedimiento almacenado en cada venta registrada, garantizando la consistencia y validación de stock suficiente.
5. Automatice pruebas unitarias y de integración mediante aserciones en T-SQL (`verify.sql`).
6. Gestione credenciales de forma segura mediante **GitHub Secrets**.
7. Implemente un segundo flujo de trabajo programado (*cron*) que genere un reporte en formato CSV y lo publique como un artefacto descargable (**Artifact**) en GitHub Actions.

---

## 2. Tecnologías Involucradas y Arquitectura

```
+-------------------------------------------------------------------------------+
|                             GitHub Repository                                 |
|   .github/workflows/deploy.yml          .github/workflows/reporte.yml         |
+-------------------------------------------------------------------------------+
                                      | (Trigger: push / schedule / dispatch)
                                      v
+-------------------------------------------------------------------------------+
|                       GitHub Actions Runner (Ubuntu Linux)                    |
|                                                                               |
|   +-----------------------------------------------------------------------+   |
|   |                         Docker Container Engine                       |   |
|   |                                                                       |   |
|   |   [ Contenedor: empresa-sqlserver ]                                   |   |
|   |   Imagen: mcr.microsoft.com/mssql/server:2022-latest                  |   |
|   |   Edición: Developer (MSSQL_PID=Developer, ACCEPT_EULA=Y)             |   |
|   |   Puerto: 1433:1433 (Localhost)                                       |   |
|   |                                                                       |   |
|   |   +---------------------------------------------------------------+   |   |
|   |   |                         SQL Server Motor                      |   |   |
|   |   |   - Base de Datos: EmpresaDB                                  |   |   |
|   |   |   - Tablas: Ventas, AuditoriaVentas, Inventario               |   |   |
|   |   |   - Lógica: trg_AuditarVenta -> sp_RegistrarAuditoria (TVP)   |   |   |
|   |   +---------------------------------------------------------------+   |   |
|   +-----------------------------------------------------------------------+   |
|                                                                               |
|   Cliente CLI: /opt/mssql-tools18/bin/sqlcmd                                  |
|   - Ejecución DDL/DML secuencial                                              |
|   - Ejecución de aserciones de validación (verify.sql)                         |
|   - Extracción de datos formateados para CSV (report.sql)                     |
+-------------------------------------------------------------------------------+
                                      |
                                      v
+-------------------------------------------------------------------------------+
|                       GitHub Actions Artifact Storage                         |
|   Artifact: reporte-ventas-csv (reporte_ventas.csv, retención 30 días)        |
+-------------------------------------------------------------------------------+
```

### 2.1 Microsoft SQL Server 2022 (Developer Edition)
Motor de base de datos relacional empresarial de Microsoft. Para entornos de desarrollo y pruebas continuas, la edición **Developer** ofrece exactamente el mismo conjunto completo de funcionalidades que la edición Enterprise (incluyendo optimizador avanzado de consultas, particionamiento, soporte en memoria y cifrado), sin coste de licenciamiento para fines que no sean producción.

### 2.2 Docker y Contenedores
Docker permite encapsular el motor de base de datos junto con todas sus dependencias en un entorno reproducible y ligero. Cada ejecución de un workflow de CI levanta una instancia limpia y aislada desde la imagen oficial `mcr.microsoft.com/mssql/server:2022-latest`. Esto garantiza que no existan efectos secundarios o residuos de ejecuciones anteriores (*idempotencia y aislamiento*).

### 2.3 GitHub Actions (CI/CD)
Plataforma de automatización basada en eventos que provee máquinas virtuales administradas (*runners* con Ubuntu). Permite definir pipelines mediante archivos YAML en `.github/workflows/`, controlando el ciclo de vida del contenedor, ejecutando scripts en bash y evaluando el código de retorno (*exit code*) de cada paso.

### 2.4 GitHub Secrets y Seguridad
Las contraseñas maestras y cadenas de conexión nunca deben almacenarse en texto plano en el repositorio (*hardcoding*). Para la contraseña del usuario `sa`, se utiliza el secret de repositorio `MSSQL_SA_PASSWORD` (`Str0ngP@ssword2026!`). GitHub Actions enmascara este valor automáticamente en todos los registros de salida (`***`) y lo inyecta como variable de entorno solo durante el tiempo de ejecución del job.

### 2.5 sqlcmd v18
Herramienta de línea de comandos incluida en la imagen de SQL Server. En su versión 18 requiere explícitamente el parámetro `-C` (*Trust Server Certificate*) para conexiones locales no cifradas por certificados de CA pública, y `-b` (*On Error Batch Abort*) para que cualquier error SQL en las sentencias termine con un código de salida distinto de cero, fallando el pipeline de CI en caso de error.

### 2.6 GitHub Actions Artifacts (`actions/upload-artifact@v4`)
Servicio de almacenamiento de GitHub que preserva archivos generados durante la ejecución de los workflows (en este caso, `reporte_ventas.csv`) para que los usuarios puedan inspeccionarlos o descargarlos desde la interfaz gráfica web.

---

## 3. Modelo de Datos y Esquema Relacional

El modelo relacional implementado en `EmpresaDB` se compone de tres tablas interconectadas:

```
+-----------------------------------+           +-----------------------------------+
|              Ventas               |           |          AuditoriaVentas          |
+-----------------------------------+           +-----------------------------------+
| PK | VentaID       INT (IDENTITY) |<----+     | PK | AuditoriaID  INT (IDENTITY)  |
|    | Producto      VARCHAR(100)   |     +-----| FK | VentaID      INT             |
|    | Cantidad      INT (CHECK > 0)|           |    | FechaRegistro DATETIME       |
|    | Fecha         DATETIME       |           |    | Mensaje      VARCHAR(255)    |
+-----------------------------------+           +-----------------------------------+
                  | (Afecta)
                  v
+-----------------------------------+
|            Inventario             |
+-----------------------------------+
| PK | Producto      VARCHAR(100)   |
|    | Existencias   INT (CHECK >=0)|
+-----------------------------------+
```

### 3.1 Diccionario de Datos

| Tabla | Columna | Tipo de Dato | Restricción | Descripción |
|---|---|---|---|---|
| **Ventas** | `VentaID` | `INT` | `IDENTITY(1,1)`, `PRIMARY KEY` | Identificador único autoincremental de la venta. |
| | `Producto` | `VARCHAR(100)` | `NOT NULL` | Nombre descriptivo del producto comercializado. |
| | `Cantidad` | `INT` | `NOT NULL`, `CHECK (Cantidad > 0)` | Unidades vendidas (debe ser estrictamente positiva). |
| | `Fecha` | `DATETIME` | `NOT NULL`, `DEFAULT GETDATE()` | Marca de tiempo exacta del registro de la transacción. |
| **AuditoriaVentas** | `AuditoriaID` | `INT` | `IDENTITY(1,1)`, `PRIMARY KEY` | Identificador único autoincremental de auditoría. |
| | `VentaID` | `INT` | `NOT NULL`, `FOREIGN KEY` | Referencia foránea a la venta correspondiente. |
| | `FechaRegistro` | `DATETIME` | `NOT NULL`, `DEFAULT GETDATE()` | Fecha y hora en que se ejecutó la auditoría automática. |
| | `Mensaje` | `VARCHAR(255)` | `NOT NULL` | Registro informativo del evento de auditoría. |
| **Inventario** | `Producto` | `VARCHAR(100)` | `PRIMARY KEY` | Nombre único del producto en almacén. |
| | `Existencias` | `INT` | `NOT NULL`, `CHECK (Existencias >= 0)` | Stock actual disponible (no admite valores negativos). |

---

## 4. Reto Principal: Procesamiento por Conjuntos y Optimización del Trigger

### 4.1 Diagnóstico de la Falla en el Código Original

El planteamiento inicial proporcionaba el siguiente trigger:

```sql
CREATE TRIGGER trg_AuditarVenta
ON Ventas
AFTER INSERT
AS
BEGIN
    DECLARE @VentaID INT;
    SELECT @VentaID = VentaID FROM inserted;
    EXEC sp_RegistrarAuditoria @VentaID;
END;
```

#### ¿Por qué falla este código en producción?
1. **Naturaleza del Trigger en SQL Server:** En Microsoft SQL Server, los triggers `AFTER INSERT` **no son a nivel de fila** (*Row-Level Triggers* como en Oracle o PostgreSQL con `FOR EACH ROW`), sino **a nivel de sentencia** (*Statement-Level Triggers*). Esto significa que el trigger se dispara **exactamente una vez por cada instrucción `INSERT`**, sin importar si la instrucción insertó 1 fila, 10 filas o 100,000 filas.
2. **Pérdida Crítica de Datos (*Data Loss*):** Cuando se ejecuta una inserción múltiple como:
   ```sql
   INSERT INTO Ventas (Producto, Cantidad) VALUES ('Laptop', 2), ('Monitor', 1), ('Mouse', 4);
   ```
   La pseudotabla `inserted` contiene tres registros. Sin embargo, la instrucción:
   ```sql
   SELECT @VentaID = VentaID FROM inserted;
   ```
   asigna un valor escalar a la variable `@VentaID`. Dado que una variable escalar solo puede almacenar un único valor a la vez, SQL Server asigna arbitrariamente el `VentaID` de la última tupla procesada internamente. En consecuencia, `sp_RegistrarAuditoria` se invoca únicamente una vez con un solo ID; las otras dos ventas jamás se auditan, violando la trazabilidad y corrompiendo la auditoría de negocio.

---

### 4.2 Funcionamiento de la Pseudotabla Lógica `inserted`

En SQL Server, las tablas lógicas `inserted` y `deleted` son estructuras especiales administradas directamente por el motor relacional durante la ejecución de triggers DML:

1. **Ubicación y Estructura:** No son tablas físicas almacenadas en disco ni visibles en `sys.tables`. Residen en memoria en el búfer del motor y se respaldan en el registro de transacciones (*transaction log*) y `tempdb`.
2. **Estructura Espejo:** Tienen exactamente las mismas columnas y tipos de datos que la tabla sobre la cual está definido el trigger (`Ventas`).
3. **Comportamiento en Operaciones:**
   - En un `INSERT`, la tabla `inserted` contiene una copia de todas las nuevas filas agregadas por la sentencia, con sus valores de `IDENTITY` ya generados.
   - En un `DELETE`, la tabla `deleted` contiene las filas eliminadas antes de su supresión.
   - En un `UPDATE`, la tabla `deleted` contiene los valores previos a la modificación y la tabla `inserted` contiene los nuevos valores tras la modificación.
4. **Ámbito Temporal y Solo Lectura:** Son de solo lectura (`READ-ONLY`). No es posible realizar `INSERT`, `UPDATE` o `DELETE` sobre ellas. Su ciclo de vida está estrictamente limitado a la duración de la transacción y ejecución del trigger.

---

### 4.3 Procesamiento por Conjuntos (*Set-Based Processing*)

El modelo relacional, formulado por Edgar F. Codd en 1970, se fundamenta en la teoría matemática de conjuntos y la lógica de predicados de primer orden. En este paradigma, **un conjunto de datos se trata como una unidad completa indivisible**.

Cuando se escribe una consulta orientada a conjuntos (por ejemplo, `UPDATE ... FROM ... INNER JOIN` o `INSERT INTO ... SELECT ...`), el desarrollador declara **qué resultado desea obtener**, no **cómo recorrer los datos paso a paso**. El Optimizador de Consultas Basado en Costos (CBO) de SQL Server analiza estadísticas de índices, distribución de datos y hardware disponible para construir un Plan de Ejecución físico altamente optimizado, aplicando algoritmos de alto rendimiento como:
- *Hash Joins* y *Merge Joins*.
- Búsquedas y escaneos de índices agrupados en paralelo (*Clustered Index Seek/Scan*).
- Paralelismo intra-consulta mediante múltiples hilos de CPU (SIMD y vectorización).

---

### 4.4 Comparativa: Fila a Fila (*RBAR*) vs. Procesamiento por Conjunto (*Set-Based*)

El procesamiento fila a fila suele denominarse en la industria como **RBAR** (*Row By Agonizing Row*). Ocurre cuando se fuerza a la base de datos relacional a comportarse como un lenguaje de programación procedimental iterativo mediante el uso de cursores (`DECLARE CURSOR ... FETCH NEXT`) o bucles (`WHILE`).

| Criterio | Procesamiento Fila a Fila (RBAR / Cursores) | Procesamiento por Conjuntos (Set-Based) |
|---|---|---|
| **Paradigma** | Procedimental / Imperativo (¿Cómo iterar?) | Declarativo / Relacional (¿Qué resultado?) |
| **Complejidad Algorítmica** | Generalmente $O(N^2)$ o $O(N \cdot M)$ por búsquedas repetitivas individuales. | Típicamente $O(N)$ o $O(N \log N)$ gracias a algoritmos de ordenamiento y tablas hash. |
| **Cambios de Contexto** | Múltiples transiciones entre el motor de ejecución procedural y el motor relacional por cada fila. | Una única invocación y evaluación en el motor relacional. |
| **Manejo de Bloqueos (Locks)** | Adquiere y libera bloqueos fila por fila en bucle, aumentando exponencialmente la contención y el riesgo de interbloqueos (*deadlocks*). | Aplica bloqueos en lote bien definidos, minimizando el tiempo de retención y facilitando la concurrencia. |
| **Uso de Registro de Transacciones** | Genera múltiples entradas individuales de log por cada ciclo, incrementando la fragmentación y el I/O. | Escribe cambios de forma masiva en el log (*bulk logging* / agrupación atómica), reduciendo el I/O en disco. |
| **Aprovechamiento de CPU** | Monohilo y secuencial; no puede paralelizarse eficientemente. | Altamente paralelizable por el motor si el volumen de datos lo amerita. |
| **Escalabilidad** | El tiempo de respuesta se degrada drásticamente a medida que $N$ crece (ej. 100,000 filas tardan minutos). | Tiempo de respuesta lineal y estable; procesa 100,000 filas en fracciones de segundo. |

---

### 4.5 Solución Implementada: Table-Valued Parameters (TVP) y Operaciones Conjuntas

Para resolver la limitación sin recurrir a cursores ni bucles, se utilizó un **Parámetro con Valor de Tabla (Table-Valued Parameter - TVP)**:

1. **Definición del Tipo de Tabla:**
   ```sql
   CREATE TYPE dbo.TipoVentasInsertadas AS TABLE (
       VentaID INT NOT NULL PRIMARY KEY,
       Producto VARCHAR(100) NOT NULL,
       Cantidad INT NOT NULL
   );
   ```
2. **Trigger Optimizado:**
   ```sql
   CREATE TRIGGER dbo.trg_AuditarVenta
   ON dbo.Ventas
   AFTER INSERT
   AS
   BEGIN
       SET NOCOUNT ON;
       DECLARE @Ventas dbo.TipoVentasInsertadas;

       INSERT INTO @Ventas (VentaID, Producto, Cantidad)
       SELECT VentaID, Producto, Cantidad
       FROM inserted;

       EXEC dbo.sp_RegistrarAuditoria @Ventas = @Ventas;
   END;
   ```
3. **Auditoría Orientada a Conjuntos:**
   En `sp_RegistrarAuditoria`, la inserción en `AuditoriaVentas` se realiza para todas las filas en una única instrucción:
   ```sql
   INSERT INTO dbo.AuditoriaVentas (VentaID, Mensaje)
   SELECT VentaID, 'Venta registrada automáticamente'
   FROM @LoteVentas;
   ```
   Esto asegura que ya sea 1 o 10,000 ventas, todas quedan auditadas inmediatamente con coste mínimo de CPU.

---

## 5. Reto Avanzado: Gestión Automatizada y Consistente de Inventario

El reto avanzado exige que cada vez que se registre una venta, se actualicen automáticamente las existencias de la tabla `Inventario` desde el procedimiento almacenado.

### 5.1 Desafío de Consistencia en Lotes Masivos
Si una instrucción `INSERT` múltiple contiene varias filas con el **mismo producto** (por ejemplo: `Laptop: 2 unidades` y `Laptop: 3 unidades` en la misma transacción), un simple `UPDATE inv SET Existencias = Existencias - v.Cantidad FROM Inventario inv INNER JOIN inserted v ON ...` es ambiguo en SQL Server porque el estándar no garantiza qué fila del `JOIN` actualiza la tabla destino cuando existen duplicados en el origen.

### 5.2 Estrategia de Solución Implementada
Para garantizar la consistencia atómica y matemática:

1. **Agrupación Previa por Producto:**
   Consolidamos las cantidades totales vendidas por producto dentro del lote recibido mediante una tabla en memoria:
   ```sql
   DECLARE @TotalesAgrupados TABLE (
       Producto VARCHAR(100) NOT NULL PRIMARY KEY,
       CantidadTotal INT NOT NULL
   );

   INSERT INTO @TotalesAgrupados (Producto, CantidadTotal)
   SELECT Producto, SUM(Cantidad)
   FROM @LoteVentas
   GROUP BY Producto;
   ```

2. **Actualización Condicional por Conjunto:**
   Se descuenta el stock asegurando que las existencias actuales sean mayores o iguales a la demanda agregada:
   ```sql
   UPDATE inv
   SET inv.Existencias = inv.Existencias - t.CantidadTotal
   FROM dbo.Inventario AS inv
   INNER JOIN @TotalesAgrupados AS t ON t.Producto = inv.Producto
   WHERE inv.Existencias >= t.CantidadTotal;
   ```

3. **Validación de Integridad y Reversión:**
   Comparamos el número de filas efectivamente actualizadas (`@@ROWCOUNT`) con la cantidad de productos distintos esperados (`COUNT(*)`):
   ```sql
   DECLARE @ProductosActualizados INT = @@ROWCOUNT;
   IF @ProductosActualizados <> @TotalProductos
   BEGIN
       THROW 50001, 'Error: Producto no registrado en inventario o existencias insuficientes para completar la venta.', 1;
   END;
   ```
   Si algún producto no existe en el inventario o no cuenta con suficiente stock, se dispara la excepción con `THROW`. Como el trigger se ejecuta dentro de la transacción implícita del `INSERT`, la transacción completa se revierte (*ROLLBACK*), evitando inconsistencias y garantizando el cumplimiento de la restricción `CHECK (Existencias >= 0)`.

---

## 6. Pipeline de Integración Continua (CI/CD)

### 6.1 Workflow 01: `deploy.yml` (Despliegue y Pruebas Continuas)
Se ejecuta en cada `push` a la rama `main` y bajo demanda (`workflow_dispatch`).

```
[ Git Push / Dispatch ]
          │
          ▼
[ Checkout Código ] ──> actions/checkout@v4
          │
          ▼
[ Ejecutar setup_db.sh ]
    ├─ Inicia contenedor Docker con SQL Server 2022 Developer
    ├─ Bucle de sondeo de salud (healthcheck con sqlcmd SELECT 1;)
    └─ Ejecuta en orden:
         1. create_database.sql
         2. create_tables.sql
         3. create_procedure.sql
         4. create_trigger.sql
         5. test_data.sql
          │
          ▼
[ Ejecutar verify.sql ]
    ├─ Valida 5 ventas totales en Ventas
    ├─ Valida 5 registros totales en AuditoriaVentas
    ├─ Valida correspondencia 1:1 entre Ventas y AuditoriaVentas
    ├─ Valida existencias finales de Inventario (Laptop: 5, Monitor: 6, Mouse: 16)
    └─ Emite código de error 5100x en caso de fallo, abortando el pipeline
```

### 6.2 Workflow 02: `reporte.yml` (Reporte Programado y Artifacts)
Se ejecuta de forma recurrente mediante una expresión `cron` (`0 12 * * 1`, todos los lunes a las 12:00 UTC) y también manualmente vía `workflow_dispatch`.

1. Levanta el contenedor e inicializa los datos con `setup_db.sh`.
2. Ejecuta `sql/report.sql` formateando los campos con delimitadores y entrecomillado estándar RFC 4180.
3. Genera el archivo físico `reportes/reporte_ventas.csv`.
4. Valida que el archivo contenga la cabecera más las filas de datos.
5. Utiliza la acción oficial `actions/upload-artifact@v4` para almacenar el artefacto con el nombre `reporte-ventas-csv` y un periodo de retención de 30 días.

---

## 7. Verificación de Resultados y Datos de Prueba

### Estado Inicial del Inventario:
| Producto | Stock Inicial |
|---|---|
| Laptop | 10 |
| Monitor | 12 |
| Mouse | 20 |

### Ventas Ejecutadas (`test_data.sql`):
1. Venta Individual 1: `('Laptop', 3)`
2. Venta Individual 2: `('Monitor', 5)`
3. Inserción Múltiple (Lote): `('Laptop', 2), ('Monitor', 1), ('Mouse', 4)`

### Estado Final Verificado:
- **Total Ventas en `dbo.Ventas`:** 5 registros.
- **Total Auditorías en `dbo.AuditoriaVentas`:** 5 registros con mensaje `"Venta registrada automáticamente"`.
- **Relación de Auditoría:** Exactamente 1 auditoría por cada venta (cobertura 100%).
- **Existencias en `dbo.Inventario`:**
  - **Laptop:** $10 - 3 - 2 = \mathbf{5}$
  - **Monitor:** $12 - 5 - 1 = \mathbf{6}$
  - **Mouse:** $20 - 4 = \mathbf{16}$

Todas las aserciones de `verify.sql` finalizaron con éxito (`EXIT CODE 0`), demostrando la robustez matemática y técnica de la solución.
