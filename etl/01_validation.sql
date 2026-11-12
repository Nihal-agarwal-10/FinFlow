
USE FinFlowDB;
GO

-- 1. Check duplicate transaction references
SELECT
    transaction_ref,
    COUNT(*) AS duplicate_count
FROM dbo.transactions
GROUP BY transaction_ref
HAVING COUNT(*) > 1;


-- 2. Check accounts with missing customers or branches
SELECT a.account_id
FROM dbo.accounts a
LEFT JOIN dbo.customers c
    ON a.customer_id = c.customer_id
LEFT JOIN dbo.branches b
    ON a.branch_id = b.branch_id
WHERE c.customer_id IS NULL
   OR b.branch_id IS NULL;


-- 3. Check transactions with missing merchants
-- NULL merchant_id is allowed in this project.
SELECT t.transaction_id
FROM dbo.transactions t
LEFT JOIN dbo.merchants m
    ON t.merchant_id = m.merchant_id
WHERE t.merchant_id IS NOT NULL
  AND m.merchant_id IS NULL;


-- 4. Check transactions without exactly two ledger entries
SELECT
    t.transaction_id,
    COUNT(te.entry_id) AS entry_count
FROM dbo.transactions t
LEFT JOIN dbo.transaction_entries te
    ON t.transaction_id = te.transaction_id
GROUP BY t.transaction_id
HAVING COUNT(te.entry_id) <> 2;


-- 5. Check debit-credit mismatches
SELECT
    transaction_id,
    SUM(CASE WHEN entry_type = 'DEBIT'
             THEN entry_amount ELSE 0 END) AS total_debit,
    SUM(CASE WHEN entry_type = 'CREDIT'
             THEN entry_amount ELSE 0 END) AS total_credit
FROM dbo.transaction_entries
GROUP BY transaction_id
HAVING
    SUM(CASE WHEN entry_type = 'DEBIT'
             THEN entry_amount ELSE 0 END)
    <>
    SUM(CASE WHEN entry_type = 'CREDIT'
             THEN entry_amount ELSE 0 END);


-- 6. Check whether ledger amounts match transaction amounts
SELECT
    t.transaction_id,
    t.transaction_amount,
    SUM(te.entry_amount) / 2 AS ledger_amount
FROM dbo.transactions t
JOIN dbo.transaction_entries te
    ON t.transaction_id = te.transaction_id
GROUP BY
    t.transaction_id,
    t.transaction_amount
HAVING
    SUM(te.entry_amount) / 2 <> t.transaction_amount;


-- 7. Check invalid account balances
SELECT
    account_id,
    current_balance
FROM dbo.accounts
WHERE current_balance < 0;


-- 8. Overall validation summary
SELECT
    (SELECT COUNT(*) FROM dbo.transactions) AS total_transactions,

    (SELECT COUNT(*)
     FROM dbo.transaction_entries) AS total_entries,

    (SELECT COUNT(*)
     FROM dbo.transactions t
     WHERE (
         SELECT COUNT(*)
         FROM dbo.transaction_entries te
         WHERE te.transaction_id = t.transaction_id
     ) = 2) AS transactions_with_two_entries,

    (SELECT COUNT(*)
     FROM dbo.accounts
     WHERE current_balance < 0) AS negative_balance_accounts;
GO
