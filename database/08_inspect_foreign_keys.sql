USE FinFlowDB;
GO

SELECT
    OBJECT_NAME(fk.parent_object_id) AS ChildTable,
    COL_NAME(
        fkc.parent_object_id,
        fkc.parent_column_id
    ) AS ChildColumn,
    OBJECT_NAME(fk.referenced_object_id) AS ParentTable,
    COL_NAME(
        fkc.referenced_object_id,
        fkc.referenced_column_id
    ) AS ParentColumn,
    fk.name AS ForeignKeyName
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc
    ON fk.object_id = fkc.constraint_object_id
ORDER BY ChildTable;