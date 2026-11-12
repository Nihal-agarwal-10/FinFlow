
USE FinFlowDB;
GO

/* Inspect all clean-layer table structures */

SELECT
    TABLE_NAME,
    ORDINAL_POSITION,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    NUMERIC_PRECISION,
    NUMERIC_SCALE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'clean'
ORDER BY
    TABLE_NAME,
    ORDINAL_POSITION;
GO


/* Inspect clean-layer record counts */

SELECT 'Branches' AS table_name,
       COUNT_BIG(*) AS record_count
FROM clean.Branches

UNION ALL

SELECT 'Customers', COUNT_BIG(*)
FROM clean.Customers

UNION ALL

SELECT 'Merchants', COUNT_BIG(*)
FROM clean.Merchants

UNION ALL

SELECT 'Accounts', COUNT_BIG(*)
FROM clean.Accounts

UNION ALL

SELECT 'Transactions', COUNT_BIG(*)
FROM clean.Transactions

UNION ALL

SELECT 'TransactionEntries', COUNT_BIG(*)
FROM clean.TransactionEntries;
GO
