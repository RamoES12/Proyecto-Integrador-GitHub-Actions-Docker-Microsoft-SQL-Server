-- ============================================================================
-- Proyecto Integrador: GitHub Actions + Docker + Microsoft SQL Server
-- Archivo: sql/create_trigger.sql
-- Descripción: Trigger trg_AuditarVenta sobre la tabla Ventas (AFTER INSERT).
-- Resuelve el Reto Principal al capturar la totalidad de filas de la pseudotabla
-- lógica 'inserted' y procesarlas en lote mediante el tipo de tabla TVP.
-- ============================================================================

USE EmpresaDB;
GO

CREATE OR ALTER TRIGGER dbo.trg_AuditarVenta
ON dbo.Ventas
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- En SQL Server, un trigger AFTER INSERT se dispara una única vez por sentencia.
    -- La pseudotabla 'inserted' contiene todas las filas afectadas por el INSERT
    -- (ya sea una sola fila o un lote masivo).
    DECLARE @Ventas dbo.TipoVentasInsertadas;

    -- Volcamos el conjunto completo de 'inserted' hacia el TVP
    INSERT INTO @Ventas (VentaID, Producto, Cantidad)
    SELECT VentaID, Producto, Cantidad
    FROM inserted;

    -- Invocamos el procedimiento almacenado enviando el conjunto completo
    EXEC dbo.sp_RegistrarAuditoria @Ventas = @Ventas;
END;
GO
