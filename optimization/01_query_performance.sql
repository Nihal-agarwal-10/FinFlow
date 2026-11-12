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