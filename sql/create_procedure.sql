USE EmpresaDB;
GO

-- Tipo de tabla para recibir multiples ventas
IF TYPE_ID('dbo.TipoVentasInsertadas') IS NULL
BEGIN
    CREATE TYPE dbo.TipoVentasInsertadas AS TABLE (
        VentaID INT NOT NULL PRIMARY KEY,
        Producto VARCHAR(100) NOT NULL,
        Cantidad INT NOT NULL
    );
END;
GO

-- Procedimiento para registrar auditoria y actualizar inventario
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarAuditoria
    @Ventas dbo.TipoVentasInsertadas READONLY,
    @VentaID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LoteVentas TABLE (
        VentaID INT NOT NULL PRIMARY KEY,
        Producto VARCHAR(100) NOT NULL,
        Cantidad INT NOT NULL
    );

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

    IF NOT EXISTS (SELECT 1 FROM @LoteVentas)
        RETURN;

    -- Agrupamos por producto para sumar cantidades
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

    -- Actualizamos existencias en inventario
    UPDATE inv
    SET inv.Existencias = inv.Existencias - t.CantidadTotal
    FROM dbo.Inventario AS inv
    INNER JOIN @TotalesAgrupados AS t ON t.Producto = inv.Producto
    WHERE inv.Existencias >= t.CantidadTotal;

    DECLARE @ProductosActualizados INT = @@ROWCOUNT;
    IF @ProductosActualizados <> @TotalProductos
    BEGIN
        THROW 50001, 'Producto no registrado en inventario o existencias insuficientes.', 1;
    END;

    -- Registramos la auditoria de cada venta
    INSERT INTO dbo.AuditoriaVentas (VentaID, Mensaje)
    SELECT VentaID, 'Venta registrada automáticamente'
    FROM @LoteVentas;
END;
GO
