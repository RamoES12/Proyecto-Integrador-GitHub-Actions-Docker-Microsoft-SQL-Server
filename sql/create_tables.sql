USE EmpresaDB;
GO

-- Tabla de ventas
IF OBJECT_ID('dbo.Ventas', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Ventas (
        VentaID INT IDENTITY(1,1) PRIMARY KEY,
        Producto VARCHAR(100) NOT NULL,
        Cantidad INT NOT NULL CHECK (Cantidad > 0),
        Fecha DATETIME NOT NULL DEFAULT GETDATE()
    );
END;
GO

-- Tabla de auditoria
IF OBJECT_ID('dbo.AuditoriaVentas', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AuditoriaVentas (
        AuditoriaID INT IDENTITY(1,1) PRIMARY KEY,
        VentaID INT NOT NULL,
        FechaRegistro DATETIME NOT NULL DEFAULT GETDATE(),
        Mensaje VARCHAR(255) NOT NULL,
        CONSTRAINT FK_AuditoriaVentas_Ventas 
            FOREIGN KEY (VentaID) REFERENCES dbo.Ventas(VentaID)
    );
END;
GO

-- Tabla de inventario
IF OBJECT_ID('dbo.Inventario', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Inventario (
        Producto VARCHAR(100) NOT NULL PRIMARY KEY,
        Existencias INT NOT NULL CHECK (Existencias >= 0)
    );
END;
GO
