
USE FinFlowDB;
GO

/* =========================================================
   CLEAN LAYER INTEGRITY VALIDATION PROCEDURE
   ========================================================= */

CREATE OR ALTER PROCEDURE etl.usp_ValidateCleanLayer
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ValidationResults TABLE
    (
        validation_check VARCHAR(150),
        failed_records BIGINT
    );


    /* =====================================================
       1. DUPLICATE PRIMARY BUSINESS IDENTIFIERS
       ===================================================== */

    INSERT INTO @ValidationResults
    SELECT 'Duplicate Branch IDs', COUNT_BIG(*)
    FROM
    (
        SELECT branch_id
        FROM clean.Branches
        GROUP BY branch_id
        HAVING COUNT(*) > 1
    ) X;

    INSERT INTO @ValidationResults
    SELECT 'Duplicate Customer IDs', COUNT_BIG(*)
    FROM
    (
        SELECT customer_id
        FROM clean.Customers
        GROUP BY customer_id
        HAVING COUNT(*) > 1
    ) X;

    INSERT INTO @ValidationResults
    SELECT 'Duplicate Merchant IDs', COUNT_BIG(*)
    FROM
    (
        SELECT merchant_id
        FROM clean.Merchants
        GROUP BY merchant_id
        HAVING COUNT(*) > 1
    ) X;

    INSERT INTO @ValidationResults
    SELECT 'Duplicate Account IDs', COUNT_BIG(*)
    FROM
    (
        SELECT account_id
        FROM clean.Accounts
        GROUP BY account_id
        HAVING COUNT(*) > 1
    ) X;

    INSERT INTO @ValidationResults
    SELECT 'Duplicate Transaction IDs', COUNT_BIG(*)
    FROM
    (
        SELECT transaction_id
        FROM clean.Transactions
        GROUP BY transaction_id
        HAVING COUNT(*) > 1
    ) X;

    INSERT INTO @ValidationResults
    SELECT 'Duplicate Entry IDs', COUNT_BIG(*)
    FROM
    (
        SELECT entry_id
        FROM clean.TransactionEntries
        GROUP BY entry_id
        HAVING COUNT(*) > 1
    ) X;


    /* =====================================================
       2. REFERENTIAL INTEGRITY
       ===================================================== */

    INSERT INTO @ValidationResults
    SELECT
        'Accounts without customers',
        COUNT_BIG(*)
    FROM clean.Accounts A
    LEFT JOIN clean.Customers C
        ON A.customer_id = C.customer_id
    WHERE C.customer_id IS NULL;

    INSERT INTO @ValidationResults
    SELECT
        'Accounts without branches',
        COUNT_BIG(*)
    FROM clean.Accounts A
    LEFT JOIN clean.Branches B
        ON A.branch_id = B.branch_id
    WHERE B.branch_id IS NULL;

    INSERT INTO @ValidationResults
    SELECT
        'Transactions without merchants',
        COUNT_BIG(*)
    FROM clean.Transactions T
    LEFT JOIN clean.Merchants M
        ON T.merchant_id = M.merchant_id
    WHERE T.merchant_id IS NOT NULL
      AND M.merchant_id IS NULL;

    INSERT INTO @ValidationResults
    SELECT
        'Entries without transactions',
        COUNT_BIG(*)
    FROM clean.TransactionEntries E
    LEFT JOIN clean.Transactions T
        ON E.transaction_id = T.transaction_id
    WHERE T.transaction_id IS NULL;

    INSERT INTO @ValidationResults
    SELECT
        'Entries without accounts',
        COUNT_BIG(*)
    FROM clean.TransactionEntries E
    LEFT JOIN clean.Accounts A
        ON E.account_id = A.account_id
    WHERE A.account_id IS NULL;


    /* =====================================================
       3. FINANCIAL LEDGER VALIDATION
       ===================================================== */

    ;WITH LedgerSummary AS
    (
        SELECT
            transaction_id,

            COUNT(*) AS entry_count,

            SUM(CASE
                WHEN entry_type = 'DEBIT'
                THEN 1 ELSE 0
            END) AS debit_count,

            SUM(CASE
                WHEN entry_type = 'CREDIT'
                THEN 1 ELSE 0
            END) AS credit_count,

            SUM(CASE
                WHEN entry_type = 'DEBIT'
                THEN entry_amount ELSE 0
            END) AS debit_total,

            SUM(CASE
                WHEN entry_type = 'CREDIT'
                THEN entry_amount ELSE 0
            END) AS credit_total

        FROM clean.TransactionEntries
        GROUP BY transaction_id
    )

    INSERT INTO @ValidationResults

    SELECT
        'Unbalanced or invalid ledger transactions',
        COUNT_BIG(*)

    FROM clean.Transactions T

    LEFT JOIN LedgerSummary L
        ON T.transaction_id = L.transaction_id

    WHERE L.transaction_id IS NULL
       OR L.entry_count <> 2
       OR L.debit_count <> 1
       OR L.credit_count <> 1
       OR L.debit_total <> T.transaction_amount
       OR L.credit_total <> T.transaction_amount;


    /* =====================================================
       4. RETURN VALIDATION REPORT
       ===================================================== */

    SELECT
        validation_check,
        failed_records,

        CASE
            WHEN failed_records = 0 THEN 'PASS'
            ELSE 'FAIL'
        END AS validation_status

    FROM @ValidationResults
    ORDER BY validation_check;


    /* =====================================================
       5. STOP PIPELINE IF VALIDATION FAILS
       ===================================================== */

    IF EXISTS
    (
        SELECT 1
        FROM @ValidationResults
        WHERE failed_records > 0
    )
    BEGIN
        THROW 50081,
            'Clean layer validation failed. Warehouse loading stopped.',
            1;
    END;

END;
GO


/* =========================================================
   6. VERIFY PROCEDURE CREATION
   ========================================================= */

SELECT
    SCHEMA_NAME(schema_id) AS schema_name,
    name AS procedure_name
FROM sys.procedures
WHERE object_id =
    OBJECT_ID('etl.usp_ValidateCleanLayer');
GO

USE FinFlowDB;
GO

EXEC etl.usp_ValidateCleanLayer;
GO