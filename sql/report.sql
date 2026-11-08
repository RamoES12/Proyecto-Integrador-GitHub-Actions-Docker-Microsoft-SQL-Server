SET NOCOUNT ON;

-- Reporte de ventas en CSV
SELECT CONCAT('"', VentaID, '","',
              REPLACE(Producto, '"', '""'), '","',
              Cantidad, '","',
              CONVERT(VARCHAR(19), Fecha, 126), '"')
FROM dbo.Ventas
ORDER BY VentaID;
GO
