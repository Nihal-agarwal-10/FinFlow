USE FinFlowDB;
GO

SELECT 'customers' AS TableName,
       COUNT(*) AS TotalRecords
FROM dbo.customers

UNION ALL

SELECT 'branches', COUNT(*)
FROM dbo.branches

UNION ALL

SELECT 'accounts', COUNT(*)
FROM dbo.accounts

UNION ALL

SELECT 'merchants', COUNT(*)
FROM dbo.merchants

UNION ALL

SELECT 'transactions', COUNT(*)
FROM dbo.transactions

UNION ALL

SELECT 'transaction_entries', COUNT(*)
FROM dbo.transaction_entries;