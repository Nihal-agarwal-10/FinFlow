
USE FinFlowDB;
GO

/* =========================================================
   1. MASTER CLEAN LAYER REFRESH PROCEDURE
   ========================================================= */

CREATE OR ALTER PROCEDURE etl.usp_RefreshCleanLayer
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RefreshStartedAt DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY

        BEGIN TRANSACTION;


        /* =================================================
           2. CLEAR EXISTING CLEAN DATA
           ================================================= */

        DELETE FROM clean.TransactionEntries;
        DELETE FROM clean.Transactions;
        DELETE FROM clean.Accounts;
        DELETE FROM clean.Merchants;
        DELETE FROM clean.Customers;
        DELETE FROM clean.Branches;


        /* =================================================
           3. CLEAN BRANCHES
           ================================================= */

        INSERT INTO clean.Branches
        (
            branch_id,
            branch_code,
            branch_name,
            city,
            state
        )
        SELECT
            TRY_CONVERT(INT, branch_id),
            TRIM(branch_code),
            TRIM(branch_name),
            TRIM(city),
            TRIM(state)
        FROM stg.Branches
        WHERE TRY_CONVERT(INT, branch_id) IS NOT NULL
          AND NULLIF(TRIM(branch_code), '') IS NOT NULL
          AND NULLIF(TRIM(branch_name), '') IS NOT NULL
          AND NULLIF(TRIM(city), '') IS NOT NULL
          AND NULLIF(TRIM(state), '') IS NOT NULL;


        /* =================================================
           4. CLEAN CUSTOMERS
           ================================================= */

        INSERT INTO clean.Customers
        (
            customer_id,
            customer_ref,
            first_name,
            last_name,
            email,
            phone,
            date_of_birth,
            customer_status
        )
        SELECT
            TRY_CONVERT(BIGINT, customer_id),
            TRIM(customer_ref),
            TRIM(first_name),
            TRIM(last_name),
            LOWER(TRIM(email)),
            TRIM(phone),
            TRY_CONVERT(DATE, date_of_birth),
            UPPER(TRIM(customer_status))
        FROM stg.Customers
        WHERE TRY_CONVERT(BIGINT, customer_id) IS NOT NULL
          AND NULLIF(TRIM(customer_ref), '') IS NOT NULL
          AND NULLIF(TRIM(first_name), '') IS NOT NULL
          AND NULLIF(TRIM(last_name), '') IS NOT NULL
          AND NULLIF(TRIM(email), '') IS NOT NULL
          AND TRIM(email) LIKE '%_@_%.__%'
          AND NULLIF(TRIM(phone), '') IS NOT NULL
          AND (
                NULLIF(TRIM(date_of_birth), '') IS NULL
                OR TRY_CONVERT(DATE, date_of_birth) IS NOT NULL
              )
          AND (
                TRY_CONVERT(DATE, date_of_birth) IS NULL
                OR TRY_CONVERT(DATE, date_of_birth)
                    <= CONVERT(DATE, SYSUTCDATETIME())
              )
          AND UPPER(TRIM(customer_status))
                IN ('ACTIVE', 'INACTIVE', 'SUSPENDED');


        /* =================================================
           5. CLEAN MERCHANTS
           ================================================= */

        INSERT INTO clean.Merchants
        (
            merchant_id,
            merchant_code,
            merchant_name,
            merchant_category,
            city,
            country
        )
        SELECT
            TRY_CONVERT(INT, merchant_id),
            TRIM(merchant_code),
            TRIM(merchant_name),
            UPPER(TRIM(merchant_category)),
            NULLIF(TRIM(city), ''),
            TRIM(country)
        FROM stg.Merchants
        WHERE TRY_CONVERT(INT, merchant_id) IS NOT NULL
          AND NULLIF(TRIM(merchant_code), '') IS NOT NULL
          AND NULLIF(TRIM(merchant_name), '') IS NOT NULL
          AND NULLIF(TRIM(merchant_category), '') IS NOT NULL
          AND NULLIF(TRIM(country), '') IS NOT NULL;


        /* =================================================
           6. CLEAN ACCOUNTS
           ================================================= */

        INSERT INTO clean.Accounts
        (
            account_id,
            account_number,
            customer_id,
            branch_id,
            account_type,
            account_status,
            currency_code,
            current_balance,
            opened_at,
            modified_at
        )
        SELECT
            TRY_CONVERT(BIGINT, S.account_id),
            TRIM(S.account_number),
            TRY_CONVERT(BIGINT, S.customer_id),
            TRY_CONVERT(INT, S.branch_id),
            UPPER(TRIM(S.account_type)),
            UPPER(TRIM(S.account_status)),
            UPPER(TRIM(S.currency_code)),
            TRY_CONVERT(DECIMAL(19,4), S.current_balance),
            TRY_CONVERT(DATETIME2, S.opened_at),
            TRY_CONVERT(DATETIME2, S.modified_at)
        FROM stg.Accounts AS S

        WHERE TRY_CONVERT(BIGINT, S.account_id) IS NOT NULL
          AND NULLIF(TRIM(S.account_number), '') IS NOT NULL

          AND EXISTS
          (
              SELECT 1
              FROM clean.Customers C
              WHERE C.customer_id =
                    TRY_CONVERT(BIGINT, S.customer_id)
          )

          AND EXISTS
          (
              SELECT 1
              FROM clean.Branches B
              WHERE B.branch_id =
                    TRY_CONVERT(INT, S.branch_id)
          )

          AND UPPER(TRIM(S.account_type))
                IN ('SAVINGS', 'CURRENT', 'SALARY')

          AND UPPER(TRIM(S.account_status))
                IN ('ACTIVE', 'INACTIVE', 'FROZEN', 'CLOSED')

          AND LEN(TRIM(S.currency_code)) = 3

          AND TRY_CONVERT(DECIMAL(19,4), S.current_balance) >= 0

          AND TRY_CONVERT(DATETIME2, S.opened_at) IS NOT NULL
          AND TRY_CONVERT(DATETIME2, S.modified_at) IS NOT NULL;


        /* =================================================
           7. CLEAN TRANSACTIONS
           ================================================= */

        INSERT INTO clean.Transactions
        (
            transaction_id,
            transaction_ref,
            merchant_id,
            transaction_type,
            transaction_status,
            transaction_amount,
            currency_code,
            transaction_channel,
            occurred_at,
            created_at
        )
        SELECT
            TRY_CONVERT(BIGINT, S.transaction_id),
            TRIM(S.transaction_ref),
            TRY_CONVERT(INT, NULLIF(TRIM(S.merchant_id), '')),
            UPPER(TRIM(S.transaction_type)),
            UPPER(TRIM(S.transaction_status)),
            TRY_CONVERT(DECIMAL(19,4), S.transaction_amount),
            UPPER(TRIM(S.currency_code)),
            UPPER(TRIM(S.transaction_channel)),
            TRY_CONVERT(DATETIME2, S.occurred_at),
            TRY_CONVERT(DATETIME2, S.created_at)
        FROM stg.Transactions AS S

        WHERE TRY_CONVERT(BIGINT, S.transaction_id) IS NOT NULL
          AND NULLIF(TRIM(S.transaction_ref), '') IS NOT NULL

          AND (
                NULLIF(TRIM(S.merchant_id), '') IS NULL
                OR EXISTS
                (
                    SELECT 1
                    FROM clean.Merchants M
                    WHERE M.merchant_id =
                          TRY_CONVERT(INT, S.merchant_id)
                )
              )

          AND UPPER(TRIM(S.transaction_type))
                IN ('PAYMENT', 'DEPOSIT', 'WITHDRAWAL', 'TRANSFER')

          AND UPPER(TRIM(S.transaction_status))
                IN ('PENDING', 'COMPLETED', 'FAILED', 'REVERSED')

          AND TRY_CONVERT(DECIMAL(19,4), S.transaction_amount) > 0

          AND LEN(TRIM(S.currency_code)) = 3

          AND UPPER(TRIM(S.transaction_channel))
                IN ('UPI', 'CARD', 'NEFT', 'IMPS', 'RTGS', 'ATM', 'BRANCH')

          AND TRY_CONVERT(DATETIME2, S.occurred_at) IS NOT NULL
          AND TRY_CONVERT(DATETIME2, S.created_at) IS NOT NULL;


        /* =================================================
           8. CLEAN TRANSACTION ENTRIES
           ================================================= */

        INSERT INTO clean.TransactionEntries
        (
            entry_id,
            transaction_id,
            account_id,
            entry_type,
            entry_amount,
            entry_timestamp
        )
        SELECT
            TRY_CONVERT(BIGINT, S.entry_id),
            TRY_CONVERT(BIGINT, S.transaction_id),
            TRY_CONVERT(BIGINT, S.account_id),
            UPPER(TRIM(S.entry_type)),
            TRY_CONVERT(DECIMAL(19,4), S.entry_amount),
            TRY_CONVERT(DATETIME2, S.entry_timestamp)
        FROM stg.TransactionEntries AS S

        WHERE TRY_CONVERT(BIGINT, S.entry_id) IS NOT NULL

          AND EXISTS
          (
              SELECT 1
              FROM clean.Transactions T
              WHERE T.transaction_id =
                    TRY_CONVERT(BIGINT, S.transaction_id)
          )

          AND EXISTS
          (
              SELECT 1
              FROM clean.Accounts A
              WHERE A.account_id =
                    TRY_CONVERT(BIGINT, S.account_id)
          )

          AND UPPER(TRIM(S.entry_type))
                IN ('DEBIT', 'CREDIT')

          AND TRY_CONVERT(DECIMAL(19,4), S.entry_amount) > 0

          AND TRY_CONVERT(DATETIME2, S.entry_timestamp) IS NOT NULL;


        /* =================================================
           9. COMMIT REFRESH
           ================================================= */

        COMMIT TRANSACTION;


        /* =================================================
           10. RETURN REFRESH SUMMARY
           ================================================= */

        SELECT
            'Branches' AS table_name,
            COUNT_BIG(*) AS records_loaded
        FROM clean.Branches

        UNION ALL

        SELECT 'Customers', COUNT_BIG(*)
        FROM clean.Customers

        UNION ALL

        SELECT 'Merchants', COUNT_BIG(*)
        FROM clean.Merchants

        UNION ALL

        SELECT 'Accounts', COUNT_BIG(*)
        FROM clean.Accounts

        UNION ALL

        SELECT 'Transactions', COUNT_BIG(*)
        FROM clean.Transactions

        UNION ALL

        SELECT 'TransactionEntries', COUNT_BIG(*)
        FROM clean.TransactionEntries;


    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO


/* =========================================================
   11. VERIFY PROCEDURE CREATION
   ========================================================= */

SELECT
    name AS procedure_name
FROM sys.procedures
WHERE name = 'usp_RefreshCleanLayer';
GO

USE FinFlowDB;
GO

SELECT
    SCHEMA_NAME(schema_id) AS schema_name,
    name AS procedure_name
FROM sys.procedures
WHERE object_id = OBJECT_ID('etl.usp_RefreshCleanLayer');
GO