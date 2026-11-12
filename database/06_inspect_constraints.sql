USE FinFlowDB;
GO

-- 1. Check constraints
SELECT
    OBJECT_NAME(parent_object_id) AS TableName,
    name AS ConstraintName,
    definition AS CheckDefinition
FROM sys.check_constraints
ORDER BY TableName;

-- 2. Default constraints
SELECT
    OBJECT_NAME(parent_object_id) AS TableName,
    COL_NAME(parent_object_id, parent_column_id) AS ColumnName,
    definition AS DefaultValue
FROM sys.default_constraints
ORDER BY TableName;