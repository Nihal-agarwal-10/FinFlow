
USE FinFlowDB;
GO

/* =========================================================
   FINFLOW - DATABASE INDEX MANAGEMENT
   =========================================================

   This script creates performance-oriented indexes.

   Primary key and unique constraint indexes are created
   automatically by database/02_create_tables.sql.

   All index creation statements are rerunnable.
   ========================================================= */


/* =========================================================
   1. TRANSACTION ENTRY COMPOSITE INDEX
   =========================================================

   Supports:
   - Account-based transaction history.
   - Account and transaction lookups.
   - Queries requiring ledger entry attributes.

   Key columns:
   account_id, transaction_id

   Included columns:
   entry_type, entry_amount
   ========================================================= */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_TransactionEntries_Account_Transaction'
      AND object_id = OBJECT_ID('dbo.transaction_entries')
)
BEGIN
    CREATE NONCLUSTERED INDEX
        IX_TransactionEntries_Account_Transaction

    ON dbo.transaction_entries
    (
        account_id,
        transaction_id
    )

    INCLUDE
    (
        entry_type,
        entry_amount
    );
END;
GO


/* =========================================================
   2. TRANSACTION TIMESTAMP INDEX
   =========================================================

   Supports:
   - Date-range transaction filtering.
   - Recent transaction history.
   - Timestamp-based analytical queries.

   Included columns reduce additional lookups for
   commonly retrieved transaction attributes.
   ========================================================= */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Transactions_OccurredAt'
      AND object_id = OBJECT_ID('dbo.transactions')
)
BEGIN
    CREATE NONCLUSTERED INDEX
        IX_Transactions_OccurredAt

    ON dbo.transactions
    (
        occurred_at DESC
    )

    INCLUDE
    (
        transaction_ref,
        transaction_type,
        transaction_amount,
        transaction_status
    );
END;
GO


/* =========================================================
   3. VERIFY PERFORMANCE INDEXES
   ========================================================= */

SELECT
    OBJECT_NAME(I.object_id) AS table_name,

    I.name AS index_name,

    I.type_desc AS index_type,

    I.is_unique,

    I.is_primary_key,

    I.is_disabled

FROM sys.indexes I

WHERE I.object_id IN
(
    OBJECT_ID('dbo.transaction_entries'),
    OBJECT_ID('dbo.transactions')
)

AND I.name IN
(
    'IX_TransactionEntries_Account_Transaction',
    'IX_Transactions_OccurredAt'
)

ORDER BY
    table_name,
    index_name;
GO


/* =========================================================
   4. VERIFY INDEX COLUMN CONFIGURATION
   ========================================================= */

SELECT
    OBJECT_NAME(I.object_id) AS table_name,

    I.name AS index_name,

    C.name AS column_name,

    IC.key_ordinal,

    IC.is_included_column,

    IC.is_descending_key

FROM sys.indexes I

INNER JOIN sys.index_columns IC
    ON I.object_id = IC.object_id
    AND I.index_id = IC.index_id

INNER JOIN sys.columns C
    ON IC.object_id = C.object_id
    AND IC.column_id = C.column_id

WHERE I.name IN
(
    'IX_TransactionEntries_Account_Transaction',
    'IX_Transactions_OccurredAt'
)

ORDER BY
    table_name,
    index_name,
    IC.key_ordinal,
    IC.index_column_id;
GO
