USE master;
GO

IF DB_ID('FinFlowDB') IS NULL
BEGIN
    CREATE DATABASE FinFlowDB;
    PRINT 'FinFlowDB created successfully.';
END
ELSE
    PRINT 'FinFlowDB already exists.';
GO