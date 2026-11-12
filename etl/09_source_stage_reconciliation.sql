
USE FinFlowDB;
GO

DECLARE @Results TABLE
(
    table_name VARCHAR(100),
    source_count INT,
    staging_count INT,
    missing_in_staging INT,
    extra_in_staging INT
);

-- 1. Branches
INSERT INTO @Results
SELECT
    'Branches',
    (SELECT COUNT(*) FROM dbo.branches),
    (SELECT COUNT(*) FROM stg.Branches),
    (
        SELECT COUNT(*)
        FROM dbo.branches B
        WHERE NOT EXISTS
        (
            SELECT 1 FROM stg.Branches S
            WHERE TRY_CONVERT(INT, S.branch_id) = B.branch_id
        )
    ),
    (
        SELECT COUNT(*)
        FROM stg.Branches S
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.branches B
            WHERE B.branch_id = TRY_CONVERT(INT, S.branch_id)
        )
    );

-- 2. Customers
INSERT INTO @Results
SELECT
    'Customers',
    (SELECT COUNT(*) FROM dbo.customers),
    (SELECT COUNT(*) FROM stg.Customers),
    (
        SELECT COUNT(*)
        FROM dbo.customers C
        WHERE NOT EXISTS
        (
            SELECT 1 FROM stg.Customers S
            WHERE TRY_CONVERT(BIGINT, S.customer_id) = C.customer_id
        )
    ),
    (
        SELECT COUNT(*)
        FROM stg.Customers S
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.customers C
            WHERE C.customer_id = TRY_CONVERT(BIGINT, S.customer_id)
        )
    );

-- 3. Merchants
INSERT INTO @Results
SELECT
    'Merchants',
    (SELECT COUNT(*) FROM dbo.merchants),
    (SELECT COUNT(*) FROM stg.Merchants),
    (
        SELECT COUNT(*)
        FROM dbo.merchants M
        WHERE NOT EXISTS
        (
            SELECT 1 FROM stg.Merchants S
            WHERE TRY_CONVERT(INT, S.merchant_id) = M.merchant_id
        )
    ),
    (
        SELECT COUNT(*)
        FROM stg.Merchants S
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.merchants M
            WHERE M.merchant_id = TRY_CONVERT(INT, S.merchant_id)
        )
    );

-- 4. Accounts
INSERT INTO @Results
SELECT
    'Accounts',
    (SELECT COUNT(*) FROM dbo.accounts),
    (SELECT COUNT(*) FROM stg.Accounts),
    (
        SELECT COUNT(*)
        FROM dbo.accounts A
        WHERE NOT EXISTS
        (
            SELECT 1 FROM stg.Accounts S
            WHERE TRY_CONVERT(BIGINT, S.account_id) = A.account_id
        )
    ),
    (
        SELECT COUNT(*)
        FROM stg.Accounts S
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.accounts A
            WHERE A.account_id = TRY_CONVERT(BIGINT, S.account_id)
        )
    );

-- 5. Transactions
INSERT INTO @Results
SELECT
    'Transactions',
    (SELECT COUNT(*) FROM dbo.transactions),
    (SELECT COUNT(*) FROM stg.Transactions),
    (
        SELECT COUNT(*)
        FROM dbo.transactions T
        WHERE NOT EXISTS
        (
            SELECT 1 FROM stg.Transactions S
            WHERE TRY_CONVERT(BIGINT, S.transaction_id) = T.transaction_id
        )
    ),
    (
        SELECT COUNT(*)
        FROM stg.Transactions S
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.transactions T
            WHERE T.transaction_id = TRY_CONVERT(BIGINT, S.transaction_id)
        )
    );

-- 6. Transaction Entries
INSERT INTO @Results
SELECT
    'Transaction Entries',
    (SELECT COUNT(*) FROM dbo.transaction_entries),
    (SELECT COUNT(*) FROM stg.TransactionEntries),
    (
        SELECT COUNT(*)
        FROM dbo.transaction_entries E
        WHERE NOT EXISTS
        (
            SELECT 1 FROM stg.TransactionEntries S
            WHERE TRY_CONVERT(BIGINT, S.entry_id) = E.entry_id
        )
    ),
    (
        SELECT COUNT(*)
        FROM stg.TransactionEntries S
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.transaction_entries E
            WHERE E.entry_id = TRY_CONVERT(BIGINT, S.entry_id)
        )
    );

-- Final reconciliation report
SELECT
    table_name,
    source_count,
    staging_count,
    missing_in_staging,
    extra_in_staging,
    CASE
        WHEN source_count = staging_count
         AND missing_in_staging = 0
         AND extra_in_staging = 0
        THEN 'PASS'
        ELSE 'CHECK'
    END AS reconciliation_status
FROM @Results
ORDER BY table_name;
GO
