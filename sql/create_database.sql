-- ============================================================================
-- Proyecto Integrador: GitHub Actions + Docker + Microsoft SQL Server
-- Archivo: sql/create_database.sql
-- Descripción: Creación de la base de datos EmpresaDB.
-- ============================================================================

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'EmpresaDB')
BEGIN
    CREATE DATABASE EmpresaDB;
END;
GO
