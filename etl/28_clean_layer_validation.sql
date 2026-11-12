
USE FinFlowDB;
GO

/* =========================================================
   1. SOURCE vs STAGING vs CLEAN RECONCILIATION
   ========================================================= */

WITH LayerCounts AS
(
    SELECT
        'Branches' AS table_name,
        (SELECT COUNT_BIG(*) FROM dbo.branches) AS source_count,
        (SELECT COUNT_BIG(*) FROM stg.Branches) AS staging_count,
        (SELECT COUNT_BIG(*) FROM clean.Branches) AS clean_count

    UNION ALL

    SELECT
        'Customers',
        (SELECT COUNT_BIG(*) FROM dbo.customers),
        (SELECT COUNT_BIG(*) FROM stg.Customers),
        (SELECT COUNT_BIG(*) FROM clean.Customers)

    UNION ALL

    SELECT
        'Merchants',
        (SELECT COUNT_BIG(*) FROM dbo.merchants),
        (SELECT COUNT_BIG(*) FROM stg.Merchants),
        (SELECT COUNT_BIG(*) FROM clean.Merchants)

    UNION ALL

    SELECT
        'Accounts',
        (SELECT COUNT_BIG(*) FROM dbo.accounts),
        (SELECT COUNT_BIG(*) FROM stg.Accounts),
        (SELECT COUNT_BIG(*) FROM clean.Accounts)

    UNION ALL

    SELECT
        'Transactions',
        (SELECT COUNT_BIG(*) FROM dbo.transactions),
        (SELECT COUNT_BIG(*) FROM stg.Transactions),
        (SELECT COUNT_BIG(*) FROM clean.Transactions)

    UNION ALL

    SELECT
        'Transaction Entries',
        (SELECT COUNT_BIG(*) FROM dbo.transaction_entries),
        (SELECT COUNT_BIG(*) FROM stg.TransactionEntries),
        (SELECT COUNT_BIG(*) FROM clean.TransactionEntries)
)

SELECT
    table_name,
    source_count,
    staging_count,
    clean_count,

    CASE
        WHEN source_count = staging_count
         AND staging_count = clean_count
        THEN 'PASS'
        ELSE 'CHECK'
    END AS reconciliation_status

FROM LayerCounts
ORDER BY table_name;
GO


/* =========================================================
   2. REFERENTIAL INTEGRITY VALIDATION
   ========================================================= */

SELECT
    'Accounts without valid customers' AS validation_check,
    COUNT(*) AS failed_records
FROM clean.Accounts A
LEFT JOIN clean.Customers C
    ON A.customer_id = C.customer_id
WHERE C.customer_id IS NULL

UNION ALL

SELECT
    'Accounts without valid branches',
    COUNT(*)
FROM clean.Accounts A
LEFT JOIN clean.Branches B
    ON A.branch_id = B.branch_id
WHERE B.branch_id IS NULL

UNION ALL

SELECT
    'Transactions without valid merchants',
    COUNT(*)
FROM clean.Transactions T
LEFT JOIN clean.Merchants M
    ON T.merchant_id = M.merchant_id
WHERE T.merchant_id IS NOT NULL
  AND M.merchant_id IS NULL

UNION ALL

SELECT
    'Entries without valid transactions',
    COUNT(*)
FROM clean.TransactionEntries E
LEFT JOIN clean.Transactions T
    ON E.transaction_id = T.transaction_id
WHERE T.transaction_id IS NULL

UNION ALL

SELECT
    'Entries without valid accounts',
    COUNT(*)
FROM clean.TransactionEntries E
LEFT JOIN clean.Accounts A
    ON E.account_id = A.account_id
WHERE A.account_id IS NULL;
GO


/* =========================================================
   3. FINANCIAL LEDGER INTEGRITY
   ========================================================= */

WITH LedgerSummary AS
(
    SELECT
        transaction_id,

        COUNT(*) AS entry_count,

        SUM(CASE WHEN entry_type = 'DEBIT'
                 THEN entry_amount ELSE 0 END) AS debit_total,

        SUM(CASE WHEN entry_type = 'CREDIT'
                 THEN entry_amount ELSE 0 END) AS credit_total,

        SUM(CASE WHEN entry_type = 'DEBIT'
                 THEN 1 ELSE 0 END) AS debit_count,

        SUM(CASE WHEN entry_type = 'CREDIT'
                 THEN 1 ELSE 0 END) AS credit_count

    FROM clean.TransactionEntries
    GROUP BY transaction_id
)

SELECT
    COUNT(*) AS invalid_ledger_transactions

FROM clean.Transactions T

LEFT JOIN LedgerSummary L
    ON T.transaction_id = L.transaction_id

WHERE L.transaction_id IS NULL
   OR L.entry_count <> 2
   OR L.debit_count <> 1
   OR L.credit_count <> 1
   OR L.debit_total <> T.transaction_amount
   OR L.credit_total <> T.transaction_amount;
GO
