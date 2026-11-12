
USE FinFlowDB;
GO

SET NOCOUNT ON;

-- 1. Check duplicate customer IDs
SELECT customer_id, COUNT(*) AS duplicate_count
FROM clean.Customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- 2. Check duplicate account numbers
SELECT account_number, COUNT(*) AS duplicate_count
FROM clean.Accounts
GROUP BY account_number
HAVING COUNT(*) > 1;

-- 3. Check accounts referencing missing customers
SELECT a.account_id, a.customer_id
FROM clean.Accounts a
LEFT JOIN clean.Customers c
    ON a.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- 4. Check accounts referencing missing branches
SELECT a.account_id, a.branch_id
FROM clean.Accounts a
LEFT JOIN clean.Branches b
    ON a.branch_id = b.branch_id
WHERE b.branch_id IS NULL;

-- 5. Check transactions referencing missing merchants
-- NULL merchant_id is permitted.
SELECT t.transaction_id, t.merchant_id
FROM clean.Transactions t
LEFT JOIN clean.Merchants m
    ON t.merchant_id = m.merchant_id
WHERE t.merchant_id IS NOT NULL
  AND m.merchant_id IS NULL;

-- 6. Check ledger entries referencing missing transactions
SELECT e.entry_id, e.transaction_id
FROM clean.TransactionEntries e
LEFT JOIN clean.Transactions t
    ON e.transaction_id = t.transaction_id
WHERE t.transaction_id IS NULL;

-- 7. Check ledger entries referencing missing accounts
SELECT e.entry_id, e.account_id
FROM clean.TransactionEntries e
LEFT JOIN clean.Accounts a
    ON e.account_id = a.account_id
WHERE a.account_id IS NULL;

-- 8. Check debit-credit balance per transaction
SELECT
    transaction_id,
    SUM(CASE WHEN entry_type = 'DEBIT'
             THEN entry_amount ELSE 0 END) AS total_debit,
    SUM(CASE WHEN entry_type = 'CREDIT'
             THEN entry_amount ELSE 0 END) AS total_credit
FROM clean.TransactionEntries
GROUP BY transaction_id
HAVING
    SUM(CASE WHEN entry_type = 'DEBIT'
             THEN entry_amount ELSE 0 END)
    <>
    SUM(CASE WHEN entry_type = 'CREDIT'
             THEN entry_amount ELSE 0 END);

-- 9. Final clean-layer record counts
SELECT 'Branches' AS Entity, COUNT(*) AS Total
FROM clean.Branches
UNION ALL
SELECT 'Customers', COUNT(*) FROM clean.Customers
UNION ALL
SELECT 'Merchants', COUNT(*) FROM clean.Merchants
UNION ALL
SELECT 'Accounts', COUNT(*) FROM clean.Accounts
UNION ALL
SELECT 'Transactions', COUNT(*) FROM clean.Transactions
UNION ALL
SELECT 'Transaction Entries', COUNT(*)
FROM clean.TransactionEntries;
GO
