
/*
=========================================================
PROJECT     : FinFlow
MODULE      : Synthetic Financial Data Generation
DATABASE    : FinFlowDB
PURPOSE     : Populate all six relational tables
=========================================================
*/

USE FinFlowDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Prevent accidental duplicate execution
    IF EXISTS (SELECT 1 FROM dbo.branches)
       OR EXISTS (SELECT 1 FROM dbo.customers)
       OR EXISTS (SELECT 1 FROM dbo.merchants)
       OR EXISTS (SELECT 1 FROM dbo.accounts)
       OR EXISTS (SELECT 1 FROM dbo.transactions)
       OR EXISTS (SELECT 1 FROM dbo.transaction_entries)
    BEGIN
        THROW 50001,
        'Tables are not empty. Aborting data generation.',
        1;
    END;

    /* ==============================================
       1. GENERATE BRANCHES (8)
    ============================================== */

    INSERT INTO dbo.branches
        (branch_code, branch_name, city, state)
    VALUES
        ('BR001', 'Hyderabad Main', 'Hyderabad', 'Telangana'),
        ('BR002', 'Bangalore Central', 'Bangalore', 'Karnataka'),
        ('BR003', 'Mumbai Central', 'Mumbai', 'Maharashtra'),
        ('BR004', 'Delhi North', 'Delhi', 'Delhi'),
        ('BR005', 'Chennai Central', 'Chennai', 'Tamil Nadu'),
        ('BR006', 'Pune Branch', 'Pune', 'Maharashtra'),
        ('BR007', 'Kolkata Main', 'Kolkata', 'West Bengal'),
        ('BR008', 'Ahmedabad Branch', 'Ahmedabad', 'Gujarat');


    /* ==============================================
       2. GENERATE CUSTOMERS (30)
    ============================================== */

    ;WITH Numbers AS
    (
        SELECT TOP (30)
            ROW_NUMBER() OVER (ORDER BY object_id) AS n
        FROM sys.all_objects
    )
    INSERT INTO dbo.customers
    (
        customer_ref,
        first_name,
        last_name,
        email,
        phone,
        date_of_birth,
        customer_status
    )
    SELECT
        CONCAT('CUS', RIGHT('0000' + CAST(n AS VARCHAR(4)), 4)),
        CONCAT('Customer', n),
        CONCAT('Family', n),
        CONCAT('customer', n, '@finflow.demo'),
        CONCAT('900000', RIGHT('0000' + CAST(n AS VARCHAR(4)), 4)),
        DATEADD(YEAR, -(20 + n % 35), CAST(GETDATE() AS DATE)),
        CASE
            WHEN n % 15 = 0 THEN 'INACTIVE'
            WHEN n % 17 = 0 THEN 'SUSPENDED'
            ELSE 'ACTIVE'
        END
    FROM Numbers;


    /* ==============================================
       3. GENERATE MERCHANTS (20)
    ============================================== */

    ;WITH Numbers AS
    (
        SELECT TOP (20)
            ROW_NUMBER() OVER (ORDER BY object_id) AS n
        FROM sys.all_objects
    )
    INSERT INTO dbo.merchants
    (
        merchant_code,
        merchant_name,
        merchant_category,
        city,
        country
    )
    SELECT
        CONCAT('MER', RIGHT('0000' + CAST(n AS VARCHAR(4)), 4)),
        CONCAT('Merchant ', n),
        CASE n % 5
            WHEN 0 THEN 'GROCERY'
            WHEN 1 THEN 'RETAIL'
            WHEN 2 THEN 'FOOD'
            WHEN 3 THEN 'TRAVEL'
            ELSE 'ENTERTAINMENT'
        END,
        CASE n % 5
            WHEN 0 THEN 'Hyderabad'
            WHEN 1 THEN 'Mumbai'
            WHEN 2 THEN 'Bangalore'
            WHEN 3 THEN 'Chennai'
            ELSE 'Delhi'
        END,
        'India'
    FROM Numbers;


    /* ==============================================
       4. GENERATE ACCOUNTS (40)
    ============================================== */

    ;WITH Numbers AS
    (
        SELECT TOP (40)
            ROW_NUMBER() OVER (ORDER BY object_id) AS n
        FROM sys.all_objects
    )
    INSERT INTO dbo.accounts
    (
        account_number,
        customer_id,
        branch_id,
        account_type,
        account_status,
        currency_code,
        current_balance
    )
    SELECT
        CONCAT('FF', RIGHT('0000000000' + CAST(n AS VARCHAR(10)), 10)),
        ((n - 1) % 30) + 1,
        ((n - 1) % 8) + 1,
        CASE n % 3
            WHEN 0 THEN 'SAVINGS'
            WHEN 1 THEN 'CURRENT'
            ELSE 'SALARY'
        END,
        'ACTIVE',
        'INR',
        CAST(10000 + (n * 1000) AS DECIMAL(19,4))
    FROM Numbers;


    /* ==============================================
       5. PREPARE TRANSACTION SEED DATA (300)
    ============================================== */

    CREATE TABLE #TransactionSeed
    (
        transaction_ref VARCHAR(40) PRIMARY KEY,
        source_account_number VARCHAR(30),
        destination_account_number VARCHAR(30),
        merchant_id INT NULL,
        amount DECIMAL(19,4),
        occurred_at DATETIME2(0),
        channel VARCHAR(20)
    );

    ;WITH Numbers AS
    (
        SELECT TOP (300)
            ROW_NUMBER() OVER (ORDER BY object_id) AS n
        FROM sys.all_objects
    )
    INSERT INTO #TransactionSeed
    SELECT
        CONCAT('FFTXN', RIGHT('000000' + CAST(n AS VARCHAR(6)), 6)),

        CONCAT('FF', RIGHT('0000000000' +
            CAST(((n - 1) % 40) + 1 AS VARCHAR(10)), 10)),

        CONCAT('FF', RIGHT('0000000000' +
            CAST((((n - 1 + 1 + (n % 39)) % 40) + 1)
            AS VARCHAR(10)), 10)),

        NULL,

        CAST(100 + (n % 20) * 50 AS DECIMAL(19,4)),

        DATEADD(MINUTE, -(n * 17), SYSUTCDATETIME()),

        CASE n % 5
            WHEN 0 THEN 'UPI'
            WHEN 1 THEN 'NEFT'
            WHEN 2 THEN 'IMPS'
            WHEN 3 THEN 'CARD'
            ELSE 'RTGS'
        END
    FROM Numbers;


    /* ==============================================
       6. INSERT TRANSACTIONS (300)
    ============================================== */

    INSERT INTO dbo.transactions
    (
        transaction_ref,
        merchant_id,
        transaction_type,
        transaction_status,
        transaction_amount,
        currency_code,
        transaction_channel,
        occurred_at
    )
    SELECT
        transaction_ref,
        merchant_id,
        'TRANSFER',
        'COMPLETED',
        amount,
        'INR',
        channel,
        occurred_at
    FROM #TransactionSeed;


    /* ==============================================
       7. GENERATE DOUBLE-ENTRY LEDGER (600)
    ============================================== */

    INSERT INTO dbo.transaction_entries
    (
        transaction_id,
        account_id,
        entry_type,
        entry_amount
    )
    SELECT
        t.transaction_id,
        a.account_id,
        'DEBIT',
        s.amount
    FROM #TransactionSeed s
    INNER JOIN dbo.transactions t
        ON t.transaction_ref = s.transaction_ref
    INNER JOIN dbo.accounts a
        ON a.account_number = s.source_account_number

    UNION ALL

    SELECT
        t.transaction_id,
        a.account_id,
        'CREDIT',
        s.amount
    FROM #TransactionSeed s
    INNER JOIN dbo.transactions t
        ON t.transaction_ref = s.transaction_ref
    INNER JOIN dbo.accounts a
        ON a.account_number = s.destination_account_number;


    /* ==============================================
       8. UPDATE ACCOUNT BALANCES
    ============================================== */

    UPDATE a
    SET
        current_balance =
            a.current_balance + COALESCE(x.net_amount, 0),
        modified_at = SYSUTCDATETIME()
    FROM dbo.accounts a
    OUTER APPLY
    (
        SELECT
            SUM(
                CASE
                    WHEN entry_type = 'CREDIT'
                        THEN entry_amount
                    ELSE -entry_amount
                END
            ) AS net_amount
        FROM dbo.transaction_entries e
        WHERE e.account_id = a.account_id
    ) x;


    /* ==============================================
       9. VERIFY DOUBLE-ENTRY BALANCING
    ============================================== */

    IF EXISTS
    (
        SELECT transaction_id
        FROM dbo.transaction_entries
        GROUP BY transaction_id
        HAVING
            SUM(CASE WHEN entry_type = 'DEBIT'
                THEN entry_amount ELSE 0 END)
            <>
            SUM(CASE WHEN entry_type = 'CREDIT'
                THEN entry_amount ELSE 0 END)
    )
    BEGIN
        THROW 50002,
        'Ledger validation failed. Transactions are not balanced.',
        1;
    END;

    COMMIT TRANSACTION;

    PRINT 'FinFlow data generation completed successfully.';

END TRY
BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
GO

-- Final record counts
SELECT 'Branches' AS Entity, COUNT(*) AS Total
FROM dbo.branches
UNION ALL
SELECT 'Customers', COUNT(*) FROM dbo.customers
UNION ALL
SELECT 'Merchants', COUNT(*) FROM dbo.merchants
UNION ALL
SELECT 'Accounts', COUNT(*) FROM dbo.accounts
UNION ALL
SELECT 'Transactions', COUNT(*) FROM dbo.transactions
UNION ALL
SELECT 'Transaction Entries', COUNT(*)
FROM dbo.transaction_entries;
