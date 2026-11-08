-- ============================================================================
-- Proyecto Integrador: GitHub Actions + Docker + Microsoft SQL Server
-- Archivo: sql/verify.sql
-- Descripción: Aserciones automáticas para validar la integridad de Ventas,
-- AuditoriaVentas y existencias de Inventario. Utilizado en CI (deploy.yml).
-- ============================================================================

USE EmpresaDB;
GO
SET NOCOUNT ON;

PRINT '=======================================================';
PRINT '   INICIANDO VERIFICACIÓN DE REGLAS DE NEGOCIO EN CI   ';
PRINT '=======================================================';

-- 1. Validar cantidad total de ventas registradas
DECLARE @TotalVentas INT;
SELECT @TotalVentas = COUNT(*) FROM dbo.Ventas;
IF @TotalVentas <> 5
BEGIN
    THROW 51001, 'ERROR DE VALIDACIÓN: Se esperaban exactamente 5 ventas registradas.', 1;
END;

-- 2. Validar cantidad total de registros de auditoría
DECLARE @TotalAuditorias INT;
SELECT @TotalAuditorias = COUNT(*) FROM dbo.AuditoriaVentas;
IF @TotalAuditorias <> 5
BEGIN
    THROW 51002, 'ERROR DE VALIDACIÓN: Se esperaban exactamente 5 registros en AuditoriaVentas.', 1;
END;

-- 3. Validar correspondencia 1:1 entre Ventas y AuditoriaVentas
IF EXISTS (
    SELECT v.VentaID
    FROM dbo.Ventas AS v
    LEFT JOIN dbo.AuditoriaVentas AS a ON a.VentaID = v.VentaID
    GROUP BY v.VentaID
    HAVING COUNT(a.AuditoriaID) <> 1
)
BEGIN
    THROW 51003, 'ERROR DE VALIDACIÓN: Cada venta debe tener exactamente un registro de auditoría.', 1;
END;

-- 4. Validar actualización de existencias en Inventario (Reto Avanzado)
-- Laptop: 10 inicial - (3 + 2) vendidas = 5 restante
-- Monitor: 12 inicial - (5 + 1) vendidas = 6 restante
-- Mouse: 20 inicial - 4 vendidas = 16 restante
IF EXISTS (
    SELECT 1 FROM dbo.Inventario
    WHERE (Producto = 'Laptop' AND Existencias <> 5)
       OR (Producto = 'Monitor' AND Existencias <> 6)
       OR (Producto = 'Mouse' AND Existencias <> 16)
)
BEGIN
    THROW 51004, 'ERROR DE VALIDACIÓN: Las existencias de Inventario no se descontaron correctamente.', 1;
END;

IF (SELECT COUNT(*) FROM dbo.Inventario) <> 3
BEGIN
    THROW 51005, 'ERROR DE VALIDACIÓN: Se esperaban exactamente 3 productos en Inventario.', 1;
END;

PRINT '✓ TODAS LAS PRUEBAS PASARON EXITOSAMENTE:';
PRINT '  - 5 ventas registradas.';
PRINT '  - 5 auditorías generadas (soporte para inserción múltiple verificado).';
PRINT '  - Existencias de inventario descontadas y consistentes.';
PRINT '=======================================================';

-- Mostrar resultados para evidencia en logs del Workflow
PRINT '';
PRINT '--- TABLA: VENTAS ---';
SELECT VentaID, Producto, Cantidad, CONVERT(VARCHAR(19), Fecha, 120) AS Fecha 
FROM dbo.Ventas 
ORDER BY VentaID;

PRINT '';
PRINT '--- TABLA: AUDITORIA VENTAS ---';
SELECT AuditoriaID, VentaID, CONVERT(VARCHAR(19), FechaRegistro, 120) AS FechaRegistro, Mensaje 
FROM dbo.AuditoriaVentas 
ORDER BY AuditoriaID;

PRINT '';
PRINT '--- TABLA: INVENTARIO (RETO AVANZADO) ---';
SELECT Producto, Existencias 
FROM dbo.Inventario 
ORDER BY Producto;
GO
