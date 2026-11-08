-- ============================================================================
-- Proyecto Integrador: GitHub Actions + Docker + Microsoft SQL Server
-- Archivo: sql/test_data.sql
-- Descripción: Inserción de datos iniciales en Inventario y pruebas de ventas.
-- Incluye ventas individuales y una inserción múltiple simultánea (Reto Principal).
-- ============================================================================

USE EmpresaDB;
GO

-- 1. Poblado inicial de Inventario (Reto Avanzado)
INSERT INTO dbo.Inventario (Producto, Existencias)
VALUES 
    ('Laptop', 10),
    ('Monitor', 12),
    ('Mouse', 20);
GO

-- 2. Ventas individuales solicitadas en la especificación
INSERT INTO dbo.Ventas (Producto, Cantidad) VALUES ('Laptop', 3);
INSERT INTO dbo.Ventas (Producto, Cantidad) VALUES ('Monitor', 5);
GO

-- 3. Reto Principal: Inserción múltiple en una única instrucción SQL
-- Valida que el trigger capture y audite todas las filas del conjunto
INSERT INTO dbo.Ventas (Producto, Cantidad)
VALUES 
    ('Laptop', 2),
    ('Monitor', 1),
    ('Mouse', 4);
GO
