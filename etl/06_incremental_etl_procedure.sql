USE FinFlowDB;
GO

CREATE TABLE dbo.ETL_SyncState
(
    table_name VARCHAR(128) PRIMARY KEY,
    last_sync_version BIGINT NOT NULL,
    last_sync_time DATETIME2(0) NOT NULL
        DEFAULT SYSUTCDATETIME()
);
GO

INSERT INTO dbo.ETL_SyncState
    (table_name, last_sync_version)
VALUES
    ('branches', CHANGE_TRACKING_CURRENT_VERSION());
GO

SELECT *
FROM dbo.ETL_SyncState;
GO


USE FinFlowDB;
GO

CREATE OR ALTER PROCEDURE dbo.usp_SyncBranches
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @LastVersion BIGINT;
    DECLARE @CurrentVersion BIGINT;
    DECLARE @MinValidVersion BIGINT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @LastVersion = last_sync_version
        FROM dbo.ETL_SyncState WITH (UPDLOCK, HOLDLOCK)
        WHERE table_name = 'branches';

        IF @LastVersion IS NULL
            THROW 50001, 'Branch synchronization checkpoint not found.', 1;

        SET @CurrentVersion = CHANGE_TRACKING_CURRENT_VERSION();

        SET @MinValidVersion =
            CHANGE_TRACKING_MIN_VALID_VERSION(
                OBJECT_ID('dbo.branches')
            );

        IF @LastVersion < @MinValidVersion
            THROW 50002, 'Change Tracking checkpoint expired. Full synchronization required.', 1;

        -- Capture changes before applying them.
        SELECT
            CT.branch_id,
            CT.SYS_CHANGE_OPERATION AS change_operation,
            B.branch_code,
            B.branch_name,
            B.city,
            B.state
        INTO #BranchChanges
        FROM CHANGETABLE(
            CHANGES dbo.branches,
            @LastVersion
        ) AS CT
        LEFT JOIN dbo.branches AS B
            ON B.branch_id = CT.branch_id;

        -- Update existing staging records.
        UPDATE S
        SET
            S.branch_code = C.branch_code,
            S.branch_name = C.branch_name,
            S.city = C.city,
            S.state = C.state
        FROM stg.Branches AS S
        JOIN #BranchChanges AS C
            ON TRY_CONVERT(INT, S.branch_id) = C.branch_id
        WHERE C.change_operation IN ('U', 'I');

        -- Insert new staging records.
        INSERT INTO stg.Branches
            (branch_id, branch_code, branch_name, city, state)
        SELECT
            C.branch_id,
            C.branch_code,
            C.branch_name,
            C.city,
            C.state
        FROM #BranchChanges AS C
        WHERE C.change_operation = 'I'
          AND NOT EXISTS (
              SELECT 1
              FROM stg.Branches AS S
              WHERE TRY_CONVERT(INT, S.branch_id) = C.branch_id
          );

        -- Delete records removed from the source.
        DELETE S
        FROM stg.Branches AS S
        JOIN #BranchChanges AS C
            ON TRY_CONVERT(INT, S.branch_id) = C.branch_id
        WHERE C.change_operation = 'D';

        -- Advance checkpoint only after successful synchronization.
        UPDATE dbo.ETL_SyncState
        SET
            last_sync_version = @CurrentVersion,
            last_sync_time = SYSUTCDATETIME()
        WHERE table_name = 'branches';

        COMMIT TRANSACTION;

        SELECT
            @LastVersion AS previous_version,
            @CurrentVersion AS current_version,
            (SELECT COUNT(*) FROM #BranchChanges) AS detected_changes;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

EXEC dbo.usp_SyncBranches;
GO

SELECT *
FROM dbo.ETL_SyncState
WHERE table_name = 'branches';
GO

USE FinFlowDB;
GO

IF NOT EXISTS (
    SELECT 1
    FROM dbo.ETL_SyncState
    WHERE table_name = 'customers'
)
BEGIN
    INSERT INTO dbo.ETL_SyncState
        (table_name, last_sync_version)
    VALUES
        ('customers', CHANGE_TRACKING_CURRENT_VERSION());
END;
GO

SELECT *
FROM dbo.ETL_SyncState;
GO


USE FinFlowDB;
GO

CREATE OR ALTER PROCEDURE dbo.usp_SyncCustomers
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @LastVersion BIGINT;
    DECLARE @CurrentVersion BIGINT;
    DECLARE @MinValidVersion BIGINT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @LastVersion = last_sync_version
        FROM dbo.ETL_SyncState WITH (UPDLOCK, HOLDLOCK)
        WHERE table_name = 'customers';

        IF @LastVersion IS NULL
            THROW 50011, 'Customer checkpoint not found.', 1;

        SET @CurrentVersion = CHANGE_TRACKING_CURRENT_VERSION();

        SET @MinValidVersion =
            CHANGE_TRACKING_MIN_VALID_VERSION(
                OBJECT_ID('dbo.customers')
            );

        IF @LastVersion < @MinValidVersion
            THROW 50012, 'Customer Change Tracking checkpoint expired.', 1;

        SELECT
            CT.customer_id,
            CT.SYS_CHANGE_OPERATION AS change_operation,
            C.customer_ref,
            C.first_name,
            C.last_name,
            C.email,
            C.phone,
            C.date_of_birth,
            C.customer_status
        INTO #CustomerChanges
        FROM CHANGETABLE(
            CHANGES dbo.customers,
            @LastVersion
        ) AS CT
        LEFT JOIN dbo.customers AS C
            ON C.customer_id = CT.customer_id;

        -- Update existing staging records.
        UPDATE S
        SET
            S.customer_ref = C.customer_ref,
            S.first_name = C.first_name,
            S.last_name = C.last_name,
            S.email = C.email,
            S.phone = C.phone,
            S.date_of_birth = C.date_of_birth,
            S.customer_status = C.customer_status
        FROM stg.Customers AS S
        JOIN #CustomerChanges AS C
            ON TRY_CONVERT(BIGINT, S.customer_id) = C.customer_id
        WHERE C.change_operation IN ('U', 'I');

        -- Insert new customers.
        INSERT INTO stg.Customers
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
            C.customer_id,
            C.customer_ref,
            C.first_name,
            C.last_name,
            C.email,
            C.phone,
            C.date_of_birth,
            C.customer_status
        FROM #CustomerChanges AS C
        WHERE C.change_operation = 'I'
          AND NOT EXISTS
          (
              SELECT 1
              FROM stg.Customers AS S
              WHERE TRY_CONVERT(BIGINT, S.customer_id) = C.customer_id
          );

        -- Delete removed customers.
        DELETE S
        FROM stg.Customers AS S
        JOIN #CustomerChanges AS C
            ON TRY_CONVERT(BIGINT, S.customer_id) = C.customer_id
        WHERE C.change_operation = 'D';

        -- Advance checkpoint.
        UPDATE dbo.ETL_SyncState
        SET
            last_sync_version = @CurrentVersion,
            last_sync_time = SYSUTCDATETIME()
        WHERE table_name = 'customers';

        COMMIT TRANSACTION;

        SELECT
            @LastVersion AS previous_version,
            @CurrentVersion AS current_version,
            (SELECT COUNT(*) FROM #CustomerChanges) AS detected_changes;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO


EXEC dbo.usp_SyncCustomers;
GO

SELECT
    customer_id,
    customer_ref,
    email,
    customer_status
FROM stg.Customers
WHERE customer_id = '1';
GO

USE FinFlowDB;
GO

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
VALUES
(
    'CUST_CT_001',
    'Test',
    'Customer',
    'ct_insert_test@finflow.demo',
    '9999999991',
    '2002-05-15',
    'ACTIVE'
);
GO

EXEC dbo.usp_SyncCustomers;
GO

SELECT *
FROM stg.Customers
WHERE customer_ref = 'CUST_CT_001';
GO

USE FinFlowDB;
GO

IF NOT EXISTS (
    SELECT 1
    FROM dbo.ETL_SyncState
    WHERE table_name = 'merchants'
)
BEGIN
    INSERT INTO dbo.ETL_SyncState
        (table_name, last_sync_version)
    VALUES
        ('merchants', CHANGE_TRACKING_CURRENT_VERSION());
END;
GO

SELECT *
FROM dbo.ETL_SyncState;
GO


USE FinFlowDB;
GO

CREATE OR ALTER PROCEDURE dbo.usp_SyncMerchants
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @LastVersion BIGINT;
    DECLARE @CurrentVersion BIGINT;
    DECLARE @MinValidVersion BIGINT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @LastVersion = last_sync_version
        FROM dbo.ETL_SyncState WITH (UPDLOCK, HOLDLOCK)
        WHERE table_name = 'merchants';

        IF @LastVersion IS NULL
            THROW 50021, 'Merchant checkpoint not found.', 1;

        SET @CurrentVersion = CHANGE_TRACKING_CURRENT_VERSION();

        SET @MinValidVersion =
            CHANGE_TRACKING_MIN_VALID_VERSION(
                OBJECT_ID('dbo.merchants')
            );

        IF @LastVersion < @MinValidVersion
            THROW 50022, 'Merchant Change Tracking checkpoint expired.', 1;

        SELECT
            CT.merchant_id,
            CT.SYS_CHANGE_OPERATION AS change_operation,
            M.merchant_code,
            M.merchant_name,
            M.merchant_category,
            M.city,
            M.country
        INTO #MerchantChanges
        FROM CHANGETABLE(
            CHANGES dbo.merchants,
            @LastVersion
        ) AS CT
        LEFT JOIN dbo.merchants AS M
            ON M.merchant_id = CT.merchant_id;

        -- Update existing staging records.
        UPDATE S
        SET
            S.merchant_code = C.merchant_code,
            S.merchant_name = C.merchant_name,
            S.merchant_category = C.merchant_category,
            S.city = C.city,
            S.country = C.country
        FROM stg.Merchants AS S
        JOIN #MerchantChanges AS C
            ON TRY_CONVERT(INT, S.merchant_id) = C.merchant_id
        WHERE C.change_operation IN ('U', 'I');

        -- Insert new merchants.
        INSERT INTO stg.Merchants
        (
            merchant_id,
            merchant_code,
            merchant_name,
            merchant_category,
            city,
            country
        )
        SELECT
            C.merchant_id,
            C.merchant_code,
            C.merchant_name,
            C.merchant_category,
            C.city,
            C.country
        FROM #MerchantChanges AS C
        WHERE C.change_operation = 'I'
          AND NOT EXISTS
          (
              SELECT 1
              FROM stg.Merchants AS S
              WHERE TRY_CONVERT(INT, S.merchant_id) = C.merchant_id
          );

        -- Delete removed merchants.
        DELETE S
        FROM stg.Merchants AS S
        JOIN #MerchantChanges AS C
            ON TRY_CONVERT(INT, S.merchant_id) = C.merchant_id
        WHERE C.change_operation = 'D';

        -- Advance checkpoint.
        UPDATE dbo.ETL_SyncState
        SET
            last_sync_version = @CurrentVersion,
            last_sync_time = SYSUTCDATETIME()
        WHERE table_name = 'merchants';

        COMMIT TRANSACTION;

        SELECT
            @LastVersion AS previous_version,
            @CurrentVersion AS current_version,
            (SELECT COUNT(*) FROM #MerchantChanges) AS detected_changes;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

EXEC dbo.usp_SyncMerchants;
GO

SELECT COUNT(*) AS staging_merchant_count
FROM stg.Merchants;
GO

USE FinFlowDB;
GO

IF NOT EXISTS (
    SELECT 1
    FROM dbo.ETL_SyncState
    WHERE table_name = 'accounts'
)
BEGIN
    INSERT INTO dbo.ETL_SyncState
        (table_name, last_sync_version)
    VALUES
        ('accounts', CHANGE_TRACKING_CURRENT_VERSION());
END;
GO

SELECT *
FROM dbo.ETL_SyncState;
GO


USE FinFlowDB;
GO

CREATE OR ALTER PROCEDURE dbo.usp_SyncAccounts
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @LastVersion BIGINT;
    DECLARE @CurrentVersion BIGINT;
    DECLARE @MinValidVersion BIGINT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @LastVersion = last_sync_version
        FROM dbo.ETL_SyncState WITH (UPDLOCK, HOLDLOCK)
        WHERE table_name = 'accounts';

        IF @LastVersion IS NULL
            THROW 50031, 'Account checkpoint not found.', 1;

        SET @CurrentVersion = CHANGE_TRACKING_CURRENT_VERSION();

        SET @MinValidVersion =
            CHANGE_TRACKING_MIN_VALID_VERSION(
                OBJECT_ID('dbo.accounts')
            );

        IF @LastVersion < @MinValidVersion
            THROW 50032, 'Account Change Tracking checkpoint expired.', 1;

        SELECT
            CT.account_id,
            CT.SYS_CHANGE_OPERATION AS change_operation,
            A.account_number,
            A.customer_id,
            A.branch_id,
            A.account_type,
            A.account_status,
            A.currency_code,
            A.current_balance,
            A.opened_at,
            A.modified_at
        INTO #AccountChanges
        FROM CHANGETABLE(
            CHANGES dbo.accounts,
            @LastVersion
        ) AS CT
        LEFT JOIN dbo.accounts AS A
            ON A.account_id = CT.account_id;

        -- Update existing staging records.
        UPDATE S
        SET
            S.account_number = C.account_number,
            S.customer_id = C.customer_id,
            S.branch_id = C.branch_id,
            S.account_type = C.account_type,
            S.account_status = C.account_status,
            S.currency_code = C.currency_code,
            S.current_balance = C.current_balance,
            S.opened_at = C.opened_at,
            S.modified_at = C.modified_at
        FROM stg.Accounts AS S
        JOIN #AccountChanges AS C
            ON TRY_CONVERT(BIGINT, S.account_id) = C.account_id
        WHERE C.change_operation IN ('U', 'I');

        -- Insert new accounts.
        INSERT INTO stg.Accounts
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
            C.account_id,
            C.account_number,
            C.customer_id,
            C.branch_id,
            C.account_type,
            C.account_status,
            C.currency_code,
            C.current_balance,
            C.opened_at,
            C.modified_at
        FROM #AccountChanges AS C
        WHERE C.change_operation = 'I'
          AND NOT EXISTS
          (
              SELECT 1
              FROM stg.Accounts AS S
              WHERE TRY_CONVERT(BIGINT, S.account_id) = C.account_id
          );

        -- Delete removed accounts.
        DELETE S
        FROM stg.Accounts AS S
        JOIN #AccountChanges AS C
            ON TRY_CONVERT(BIGINT, S.account_id) = C.account_id
        WHERE C.change_operation = 'D';

        -- Advance checkpoint.
        UPDATE dbo.ETL_SyncState
        SET
            last_sync_version = @CurrentVersion,
            last_sync_time = SYSUTCDATETIME()
        WHERE table_name = 'accounts';

        COMMIT TRANSACTION;

        SELECT
            @LastVersion AS previous_version,
            @CurrentVersion AS current_version,
            (SELECT COUNT(*) FROM #AccountChanges) AS detected_changes;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO


EXEC dbo.usp_SyncAccounts;
GO

SELECT COUNT(*) AS staging_account_count
FROM stg.Accounts;
GO

USE FinFlowDB;
GO

IF NOT EXISTS (
    SELECT 1
    FROM dbo.ETL_SyncState
    WHERE table_name = 'transactions'
)
BEGIN
    INSERT INTO dbo.ETL_SyncState
        (table_name, last_sync_version)
    VALUES
        ('transactions', CHANGE_TRACKING_CURRENT_VERSION());
END;
GO

SELECT *
FROM dbo.ETL_SyncState;
GO


USE FinFlowDB;
GO

CREATE OR ALTER PROCEDURE dbo.usp_SyncTransactions
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @LastVersion BIGINT;
    DECLARE @CurrentVersion BIGINT;
    DECLARE @MinValidVersion BIGINT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @LastVersion = last_sync_version
        FROM dbo.ETL_SyncState WITH (UPDLOCK, HOLDLOCK)
        WHERE table_name = 'transactions';

        IF @LastVersion IS NULL
            THROW 50041, 'Transaction checkpoint not found.', 1;

        SET @CurrentVersion = CHANGE_TRACKING_CURRENT_VERSION();

        SET @MinValidVersion =
            CHANGE_TRACKING_MIN_VALID_VERSION(
                OBJECT_ID('dbo.transactions')
            );

        IF @LastVersion < @MinValidVersion
            THROW 50042, 'Transaction Change Tracking checkpoint expired.', 1;

        SELECT
            CT.transaction_id,
            CT.SYS_CHANGE_OPERATION AS change_operation,
            T.transaction_ref,
            T.merchant_id,
            T.transaction_type,
            T.transaction_status,
            T.transaction_amount,
            T.currency_code,
            T.transaction_channel,
            T.occurred_at
        INTO #TransactionChanges
        FROM CHANGETABLE(
            CHANGES dbo.transactions,
            @LastVersion
        ) AS CT
        LEFT JOIN dbo.transactions AS T
            ON T.transaction_id = CT.transaction_id;

        -- Update existing staging records.
        UPDATE S
        SET
            S.transaction_ref = C.transaction_ref,
            S.merchant_id = C.merchant_id,
            S.transaction_type = C.transaction_type,
            S.transaction_status = C.transaction_status,
            S.transaction_amount = C.transaction_amount,
            S.currency_code = C.currency_code,
            S.transaction_channel = C.transaction_channel,
            S.occurred_at = C.occurred_at
        FROM stg.Transactions AS S
        JOIN #TransactionChanges AS C
            ON TRY_CONVERT(BIGINT, S.transaction_id) = C.transaction_id
        WHERE C.change_operation IN ('U', 'I');

        -- Insert new transactions.
        INSERT INTO stg.Transactions
        (
            transaction_id,
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
            C.transaction_id,
            C.transaction_ref,
            C.merchant_id,
            C.transaction_type,
            C.transaction_status,
            C.transaction_amount,
            C.currency_code,
            C.transaction_channel,
            C.occurred_at
        FROM #TransactionChanges AS C
        WHERE C.change_operation = 'I'
          AND NOT EXISTS
          (
              SELECT 1
              FROM stg.Transactions AS S
              WHERE TRY_CONVERT(BIGINT, S.transaction_id) = C.transaction_id
          );

        -- Delete removed transactions.
        DELETE S
        FROM stg.Transactions AS S
        JOIN #TransactionChanges AS C
            ON TRY_CONVERT(BIGINT, S.transaction_id) = C.transaction_id
        WHERE C.change_operation = 'D';

        -- Advance checkpoint.
        UPDATE dbo.ETL_SyncState
        SET
            last_sync_version = @CurrentVersion,
            last_sync_time = SYSUTCDATETIME()
        WHERE table_name = 'transactions';

        COMMIT TRANSACTION;

        SELECT
            @LastVersion AS previous_version,
            @CurrentVersion AS current_version,
            (SELECT COUNT(*) FROM #TransactionChanges) AS detected_changes;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO


EXEC dbo.usp_SyncTransactions;
GO

SELECT COUNT(*) AS staging_transaction_count
FROM stg.Transactions;
GO

USE FinFlowDB;
GO

IF NOT EXISTS (
    SELECT 1
    FROM dbo.ETL_SyncState
    WHERE table_name = 'transaction_entries'
)
BEGIN
    INSERT INTO dbo.ETL_SyncState
        (table_name, last_sync_version)
    VALUES
        ('transaction_entries', CHANGE_TRACKING_CURRENT_VERSION());
END;
GO

SELECT *
FROM dbo.ETL_SyncState;
GO


USE FinFlowDB;
GO

CREATE OR ALTER PROCEDURE dbo.usp_SyncTransactionEntries
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @LastVersion BIGINT;
    DECLARE @CurrentVersion BIGINT;
    DECLARE @MinValidVersion BIGINT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @LastVersion = last_sync_version
        FROM dbo.ETL_SyncState WITH (UPDLOCK, HOLDLOCK)
        WHERE table_name = 'transaction_entries';

        IF @LastVersion IS NULL
            THROW 50051, 'Transaction entry checkpoint not found.', 1;

        SET @CurrentVersion = CHANGE_TRACKING_CURRENT_VERSION();

        SET @MinValidVersion =
            CHANGE_TRACKING_MIN_VALID_VERSION(
                OBJECT_ID('dbo.transaction_entries')
            );

        IF @LastVersion < @MinValidVersion
            THROW 50052, 'Transaction entry Change Tracking checkpoint expired.', 1;

        SELECT
            CT.entry_id,
            CT.SYS_CHANGE_OPERATION AS change_operation,
            E.transaction_id,
            E.account_id,
            E.entry_type,
            E.entry_amount,
            E.entry_timestamp
        INTO #EntryChanges
        FROM CHANGETABLE(
            CHANGES dbo.transaction_entries,
            @LastVersion
        ) AS CT
        LEFT JOIN dbo.transaction_entries AS E
            ON E.entry_id = CT.entry_id;

        -- Update existing staging records.
        UPDATE S
        SET
            S.transaction_id = C.transaction_id,
            S.account_id = C.account_id,
            S.entry_type = C.entry_type,
            S.entry_amount = C.entry_amount,
            S.entry_timestamp = C.entry_timestamp
        FROM stg.TransactionEntries AS S
        JOIN #EntryChanges AS C
            ON TRY_CONVERT(BIGINT, S.entry_id) = C.entry_id
        WHERE C.change_operation IN ('U', 'I');

        -- Insert new entries.
        INSERT INTO stg.TransactionEntries
        (
            entry_id,
            transaction_id,
            account_id,
            entry_type,
            entry_amount,
            entry_timestamp
        )
        SELECT
            C.entry_id,
            C.transaction_id,
            C.account_id,
            C.entry_type,
            C.entry_amount,
            C.entry_timestamp
        FROM #EntryChanges AS C
        WHERE C.change_operation = 'I'
          AND NOT EXISTS
          (
              SELECT 1
              FROM stg.TransactionEntries AS S
              WHERE TRY_CONVERT(BIGINT, S.entry_id) = C.entry_id
          );

        -- Delete removed entries.
        DELETE S
        FROM stg.TransactionEntries AS S
        JOIN #EntryChanges AS C
            ON TRY_CONVERT(BIGINT, S.entry_id) = C.entry_id
        WHERE C.change_operation = 'D';

        -- Advance checkpoint.
        UPDATE dbo.ETL_SyncState
        SET
            last_sync_version = @CurrentVersion,
            last_sync_time = SYSUTCDATETIME()
        WHERE table_name = 'transaction_entries';

        COMMIT TRANSACTION;

        SELECT
            @LastVersion AS previous_version,
            @CurrentVersion AS current_version,
            (SELECT COUNT(*) FROM #EntryChanges) AS detected_changes;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO


EXEC dbo.usp_SyncTransactionEntries;
GO

SELECT COUNT(*) AS staging_entry_count
FROM stg.TransactionEntries;
GO