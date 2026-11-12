
USE FinFlowDB;
GO

/* =========================================================
   1. INSPECT WAREHOUSE TABLE STRUCTURES
   ========================================================= */

SELECT
    TABLE_NAME,
    ORDINAL_POSITION,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'warehouse'
ORDER BY
    TABLE_NAME,
    ORDINAL_POSITION;
GO


/* =========================================================
   2. WAREHOUSE RECORD COUNTS
   ========================================================= */

SELECT 'DimDate' AS table_name, COUNT_BIG(*) AS records
FROM warehouse.DimDate

UNION ALL
SELECT 'DimCustomer', COUNT_BIG(*)
FROM warehouse.DimCustomer

UNION ALL
SELECT 'DimBranch', COUNT_BIG(*)
FROM warehouse.DimBranch

UNION ALL
SELECT 'DimMerchant', COUNT_BIG(*)
FROM warehouse.DimMerchant

UNION ALL
SELECT 'DimAccount', COUNT_BIG(*)
FROM warehouse.DimAccount

UNION ALL
SELECT 'DimTransactionType', COUNT_BIG(*)
FROM warehouse.DimTransactionType

UNION ALL
SELECT 'DimTransactionStatus', COUNT_BIG(*)
FROM warehouse.DimTransactionStatus

UNION ALL
SELECT 'DimChannel', COUNT_BIG(*)
FROM warehouse.DimChannel

UNION ALL
SELECT 'FactTransactions', COUNT_BIG(*)
FROM warehouse.FactTransactions

UNION ALL
SELECT 'FactLedgerEntries', COUNT_BIG(*)
FROM warehouse.FactLedgerEntries;
GO


/* =========================================================
   3. INSPECT CUSTOMER SCD TYPE 2 HISTORY
   ========================================================= */

SELECT
    customer_id,
    customer_key,
    version_number,
    is_current,
    email,
    effective_from,
    effective_to
FROM warehouse.DimCustomer
ORDER BY customer_id, version_number;
GO


/* =========================================================
   4. INSPECT BRANCH DIMENSION
   ========================================================= */

SELECT *
FROM warehouse.DimBranch
ORDER BY branch_id;
GO


/* =========================================================
   5. VERIFY WAREHOUSE PROCEDURES
   ========================================================= */

SELECT
    SCHEMA_NAME(schema_id) AS schema_name,
    name AS procedure_name
FROM sys.procedures
WHERE schema_id = SCHEMA_ID('warehouse');
GO


USE FinFlowDB;
GO

/* Inspect fact table columns */

SELECT
    TABLE_NAME,
    ORDINAL_POSITION,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'warehouse'
  AND TABLE_NAME IN
  (
      'FactTransactions',
      'FactLedgerEntries'
  )
ORDER BY
    TABLE_NAME,
    ORDINAL_POSITION;
GO

/* Inspect relevant dimension columns */

SELECT
    TABLE_NAME,
    ORDINAL_POSITION,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'warehouse'
  AND TABLE_NAME IN
  (
      'DimCustomer',
      'DimBranch',
      'DimMerchant',
      'DimAccount',
      'DimTransactionType',
      'DimTransactionStatus',
      'DimChannel'
  )
ORDER BY
    TABLE_NAME,
    ORDINAL_POSITION;
GO

USE FinFlowDB;
GO


SELECT
    TABLE_NAME,
    STRING_AGG(
        CAST(
            CONCAT(
                COLUMN_NAME,
                ' (',
                DATA_TYPE,
                ', ',
                IS_NULLABLE,
                ')'
            ) AS NVARCHAR(MAX)
        ),
        ' | '
    ) WITHIN GROUP (
        ORDER BY ORDINAL_POSITION
    ) AS column_definitions
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'warehouse'
  AND TABLE_NAME IN
  (
      'DimDate',
      'DimCustomer',
      'DimBranch',
      'DimMerchant',
      'DimAccount',
      'DimTransactionType',
      'DimTransactionStatus',
      'DimChannel',
      'FactTransactions',
      'FactLedgerEntries'
  )
GROUP BY TABLE_NAME
ORDER BY TABLE_NAME;
GO

USE FinFlowDB;
GO

-- FactTransactions structure
SELECT
    ORDINAL_POSITION,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'warehouse'
  AND TABLE_NAME = 'FactTransactions'
ORDER BY ORDINAL_POSITION;
GO

-- FactLedgerEntries structure
SELECT
    ORDINAL_POSITION,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'warehouse'
  AND TABLE_NAME = 'FactLedgerEntries'
ORDER BY ORDINAL_POSITION;
GO

-- Dimension business keys and attributes
SELECT
    TABLE_NAME,
    ORDINAL_POSITION,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'warehouse'
  AND TABLE_NAME IN
  (
      'DimCustomer',
      'DimBranch',
      'DimMerchant',
      'DimAccount',
      'DimTransactionType',
      'DimTransactionStatus',
      'DimChannel',
      'DimDate'
  )
ORDER BY TABLE_NAME, ORDINAL_POSITION;
GO