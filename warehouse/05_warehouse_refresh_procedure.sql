
USE FinFlowDB;
GO

/* =========================================================
   FINFLOW - AUTOMATED DATA WAREHOUSE REFRESH
   ========================================================= */

/* =========================================================
   1. CREATE WAREHOUSE EXECUTION LOG
   ========================================================= */

IF OBJECT_ID('warehouse.WarehouseRunLog', 'U') IS NULL
BEGIN
    CREATE TABLE warehouse.WarehouseRunLog
    (
        run_id UNIQUEIDENTIFIER PRIMARY KEY,

        execution_status VARCHAR(20) NOT NULL,

        started_at DATETIME2(0) NOT NULL,
        completed_at DATETIME2(0) NULL,

        transaction_facts_inserted INT DEFAULT 0,
        transaction_facts_updated INT DEFAULT 0,

        ledger_facts_inserted INT DEFAULT 0,
        ledger_facts_updated INT DEFAULT 0,

        error_message NVARCHAR(4000) NULL
    );
END;
GO


/* =========================================================
   2. CREATE WAREHOUSE REFRESH PROCEDURE
   ========================================================= */

CREATE OR ALTER PROCEDURE warehouse.usp_RefreshWarehouse
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RunID UNIQUEIDENTIFIER = NEWID();
    DECLARE @StartedAt DATETIME2(0) = SYSUTCDATETIME();

    DECLARE @TransactionInserted INT = 0;
    DECLARE @TransactionUpdated INT = 0;

    DECLARE @LedgerInserted INT = 0;
    DECLARE @LedgerUpdated INT = 0;

    BEGIN TRY

        BEGIN TRANSACTION;


        /* =================================================
           STEP 1: UPDATE CUSTOMER DIMENSION - SCD TYPE 2
           ================================================= */

        EXEC warehouse.usp_LoadDimCustomer_SCD2;


        /* =================================================
           STEP 2: POPULATE DATE DIMENSION
           ================================================= */

        ;WITH RequiredDates AS
        (
            SELECT CAST(occurred_at AS DATE) AS full_date
            FROM clean.Transactions

            UNION

            SELECT CAST(entry_timestamp AS DATE)
            FROM clean.TransactionEntries
        )
        INSERT INTO warehouse.DimDate
        (
            date_key,
            full_date,
            day_number,
            month_number,
            month_name,
            quarter_number,
            year_number,
            day_of_week,
            is_weekend
        )
        SELECT
            CONVERT(INT, CONVERT(CHAR(8), D.full_date, 112)),
            D.full_date,
            DAY(D.full_date),
            MONTH(D.full_date),
            DATENAME(MONTH, D.full_date),
            DATEPART(QUARTER, D.full_date),
            YEAR(D.full_date),
            DATENAME(WEEKDAY, D.full_date),
            CASE
                WHEN DATEDIFF(DAY, '19000101', D.full_date) % 7
                     IN (5, 6)
                THEN 1
                ELSE 0
            END
        FROM RequiredDates D
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM warehouse.DimDate DD
            WHERE DD.full_date = D.full_date
        );


        /* =================================================
           STEP 3: SYNCHRONIZE BRANCH DIMENSION
           ================================================= */

        UPDATE D
        SET
            D.branch_code = C.branch_code,
            D.branch_name = C.branch_name,
            D.city = C.city,
            D.state = C.state
        FROM warehouse.DimBranch D
        INNER JOIN clean.Branches C
            ON D.branch_id = C.branch_id;


        INSERT INTO warehouse.DimBranch
        (
            branch_id,
            branch_code,
            branch_name,
            city,
            state
        )
        SELECT
            C.branch_id,
            C.branch_code,
            C.branch_name,
            C.city,
            C.state
        FROM clean.Branches C
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM warehouse.DimBranch D
            WHERE D.branch_id = C.branch_id
        );


        /* =================================================
           STEP 4: SYNCHRONIZE MERCHANT DIMENSION
           ================================================= */

        UPDATE D
        SET
            D.merchant_code = C.merchant_code,
            D.merchant_name = C.merchant_name,
            D.merchant_category = C.merchant_category,
            D.city = C.city,
            D.country = C.country
        FROM warehouse.DimMerchant D
        INNER JOIN clean.Merchants C
            ON D.merchant_id = C.merchant_id;


        INSERT INTO warehouse.DimMerchant
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
        FROM clean.Merchants C
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM warehouse.DimMerchant D
            WHERE D.merchant_id = C.merchant_id
        );


        /* =================================================
           STEP 5: SYNCHRONIZE ACCOUNT DIMENSION
           ================================================= */

        UPDATE D
        SET
            D.account_number = C.account_number,
            D.customer_id = C.customer_id,
            D.branch_id = C.branch_id,
            D.account_type = C.account_type,
            D.account_status = C.account_status,
            D.currency_code = C.currency_code
        FROM warehouse.DimAccount D
        INNER JOIN clean.Accounts C
            ON D.account_id = C.account_id;


        INSERT INTO warehouse.DimAccount
        (
            account_id,
            account_number,
            customer_id,
            branch_id,
            account_type,
            account_status,
            currency_code
        )
        SELECT
            C.account_id,
            C.account_number,
            C.customer_id,
            C.branch_id,
            C.account_type,
            C.account_status,
            C.currency_code
        FROM clean.Accounts C
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM warehouse.DimAccount D
            WHERE D.account_id = C.account_id
        );


        /* =================================================
           STEP 6: SYNCHRONIZE TRANSACTION TYPE DIMENSION
           ================================================= */

        INSERT INTO warehouse.DimTransactionType
        (
            transaction_type
        )
        SELECT DISTINCT
            C.transaction_type
        FROM clean.Transactions C
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM warehouse.DimTransactionType D
            WHERE D.transaction_type = C.transaction_type
        );


        /* =================================================
           STEP 7: SYNCHRONIZE TRANSACTION STATUS DIMENSION
           ================================================= */

        INSERT INTO warehouse.DimTransactionStatus
        (
            transaction_status
        )
        SELECT DISTINCT
            C.transaction_status
        FROM clean.Transactions C
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM warehouse.DimTransactionStatus D
            WHERE D.transaction_status = C.transaction_status
        );


        /* =================================================
           STEP 8: SYNCHRONIZE CHANNEL DIMENSION
           ================================================= */

        INSERT INTO warehouse.DimChannel
        (
            transaction_channel
        )
        SELECT DISTINCT
            C.transaction_channel
        FROM clean.Transactions C
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM warehouse.DimChannel D
            WHERE D.transaction_channel = C.transaction_channel
        );


        /* =================================================
           STEP 9: PREPARE TRANSACTION FACT SOURCE
           ================================================= */

        ;WITH EntryPairs AS
        (
            SELECT
                transaction_id,

                MAX(
                    CASE WHEN entry_type = 'DEBIT'
                         THEN account_id END
                ) AS debit_account_id,

                MAX(
                    CASE WHEN entry_type = 'CREDIT'
                         THEN account_id END
                ) AS credit_account_id,

                SUM(
                    CASE WHEN entry_type = 'DEBIT'
                         THEN 1 ELSE 0 END
                ) AS debit_count,

                SUM(
                    CASE WHEN entry_type = 'CREDIT'
                         THEN 1 ELSE 0 END
                ) AS credit_count

            FROM clean.TransactionEntries
            GROUP BY transaction_id

            HAVING
                SUM(CASE WHEN entry_type = 'DEBIT'
                         THEN 1 ELSE 0 END) = 1

                AND

                SUM(CASE WHEN entry_type = 'CREDIT'
                         THEN 1 ELSE 0 END) = 1

                AND COUNT(*) = 2
        )

        SELECT
            T.transaction_id,

            DD.date_key,

            DC.customer_key,

            DM.merchant_key,

            DA_Debit.account_key AS debit_account_key,

            DA_Credit.account_key AS credit_account_key,

            DType.transaction_type_key,

            DStatus.transaction_status_key,

            DChannel.channel_key,

            T.transaction_amount,

            T.currency_code

        INTO #TransactionFactSource

        FROM clean.Transactions T

        INNER JOIN EntryPairs EP
            ON T.transaction_id = EP.transaction_id

        INNER JOIN warehouse.DimDate DD
            ON DD.full_date = CAST(T.occurred_at AS DATE)

        INNER JOIN warehouse.DimAccount DA_Debit
            ON DA_Debit.account_id = EP.debit_account_id

        INNER JOIN warehouse.DimAccount DA_Credit
            ON DA_Credit.account_id = EP.credit_account_id

        OUTER APPLY
        (
            SELECT TOP (1)
                D.customer_key

            FROM warehouse.DimCustomer D

            WHERE D.customer_id = DA_Debit.customer_id

            ORDER BY
                CASE
                    WHEN T.occurred_at >= D.effective_from
                     AND T.occurred_at < D.effective_to
                    THEN 0

                    WHEN D.is_current = 1
                    THEN 1

                    ELSE 2
                END,

                D.effective_from DESC

        ) DC

        LEFT JOIN warehouse.DimMerchant DM
            ON DM.merchant_id = T.merchant_id

        INNER JOIN warehouse.DimTransactionType DType
            ON DType.transaction_type = T.transaction_type

        INNER JOIN warehouse.DimTransactionStatus DStatus
            ON DStatus.transaction_status = T.transaction_status

        INNER JOIN warehouse.DimChannel DChannel
            ON DChannel.transaction_channel = T.transaction_channel

        WHERE DC.customer_key IS NOT NULL;


        /* Ensure every clean transaction has a valid fact mapping. */

        IF
        (
            SELECT COUNT_BIG(*)
            FROM #TransactionFactSource
        )
        <>
        (
            SELECT COUNT_BIG(*)
            FROM clean.Transactions
        )
        BEGIN
            THROW 50071,
                'Some transactions could not be mapped to warehouse dimensions or balanced ledger entries.',
                1;
        END;


        /* =================================================
           STEP 10: UPDATE EXISTING TRANSACTION FACTS
           ================================================= */

        UPDATE F
        SET
            F.date_key = S.date_key,
            F.merchant_key = S.merchant_key,
            F.debit_account_key = S.debit_account_key,
            F.credit_account_key = S.credit_account_key,
            F.transaction_type_key = S.transaction_type_key,
            F.transaction_status_key = S.transaction_status_key,
            F.channel_key = S.channel_key,
            F.transaction_amount = S.transaction_amount,
            F.currency_code = S.currency_code

        FROM warehouse.FactTransactions F

        INNER JOIN #TransactionFactSource S
            ON F.transaction_id = S.transaction_id

        WHERE
            F.date_key <> S.date_key

            OR ISNULL(F.merchant_key, -1)
                <> ISNULL(S.merchant_key, -1)

            OR F.debit_account_key <> S.debit_account_key

            OR F.credit_account_key <> S.credit_account_key

            OR F.transaction_type_key <> S.transaction_type_key

            OR F.transaction_status_key <> S.transaction_status_key

            OR F.channel_key <> S.channel_key

            OR F.transaction_amount <> S.transaction_amount

            OR F.currency_code <> S.currency_code;

        SET @TransactionUpdated = @@ROWCOUNT;


        /* =================================================
           STEP 11: INSERT NEW TRANSACTION FACTS
           ================================================= */

        INSERT INTO warehouse.FactTransactions
        (
            transaction_id,
            date_key,
            customer_key,
            merchant_key,
            debit_account_key,
            credit_account_key,
            transaction_type_key,
            transaction_status_key,
            channel_key,
            transaction_amount,
            currency_code
        )
        SELECT
            S.transaction_id,
            S.date_key,
            S.customer_key,
            S.merchant_key,
            S.debit_account_key,
            S.credit_account_key,
            S.transaction_type_key,
            S.transaction_status_key,
            S.channel_key,
            S.transaction_amount,
            S.currency_code

        FROM #TransactionFactSource S

        WHERE NOT EXISTS
        (
            SELECT 1
            FROM warehouse.FactTransactions F
            WHERE F.transaction_id = S.transaction_id
        );

        SET @TransactionInserted = @@ROWCOUNT;


        /* =================================================
           STEP 12: PREPARE LEDGER FACT SOURCE
           ================================================= */

        SELECT
            E.entry_id,

            E.transaction_id,

            DD.date_key,

            DA.account_key,

            E.entry_type,

            E.entry_amount

        INTO #LedgerFactSource

        FROM clean.TransactionEntries E

        INNER JOIN clean.Transactions T
            ON T.transaction_id = E.transaction_id

        INNER JOIN warehouse.DimDate DD
            ON DD.full_date = CAST(T.occurred_at AS DATE)

        INNER JOIN warehouse.DimAccount DA
            ON DA.account_id = E.account_id;


        /* Ensure every clean ledger entry has a valid mapping. */

        IF
        (
            SELECT COUNT_BIG(*)
            FROM #LedgerFactSource
        )
        <>
        (
            SELECT COUNT_BIG(*)
            FROM clean.TransactionEntries
        )
        BEGIN
            THROW 50072,
                'Some ledger entries could not be mapped to warehouse dimensions.',
                1;
        END;


        /* =================================================
           STEP 13: UPDATE EXISTING LEDGER FACTS
           ================================================= */

        UPDATE F
        SET
            F.transaction_id = S.transaction_id,
            F.date_key = S.date_key,
            F.account_key = S.account_key,
            F.entry_type = S.entry_type,
            F.entry_amount = S.entry_amount

        FROM warehouse.FactLedgerEntries F

        INNER JOIN #LedgerFactSource S
            ON F.entry_id = S.entry_id

        WHERE
            F.transaction_id <> S.transaction_id
            OR F.date_key <> S.date_key
            OR F.account_key <> S.account_key
            OR F.entry_type <> S.entry_type
            OR F.entry_amount <> S.entry_amount;

        SET @LedgerUpdated = @@ROWCOUNT;


        /* =================================================
           STEP 14: INSERT NEW LEDGER FACTS
           ================================================= */

        INSERT INTO warehouse.FactLedgerEntries
        (
            entry_id,
            transaction_id,
            date_key,
            account_key,
            entry_type,
            entry_amount
        )
        SELECT
            S.entry_id,
            S.transaction_id,
            S.date_key,
            S.account_key,
            S.entry_type,
            S.entry_amount

        FROM #LedgerFactSource S

        WHERE NOT EXISTS
        (
            SELECT 1
            FROM warehouse.FactLedgerEntries F
            WHERE F.entry_id = S.entry_id
        );

        SET @LedgerInserted = @@ROWCOUNT;


        /* =================================================
           STEP 15: COMMIT WAREHOUSE REFRESH
           ================================================= */

        COMMIT TRANSACTION;


        /* =================================================
           STEP 16: WRITE SUCCESS LOG
           ================================================= */

        INSERT INTO warehouse.WarehouseRunLog
        (
            run_id,
            execution_status,
            started_at,
            completed_at,
            transaction_facts_inserted,
            transaction_facts_updated,
            ledger_facts_inserted,
            ledger_facts_updated
        )
        VALUES
        (
            @RunID,
            'SUCCESS',
            @StartedAt,
            SYSUTCDATETIME(),
            @TransactionInserted,
            @TransactionUpdated,
            @LedgerInserted,
            @LedgerUpdated
        );


        /* =================================================
           STEP 17: RETURN EXECUTION SUMMARY
           ================================================= */

        SELECT
            @RunID AS run_id,
            'SUCCESS' AS execution_status,

            @TransactionInserted
                AS transaction_facts_inserted,

            @TransactionUpdated
                AS transaction_facts_updated,

            @LedgerInserted
                AS ledger_facts_inserted,

            @LedgerUpdated
                AS ledger_facts_updated;


    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;


        INSERT INTO warehouse.WarehouseRunLog
        (
            run_id,
            execution_status,
            started_at,
            completed_at,
            transaction_facts_inserted,
            transaction_facts_updated,
            ledger_facts_inserted,
            ledger_facts_updated,
            error_message
        )
        VALUES
        (
            @RunID,
            'FAILED',
            @StartedAt,
            SYSUTCDATETIME(),
            @TransactionInserted,
            @TransactionUpdated,
            @LedgerInserted,
            @LedgerUpdated,
            ERROR_MESSAGE()
        );


        THROW;

    END CATCH;
END;
GO


/* =========================================================
   3. VERIFY PROCEDURE CREATION
   ========================================================= */

SELECT
    SCHEMA_NAME(schema_id) AS schema_name,
    name AS procedure_name
FROM sys.procedures
WHERE object_id =
    OBJECT_ID('warehouse.usp_RefreshWarehouse');
GO
