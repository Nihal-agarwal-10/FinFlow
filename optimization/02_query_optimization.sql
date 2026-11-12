USE FinFlowDB;
GO

SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

-- Baseline: transaction history for one account
SELECT
    a.account_number,
    t.transaction_id,
    t.transaction_ref,
    t.transaction_type,
    t.transaction_amount,
    t.transaction_status,
    t.occurred_at
FROM dbo.transaction_entries te
JOIN dbo.accounts a
    ON te.account_id = a.account_id
JOIN dbo.transactions t
    ON te.transaction_id = t.transaction_id
WHERE a.account_number = 'ACC1001'
ORDER BY t.occurred_at DESC;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

USE FinFlowDB;
GO

-- Enable performance statistics
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

-- Baseline: non-SARGable date filtering
SELECT
    transaction_id,
    transaction_ref,
    transaction_type,
    transaction_amount,
    transaction_status,
    occurred_at
FROM dbo.transactions
WHERE CAST(occurred_at AS DATE) = '2026-11-02'
ORDER BY occurred_at DESC;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

-- Optimised date-range filtering
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

SELECT
    transaction_id,
    transaction_ref,
    transaction_type,
    transaction_amount,
    transaction_status,
    occurred_at
FROM dbo.transactions
WHERE occurred_at >= '2026-11-02'
  AND occurred_at < '2026-11-03'
ORDER BY occurred_at DESC;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

-- Composite covering index for date-based transaction searches
CREATE NONCLUSTERED INDEX IX_Transactions_OccurredAt
ON dbo.transactions (occurred_at DESC)
INCLUDE (
    transaction_ref,
    transaction_type,
    transaction_amount,
    transaction_status
);
GO

-- Index for account-based transaction history
CREATE NONCLUSTERED INDEX IX_TransactionEntries_Account_Transaction
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
GO

SELECT
    i.name AS index_name,
    i.type_desc,
    c.name AS column_name,
    ic.key_ordinal,
    ic.is_included_column
FROM sys.indexes i
JOIN sys.index_columns ic
    ON i.object_id = ic.object_id
    AND i.index_id = ic.index_id
JOIN sys.columns c
    ON ic.object_id = c.object_id
    AND ic.column_id = c.column_id
WHERE i.object_id = OBJECT_ID('dbo.transaction_entries')
ORDER BY i.name, ic.key_ordinal, ic.index_column_id;
GO


USE FinFlowDB;
GO

DROP INDEX IX_TransactionEntries_AccountID
ON dbo.transaction_entries;
GO

USE FinFlowDB;
GO

SELECT
    i.name AS index_name,
    i.type_desc,
    c.name AS column_name,
    ic.key_ordinal,
    ic.is_included_column
FROM sys.indexes i
JOIN sys.index_columns ic
    ON i.object_id = ic.object_id
    AND i.index_id = ic.index_id
JOIN sys.columns c
    ON ic.object_id = c.object_id
    AND ic.column_id = c.column_id
WHERE i.object_id = OBJECT_ID('dbo.transaction_entries')
  AND i.name = 'IX_TransactionEntries_Account_Transaction'
ORDER BY ic.key_ordinal, ic.index_column_id;
GO

USE FinFlowDB;
GO

SELECT
    i.name AS index_name,
    i.type_desc,
    c.name AS column_name,
    ic.key_ordinal,
    ic.is_included_column
FROM sys.indexes i
JOIN sys.index_columns ic
    ON i.object_id = ic.object_id
    AND i.index_id = ic.index_id
JOIN sys.columns c
    ON ic.object_id = c.object_id
    AND ic.column_id = c.column_id
WHERE i.object_id = OBJECT_ID('dbo.transaction_entries')
  AND i.name IS NOT NULL
ORDER BY i.name, ic.key_ordinal, ic.index_column_id;
GO

USE FinFlowDB;
GO

SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

SELECT
    a.account_number,
    t.transaction_id,
    t.transaction_ref,
    t.transaction_type,
    t.transaction_amount,
    t.transaction_status,
    t.occurred_at
FROM dbo.transaction_entries te
JOIN dbo.accounts a
    ON te.account_id = a.account_id
JOIN dbo.transactions t
    ON te.transaction_id = t.transaction_id
WHERE a.account_number = 'FF0000000001'
ORDER BY t.occurred_at DESC;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

USE FinFlowDB;
GO

SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

SELECT
    a.account_number,
    t.transaction_id,
    t.transaction_ref,
    t.transaction_type,
    t.transaction_amount,
    t.transaction_status,
    t.occurred_at
FROM dbo.transaction_entries te
JOIN dbo.accounts a
    ON te.account_id = a.account_id
JOIN dbo.transactions t
    ON te.transaction_id = t.transaction_id
WHERE a.account_number = 'FF0000000001'
ORDER BY t.occurred_at DESC;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO