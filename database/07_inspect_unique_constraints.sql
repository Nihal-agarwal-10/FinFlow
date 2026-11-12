USE FinFlowDB;
GO

SELECT
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    COL_NAME(ic.object_id, ic.column_id) AS ColumnName
FROM sys.indexes i
JOIN sys.index_columns ic
    ON i.object_id = ic.object_id
    AND i.index_id = ic.index_id
WHERE i.is_unique = 1
  AND i.is_primary_key = 0
  AND i.is_unique_constraint = 1
ORDER BY TableName, IndexName;