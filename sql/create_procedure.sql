
USE EmpresaDB;
GO

-- 1. Tipo de dato definido por el usuario para pasar lotes de ventas como parámetro
IF TYPE_ID('dbo.TipoVentasInsertadas') IS NULL
BEGIN
    CREATE TYPE dbo.TipoVentasInsertadas AS TABLE (
        VentaID INT NOT NULL PRIMARY KEY,
        Producto VARCHAR(100) NOT NULL,
        Cantidad INT NOT NULL
    );
END;
GO

-- 2. Procedimiento Almacenado sp_RegistrarAuditoria
-- Recibe un lote de ventas mediante Table-Valued Parameter (TVP) o un ID individual
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarAuditoria
    @Ventas dbo.TipoVentasInsertadas READONLY,
    @VentaID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Tabla temporal en memoria para unificar los datos recibidos
    DECLARE @LoteVentas TABLE (
        VentaID INT NOT NULL PRIMARY KEY,
        Producto VARCHAR(100) NOT NULL,
        Cantidad INT NOT NULL
    );

    -- Poblar según el modo de invocación (TVP o parámetro individual)
    IF EXISTS (SELECT 1 FROM @Ventas)
    BEGIN
        INSERT INTO @LoteVentas (VentaID, Producto, Cantidad)
        SELECT VentaID, Producto, Cantidad FROM @Ventas;
    END
    ELSE IF @VentaID IS NOT NULL
    BEGIN
        INSERT INTO @LoteVentas (VentaID, Producto, Cantidad)
        SELECT VentaID, Producto, Cantidad
        FROM dbo.Ventas
        WHERE VentaID = @VentaID;
    END;

    -- Si no hay registros, salir inmediatamente
    IF NOT EXISTS (SELECT 1 FROM @LoteVentas)
        RETURN;

    -- ------------------------------------------------------------------------
    -- Reto Avanzado: Actualización de existencias en Inventario (Set-Based)
    -- Agrupamos por producto para sumar cantidades si el mismo producto
    -- fue vendido múltiples veces en el mismo lote.
    -- ------------------------------------------------------------------------
    DECLARE @TotalesAgrupados TABLE (
        Producto VARCHAR(100) NOT NULL PRIMARY KEY,
        CantidadTotal INT NOT NULL
    );

    INSERT INTO @TotalesAgrupados (Producto, CantidadTotal)
    SELECT Producto, SUM(Cantidad)
    FROM @LoteVentas
    GROUP BY Producto;

    DECLARE @TotalProductos INT;
    SELECT @TotalProductos = COUNT(*) FROM @TotalesAgrupados;

    -- Descuento atómico por conjunto sobre la tabla Inventario
    UPDATE inv
    SET inv.Existencias = inv.Existencias - t.CantidadTotal
    FROM dbo.Inventario AS inv
    INNER JOIN @TotalesAgrupados AS t ON t.Producto = inv.Producto
    WHERE inv.Existencias >= t.CantidadTotal;

    -- Validar que todos los productos existían y tenían stock suficiente
    DECLARE @ProductosActualizados INT = @@ROWCOUNT;
    IF @ProductosActualizados <> @TotalProductos
    BEGIN
        THROW 50001, 'Error: Producto no registrado en inventario o existencias insuficientes para completar la venta.', 1;
    END;

    -- ------------------------------------------------------------------------
    -- Reto Principal: Registro de auditoría para todas las ventas insertadas
    -- Operación orientada a conjuntos (Set-Based) sin uso de cursores.
    -- ------------------------------------------------------------------------
    INSERT INTO dbo.AuditoriaVentas (VentaID, Mensaje)
    SELECT VentaID, 'Venta registrada automáticamente'
    FROM @LoteVentas;
END;
GO
