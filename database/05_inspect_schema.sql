USE FinFlowDB;
GO

SELECT
    TABLE_NAME,
    COLUMN_NAME,
    COLUMNPROPERTY(
        OBJECT_ID(TABLE_SCHEMA + '.' + TABLE_NAME),
        COLUMN_NAME,
        'IsIdentity'
    ) AS IsIdentity
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN (
    'customers',
    'branches',
    'accounts',
    'merchants',
    'transactions',
    'transaction_entries'
)
AND COLUMN_NAME LIKE '%_id'
ORDER BY TABLE_NAME;