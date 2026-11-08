USE EmpresaDB;
GO

-- Stock inicial
INSERT INTO dbo.Inventario (Producto, Existencias)
VALUES 
    ('Laptop', 10),
    ('Monitor', 12),
    ('Mouse', 20);
GO

-- Ventas individuales
INSERT INTO dbo.Ventas (Producto, Cantidad) VALUES ('Laptop', 3);
INSERT INTO dbo.Ventas (Producto, Cantidad) VALUES ('Monitor', 5);
GO

-- Venta de varios productos
INSERT INTO dbo.Ventas (Producto, Cantidad)
VALUES 
    ('Laptop', 2),
    ('Monitor', 1),
    ('Mouse', 4);
GO
