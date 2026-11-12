
USE FinFlowDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Create clean schema
    IF NOT EXISTS (
        SELECT 1 FROM sys.schemas WHERE name = 'clean'
    )
        EXEC('CREATE SCHEMA clean');

    -- Prevent accidental overwrite
    IF OBJECT_ID('clean.Branches', 'U') IS NOT NULL
       OR OBJECT_ID('clean.Customers', 'U') IS NOT NULL
       OR OBJECT_ID('clean.Merchants', 'U') IS NOT NULL
       OR OBJECT_ID('clean.Accounts', 'U') IS NOT NULL
       OR OBJECT_ID('clean.Transactions', 'U') IS NOT NULL
       OR OBJECT_ID('clean.TransactionEntries', 'U') IS NOT NULL
    BEGIN
        THROW 50002,
        'Clean tables already exist. Review before rerunning.',
        1;
    END;

    -- 1. Clean Branches
    SELECT
        TRY_CONVERT(INT, TRIM(branch_id)) AS branch_id,
        UPPER(TRIM(branch_code)) AS branch_code,
        TRIM(branch_name) AS branch_name,
        TRIM(city) AS city,
        TRIM(state) AS state
    INTO clean.Branches
    FROM stg.Branches
    WHERE TRY_CONVERT(INT, TRIM(branch_id)) IS NOT NULL
      AND NULLIF(TRIM(branch_code), '') IS NOT NULL
      AND NULLIF(TRIM(branch_name), '') IS NOT NULL
      AND NULLIF(TRIM(city), '') IS NOT NULL
      AND NULLIF(TRIM(state), '') IS NOT NULL;

    -- 2. Clean Customers
    SELECT
        TRY_CONVERT(BIGINT, TRIM(customer_id)) AS customer_id,
        UPPER(TRIM(customer_ref)) AS customer_ref,
        TRIM(first_name) AS first_name,
        TRIM(last_name) AS last_name,
        LOWER(TRIM(email)) AS email,
        TRIM(phone) AS phone,
        TRY_CONVERT(DATE, TRIM(date_of_birth)) AS date_of_birth,
        UPPER(TRIM(customer_status)) AS customer_status
    INTO clean.Customers
    FROM stg.Customers
    WHERE TRY_CONVERT(BIGINT, TRIM(customer_id)) IS NOT NULL
      AND NULLIF(TRIM(customer_ref), '') IS NOT NULL
      AND NULLIF(TRIM(first_name), '') IS NOT NULL
      AND NULLIF(TRIM(last_name), '') IS NOT NULL
      AND NULLIF(TRIM(email), '') IS NOT NULL
      AND UPPER(TRIM(customer_status))
          IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')
      AND (
          NULLIF(TRIM(date_of_birth), '') IS NULL
          OR TRY_CONVERT(DATE, TRIM(date_of_birth)) IS NOT NULL
      );

    -- 3. Clean Merchants
    SELECT
        TRY_CONVERT(INT, TRIM(merchant_id)) AS merchant_id,
        UPPER(TRIM(merchant_code)) AS merchant_code,
        TRIM(merchant_name) AS merchant_name,
        UPPER(TRIM(merchant_category)) AS merchant_category,
        TRIM(city) AS city,
        COALESCE(NULLIF(TRIM(country), ''), 'India') AS country
    INTO clean.Merchants
    FROM stg.Merchants
    WHERE TRY_CONVERT(INT, TRIM(merchant_id)) IS NOT NULL
      AND NULLIF(TRIM(merchant_code), '') IS NOT NULL
      AND NULLIF(TRIM(merchant_name), '') IS NOT NULL
      AND NULLIF(TRIM(merchant_category), '') IS NOT NULL;

    -- 4. Clean Accounts
    SELECT
        TRY_CONVERT(BIGINT, TRIM(account_id)) AS account_id,
        UPPER(TRIM(account_number)) AS account_number,
        TRY_CONVERT(BIGINT, TRIM(customer_id)) AS customer_id,
        TRY_CONVERT(INT, TRIM(branch_id)) AS branch_id,
        UPPER(TRIM(account_type)) AS account_type,
        UPPER(TRIM(account_status)) AS account_status,
        UPPER(TRIM(currency_code)) AS currency_code,
        TRY_CONVERT(DECIMAL(19,4), TRIM(current_balance))
            AS current_balance,
        TRY_CONVERT(DATETIME2(0), TRIM(opened_at), 126)
            AS opened_at,
        TRY_CONVERT(DATETIME2(0), TRIM(modified_at), 126)
            AS modified_at
    INTO clean.Accounts
    FROM stg.Accounts
    WHERE TRY_CONVERT(BIGINT, TRIM(account_id)) IS NOT NULL
      AND NULLIF(TRIM(account_number), '') IS NOT NULL
      AND TRY_CONVERT(BIGINT, TRIM(customer_id)) IS NOT NULL
      AND TRY_CONVERT(INT, TRIM(branch_id)) IS NOT NULL
      AND UPPER(TRIM(account_type))
          IN ('SAVINGS', 'CURRENT', 'SALARY')
      AND UPPER(TRIM(account_status))
          IN ('ACTIVE', 'INACTIVE', 'FROZEN', 'CLOSED')
      AND TRY_CONVERT(DECIMAL(19,4), TRIM(current_balance)) >= 0
      AND TRY_CONVERT(DATETIME2(0), TRIM(opened_at), 126) IS NOT NULL;

    -- 5. Clean Transactions
    SELECT
        TRY_CONVERT(BIGINT, TRIM(transaction_id))
            AS transaction_id,
        UPPER(TRIM(transaction_ref)) AS transaction_ref,
        TRY_CONVERT(INT, NULLIF(TRIM(merchant_id), ''))
            AS merchant_id,
        UPPER(TRIM(transaction_type)) AS transaction_type,
        UPPER(TRIM(transaction_status)) AS transaction_status,
        TRY_CONVERT(DECIMAL(19,4), TRIM(transaction_amount))
            AS transaction_amount,
        UPPER(TRIM(currency_code)) AS currency_code,
        UPPER(TRIM(transaction_channel)) AS transaction_channel,
        TRY_CONVERT(DATETIME2(0), TRIM(occurred_at), 126)
            AS occurred_at,
        TRY_CONVERT(DATETIME2(0), TRIM(created_at), 126)
            AS created_at
    INTO clean.Transactions
    FROM stg.Transactions
    WHERE TRY_CONVERT(BIGINT, TRIM(transaction_id)) IS NOT NULL
      AND NULLIF(TRIM(transaction_ref), '') IS NOT NULL
      AND UPPER(TRIM(transaction_type))
          IN ('PAYMENT', 'DEPOSIT', 'WITHDRAWAL', 'TRANSFER')
      AND UPPER(TRIM(transaction_status))
          IN ('PENDING', 'COMPLETED', 'FAILED', 'REVERSED')
      AND TRY_CONVERT(DECIMAL(19,4), TRIM(transaction_amount)) > 0
      AND UPPER(TRIM(transaction_channel))
          IN ('UPI', 'CARD', 'NEFT', 'IMPS', 'RTGS', 'ATM', 'BRANCH')
      AND TRY_CONVERT(DATETIME2(0), TRIM(occurred_at), 126) IS NOT NULL;

    -- 6. Clean Transaction Entries
    SELECT
        TRY_CONVERT(BIGINT, TRIM(entry_id)) AS entry_id,
        TRY_CONVERT(BIGINT, TRIM(transaction_id)) AS transaction_id,
        TRY_CONVERT(BIGINT, TRIM(account_id)) AS account_id,
        UPPER(TRIM(entry_type)) AS entry_type,
        TRY_CONVERT(DECIMAL(19,4), TRIM(entry_amount))
            AS entry_amount,
        TRY_CONVERT(DATETIME2(0), TRIM(entry_timestamp), 126)
            AS entry_timestamp
    INTO clean.TransactionEntries
    FROM stg.TransactionEntries
    WHERE TRY_CONVERT(BIGINT, TRIM(entry_id)) IS NOT NULL
      AND TRY_CONVERT(BIGINT, TRIM(transaction_id)) IS NOT NULL
      AND TRY_CONVERT(BIGINT, TRIM(account_id)) IS NOT NULL
      AND UPPER(TRIM(entry_type)) IN ('DEBIT', 'CREDIT')
      AND TRY_CONVERT(DECIMAL(19,4), TRIM(entry_amount)) > 0
      AND TRY_CONVERT(DATETIME2(0), TRIM(entry_timestamp), 126)
          IS NOT NULL;

    COMMIT TRANSACTION;

    -- Display cleaning results
    SELECT 'Branches' AS Entity,
           (SELECT COUNT(*) FROM stg.Branches) AS RawRows,
           (SELECT COUNT(*) FROM clean.Branches) AS CleanRows
    UNION ALL
    SELECT 'Customers',
           (SELECT COUNT(*) FROM stg.Customers),
           (SELECT COUNT(*) FROM clean.Customers)
    UNION ALL
    SELECT 'Merchants',
           (SELECT COUNT(*) FROM stg.Merchants),
           (SELECT COUNT(*) FROM clean.Merchants)
    UNION ALL
    SELECT 'Accounts',
           (SELECT COUNT(*) FROM stg.Accounts),
           (SELECT COUNT(*) FROM clean.Accounts)
    UNION ALL
    SELECT 'Transactions',
           (SELECT COUNT(*) FROM stg.Transactions),
           (SELECT COUNT(*) FROM clean.Transactions)
    UNION ALL
    SELECT 'Transaction Entries',
           (SELECT COUNT(*) FROM stg.TransactionEntries),
           (SELECT COUNT(*) FROM clean.TransactionEntries);

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
