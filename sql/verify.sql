USE EmpresaDB;
GO
SET NOCOUNT ON;

-- Validamos cantidad de ventas
IF (SELECT COUNT(*) FROM dbo.Ventas) <> 5
    THROW 51001, 'Error: Se esperaban 5 ventas.', 1;

-- Validamos cantidad de auditorias
IF (SELECT COUNT(*) FROM dbo.AuditoriaVentas) <> 5
    THROW 51002, 'Error: Se esperaban 5 auditorias.', 1;

-- Validamos que cada venta tenga auditoria
IF EXISTS (
    SELECT v.VentaID
    FROM dbo.Ventas AS v
    LEFT JOIN dbo.AuditoriaVentas AS a ON a.VentaID = v.VentaID
    GROUP BY v.VentaID
    HAVING COUNT(a.AuditoriaID) <> 1
)
    THROW 51003, 'Error: Cada venta debe tener una auditoria.', 1;

-- Validamos existencias de inventario
IF EXISTS (
    SELECT 1 FROM dbo.Inventario
    WHERE (Producto = 'Laptop' AND Existencias <> 5)
       OR (Producto = 'Monitor' AND Existencias <> 6)
       OR (Producto = 'Mouse' AND Existencias <> 16)
)
    THROW 51004, 'Error: Las existencias no coinciden.', 1;

PRINT 'Pruebas correctas: 5 ventas, 5 auditorias e inventario actualizado.';

SELECT * FROM dbo.Ventas;
SELECT * FROM dbo.AuditoriaVentas;
SELECT * FROM dbo.Inventario;
GO
