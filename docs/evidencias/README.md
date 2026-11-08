# Guía de Capturas de Evidencia

Este documento detalla las capturas de pantalla requeridas para la entrega formal del Proyecto Integrador. Cada evidencia debe ser tomada directamente de la plataforma GitHub y de las ejecuciones reales de los workflows.

> [!IMPORTANT]
> Por políticas de seguridad de la información, nunca revele en las capturas el contenido en texto plano de la contraseña maestra del Secret.

---

## Índice de Evidencias Requeridas

| # | Evidencia | Sección / Ubicación en GitHub | Criterio de Aceptación |
|---|---|---|---|
| **1** | **Estructura del Repositorio** | Pestaña *Code* principal | Se visualizan las carpetas `.github/workflows`, `docs`, `scripts`, `sql` y el archivo `README.md`. |
| **2** | **Configuración del Secreto** | *Settings → Secrets and variables → Actions* | Se muestra el secret `MSSQL_SA_PASSWORD` configurado como *Repository secret*. |
| **3** | **Workflow 01 Exitoso** | Pestaña *Actions → 01 - Desplegar y probar SQL Server* | Ejecución completada en verde (`Status: Success`). |
| **4** | **Aserciones y Pruebas Unitarias** | Paso *Ejecutar pruebas de negocio y aserciones* | Logs mostrando `✓ TODAS LAS PRUEBAS PASARON EXITOSAMENTE`, 5 ventas, 5 auditorías y stock actualizado. |
| **5** | **Workflow 02 Exitoso** | Pestaña *Actions → 02 - Reporte programado de ventas CSV* | Ejecución completada en verde (`Status: Success`). |
| **6** | **Artefacto Publicado** | Resumen de la ejecución de Workflow 02 (*Artifacts*) | Se visualiza el artefacto descargable `reporte-ventas-csv` (formato `.zip` que contiene `reporte_ventas.csv`). |
| **7** | **Reporte CSV Descargado** | Archivo `reporte_ventas.csv` en visor de texto o Excel | Se comprueba la cabecera `"VentaID","Producto","Cantidad","Fecha"` y las 5 filas de ventas. |

---

## Detalle de Cada Captura

### Evidencia 1: Repositorio GitHub Completo
- **Cómo capturarla:** Navegue a la raíz del repositorio en GitHub (`https://github.com/RamoES12/Proyecto-Integrador-GitHub-Actions-Docker-Microsoft-SQL-Server`).
- **Qué debe verse:** El árbol de directorios con sus descripciones de commit y el renderizado del `README.md`.

### Evidencia 2: Secreto de Contraseña
- **Cómo capturarla:** Diríjase a *Settings* (del repositorio) > *Secrets and variables* > *Actions*.
- **Qué debe verse:** En la lista de *Repository secrets*, la entrada con nombre `MSSQL_SA_PASSWORD` y fecha de última actualización.

### Evidencia 3: Ejecución de Despliegue y Pruebas (CI)
- **Cómo capturarla:** Vaya a la pestaña *Actions*, seleccione *01 - Desplegar y probar SQL Server* y abra la última ejecución.
- **Qué debe verse:** El diagrama con el job *Despliegue en Docker y Validación de Reglas* con check verde.

### Evidencia 4: Logs del Paso de Verificación
- **Cómo capturarla:** En la ejecución anterior, despliegue el paso `Ejecutar pruebas de negocio y aserciones`.
- **Qué debe verse:**
  ```text
  ✓ TODAS LAS PRUEBAS PASARON EXITOSAMENTE:
    - 5 ventas registradas.
    - 5 auditorías generadas (soporte para inserción múltiple verificado).
    - Existencias de inventario descontadas y consistentes.
  ```
  Junto con las tablas de resultados de `Ventas`, `AuditoriaVentas` e `Inventario`.

### Evidencia 5 y 6: Workflow de Reporte y Descarga de Artefacto
- **Cómo capturarla:** Vaya a *Actions*, seleccione *02 - Reporte programado de ventas CSV*, haga clic en *Run workflow* (para dispararlo manualmente) y espere a que finalice. En la parte inferior de la página de resumen, localice la sección **Artifacts**.
- **Qué debe verse:** El artefacto denominado `reporte-ventas-csv`.

### Evidencia 7: Inspección del Archivo CSV
- **Cómo capturarla:** Descargue y descomprima el artefacto, abriendo `reporte_ventas.csv` en un editor como VS Code, Notepad o Excel.
- **Qué debe verse:**
  ```csv
  "VentaID","Producto","Cantidad","Fecha"
  "1","Laptop","3","..."
  "2","Monitor","5","..."
  "3","Laptop","2","..."
  "4","Monitor","1","..."
  "5","Mouse","4","..."
  ```
