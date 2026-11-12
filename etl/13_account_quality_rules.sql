
USE FinFlowDB;
GO

/* =========================================================
   ACCOUNT DATA QUALITY VALIDATION
   ========================================================= */

CREATE OR ALTER PROCEDURE dq.usp_QuarantineInvalidAccounts
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        BEGIN TRANSACTION;

        /* Identify invalid account records */

        SELECT
            S.account_id AS source_record_key,

            CASE
                WHEN TRY_CONVERT(BIGINT, S.account_id) IS NULL
                    THEN 'Invalid account_id: cannot be converted to BIGINT.'

                WHEN NULLIF(TRIM(S.account_number), '') IS NULL
                    THEN 'Missing account number.'

                WHEN TRY_CONVERT(BIGINT, S.customer_id) IS NULL
                    THEN 'Invalid customer_id.'

                WHEN NOT EXISTS
                (
                    SELECT 1
                    FROM dbo.customers C
                    WHERE C.customer_id =
                          TRY_CONVERT(BIGINT, S.customer_id)
                )
                    THEN 'Customer reference does not exist.'

                WHEN TRY_CONVERT(INT, S.branch_id) IS NULL
                    THEN 'Invalid branch_id.'

                WHEN NOT EXISTS
                (
                    SELECT 1
                    FROM dbo.branches B
                    WHERE B.branch_id =
                          TRY_CONVERT(INT, S.branch_id)
                )
                    THEN 'Branch reference does not exist.'

                WHEN UPPER(TRIM(S.account_type))
                     NOT IN ('SAVINGS', 'CURRENT', 'SALARY')
                    THEN 'Invalid account type.'

                WHEN UPPER(TRIM(S.account_status))
                     NOT IN ('ACTIVE', 'INACTIVE', 'FROZEN', 'CLOSED')
                    THEN 'Invalid account status.'

                WHEN LEN(TRIM(S.currency_code)) <> 3
                    THEN 'Invalid currency code.'

                WHEN TRY_CONVERT(DECIMAL(19,4), S.current_balance) IS NULL
                    THEN 'Invalid account balance.'

                WHEN TRY_CONVERT(DECIMAL(19,4), S.current_balance) < 0
                    THEN 'Negative account balance.'

                WHEN TRY_CONVERT(DATETIME2, S.opened_at) IS NULL
                    THEN 'Invalid account opening date.'

                WHEN TRY_CONVERT(DATETIME2, S.modified_at) IS NULL
                    THEN 'Invalid account modification date.'

            END AS rejection_reason,

            (
                SELECT
                    S.account_id,
                    S.account_number,
                    S.customer_id,
                    S.branch_id,
                    S.account_type,
                    S.account_status,
                    S.currency_code,
                    S.current_balance,
                    S.opened_at,
                    S.modified_at,
                    S.loaded_at
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS raw_record

        INTO #InvalidAccounts

        FROM stg.Accounts AS S

        WHERE

            TRY_CONVERT(BIGINT, S.account_id) IS NULL

            OR NULLIF(TRIM(S.account_number), '') IS NULL

            OR TRY_CONVERT(BIGINT, S.customer_id) IS NULL

            OR NOT EXISTS
            (
                SELECT 1
                FROM dbo.customers C
                WHERE C.customer_id =
                      TRY_CONVERT(BIGINT, S.customer_id)
            )

            OR TRY_CONVERT(INT, S.branch_id) IS NULL

            OR NOT EXISTS
            (
                SELECT 1
                FROM dbo.branches B
                WHERE B.branch_id =
                      TRY_CONVERT(INT, S.branch_id)
            )

            OR UPPER(TRIM(S.account_type))
                   NOT IN ('SAVINGS', 'CURRENT', 'SALARY')

            OR UPPER(TRIM(S.account_status))
                   NOT IN ('ACTIVE', 'INACTIVE', 'FROZEN', 'CLOSED')

            OR LEN(TRIM(S.currency_code)) <> 3

            OR TRY_CONVERT(DECIMAL(19,4), S.current_balance) IS NULL

            OR TRY_CONVERT(DECIMAL(19,4), S.current_balance) < 0

            OR TRY_CONVERT(DATETIME2, S.opened_at) IS NULL

            OR TRY_CONVERT(DATETIME2, S.modified_at) IS NULL;


        /* Insert rejected records into quarantine */

        INSERT INTO dq.RejectedRecords
        (
            source_table,
            source_record_key,
            rejection_reason,
            raw_record
        )
        SELECT
            'Accounts',
            COALESCE(I.source_record_key, '(MISSING_ACCOUNT_ID)'),
            I.rejection_reason,
            I.raw_record

        FROM #InvalidAccounts AS I

        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dq.RejectedRecords AS R
            WHERE R.source_table = 'Accounts'
              AND R.source_record_key =
                  COALESCE(I.source_record_key, '(MISSING_ACCOUNT_ID)')
              AND R.rejection_reason = I.rejection_reason
              AND R.is_resolved = 0
        );


        /* Remove quarantined records from staging */

        DELETE S
        FROM stg.Accounts AS S

        INNER JOIN #InvalidAccounts AS I
            ON S.account_id = I.source_record_key
            OR (
                S.account_id IS NULL
                AND I.source_record_key IS NULL
            );


        COMMIT TRANSACTION;


        /* Return account rejection report */

        SELECT
            rejection_id,
            source_record_key,
            rejection_reason,
            detected_at,
            is_resolved

        FROM dq.RejectedRecords

        WHERE source_table = 'Accounts'

        ORDER BY rejection_id DESC;


    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO