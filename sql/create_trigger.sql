USE EmpresaDB;
GO

-- Trigger para auditar ventas al insertar
CREATE OR ALTER TRIGGER dbo.trg_AuditarVenta
ON dbo.Ventas
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Ventas dbo.TipoVentasInsertadas;

    -- Pasamos las filas de inserted al procedimiento
    INSERT INTO @Ventas (VentaID, Producto, Cantidad)
    SELECT VentaID, Producto, Cantidad
    FROM inserted;

    EXEC dbo.sp_RegistrarAuditoria @Ventas = @Ventas;
END;
GO
