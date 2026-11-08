-- ============================================================================
-- Proyecto Integrador: GitHub Actions + Docker + Microsoft SQL Server
-- Archivo: sql/report.sql
-- Descripción: Consulta para exportar el reporte de Ventas en formato CSV estándar.
-- Nota: La conexión ya se realiza directamente a EmpresaDB con el flag -d EmpresaDB.
-- ============================================================================

SET NOCOUNT ON;

SELECT CONCAT('"', VentaID, '","',
              REPLACE(Producto, '"', '""'), '","',
              Cantidad, '","',
              CONVERT(VARCHAR(19), Fecha, 126), '"')
FROM dbo.Ventas
ORDER BY VentaID;
GO
