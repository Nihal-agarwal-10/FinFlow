
USE FinFlowDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Prevent accidental duplicate loading
    IF EXISTS (SELECT 1 FROM stg.Branches)
       OR EXISTS (SELECT 1 FROM stg.Customers)
       OR EXISTS (SELECT 1 FROM stg.Merchants)
       OR EXISTS (SELECT 1 FROM stg.Accounts)
       OR EXISTS (SELECT 1 FROM stg.Transactions)
       OR EXISTS (SELECT 1 FROM stg.TransactionEntries)
    BEGIN
        THROW 50001,
        'Staging tables already contain data. Clear them before reloading.',
        1;
    END;

    -- 1. Branches
    INSERT INTO stg.Branches
        (branch_id, branch_code, branch_name, city, state)
    SELECT
        CONVERT(NVARCHAR(50), branch_id),
        CONVERT(NVARCHAR(100), branch_code),
        CONVERT(NVARCHAR(200), branch_name),
        CONVERT(NVARCHAR(150), city),
        CONVERT(NVARCHAR(150), state)
    FROM dbo.branches;

    -- 2. Customers
    INSERT INTO stg.Customers
        (customer_id, customer_ref, first_name, last_name,
         email, phone, date_of_birth, customer_status)
    SELECT
        CONVERT(NVARCHAR(50), customer_id),
        CONVERT(NVARCHAR(100), customer_ref),
        CONVERT(NVARCHAR(150), first_name),
        CONVERT(NVARCHAR(150), last_name),
        CONVERT(NVARCHAR(250), email),
        CONVERT(NVARCHAR(50), phone),
        CONVERT(NVARCHAR(50), date_of_birth, 23),
        CONVERT(NVARCHAR(50), customer_status)
    FROM dbo.customers;

    -- 3. Merchants
    INSERT INTO stg.Merchants
        (merchant_id, merchant_code, merchant_name,
         merchant_category, city, country)
    SELECT
        CONVERT(NVARCHAR(50), merchant_id),
        CONVERT(NVARCHAR(100), merchant_code),
        CONVERT(NVARCHAR(200), merchant_name),
        CONVERT(NVARCHAR(100), merchant_category),
        CONVERT(NVARCHAR(150), city),
        CONVERT(NVARCHAR(100), country)
    FROM dbo.merchants;

    -- 4. Accounts
    INSERT INTO stg.Accounts
        (account_id, account_number, customer_id, branch_id,
         account_type, account_status, currency_code,
         current_balance, opened_at, modified_at)
    SELECT
        CONVERT(NVARCHAR(50), account_id),
        CONVERT(NVARCHAR(100), account_number),
        CONVERT(NVARCHAR(50), customer_id),
        CONVERT(NVARCHAR(50), branch_id),
        CONVERT(NVARCHAR(50), account_type),
        CONVERT(NVARCHAR(50), account_status),
        CONVERT(NVARCHAR(20), currency_code),
        CONVERT(NVARCHAR(100), current_balance),
        CONVERT(NVARCHAR(50), opened_at, 126),
        CONVERT(NVARCHAR(50), modified_at, 126)
    FROM dbo.accounts;

    -- 5. Transactions
    INSERT INTO stg.Transactions
        (transaction_id, transaction_ref, merchant_id,
         transaction_type, transaction_status,
         transaction_amount, currency_code,
         transaction_channel, occurred_at, created_at)
    SELECT
        CONVERT(NVARCHAR(50), transaction_id),
        CONVERT(NVARCHAR(100), transaction_ref),
        CONVERT(NVARCHAR(50), merchant_id),
        CONVERT(NVARCHAR(50), transaction_type),
        CONVERT(NVARCHAR(50), transaction_status),
        CONVERT(NVARCHAR(100), transaction_amount),
        CONVERT(NVARCHAR(20), currency_code),
        CONVERT(NVARCHAR(50), transaction_channel),
        CONVERT(NVARCHAR(50), occurred_at, 126),
        CONVERT(NVARCHAR(50), created_at, 126)
    FROM dbo.transactions;

    -- 6. Transaction Entries
    INSERT INTO stg.TransactionEntries
        (entry_id, transaction_id, account_id,
         entry_type, entry_amount, entry_timestamp)
    SELECT
        CONVERT(NVARCHAR(50), entry_id),
        CONVERT(NVARCHAR(50), transaction_id),
        CONVERT(NVARCHAR(50), account_id),
        CONVERT(NVARCHAR(50), entry_type),
        CONVERT(NVARCHAR(100), entry_amount),
        CONVERT(NVARCHAR(50), entry_timestamp, 126)
    FROM dbo.transaction_entries;

    COMMIT TRANSACTION;

    -- Display staging record counts
    SELECT 'Branches' AS Entity, COUNT(*) AS Total
    FROM stg.Branches
    UNION ALL
    SELECT 'Customers', COUNT(*) FROM stg.Customers
    UNION ALL
    SELECT 'Merchants', COUNT(*) FROM stg.Merchants
    UNION ALL
    SELECT 'Accounts', COUNT(*) FROM stg.Accounts
    UNION ALL
    SELECT 'Transactions', COUNT(*) FROM stg.Transactions
    UNION ALL
    SELECT 'Transaction Entries', COUNT(*)
    FROM stg.TransactionEntries;

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
