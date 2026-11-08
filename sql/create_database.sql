IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'EmpresaDB')
BEGIN
    CREATE DATABASE EmpresaDB;
END;
GO
