
USE FinFlowDB;
GO

/* =========================================================
   TRANSACTION DATA QUALITY VALIDATION
   ========================================================= */

CREATE OR ALTER PROCEDURE dq.usp_QuarantineInvalidTransactions
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        BEGIN TRANSACTION;

        /* Identify invalid transaction records */

        SELECT
            S.transaction_id AS source_record_key,

            CASE
                WHEN TRY_CONVERT(BIGINT, S.transaction_id) IS NULL
                    THEN 'Invalid transaction_id.'

                WHEN NULLIF(TRIM(S.transaction_ref), '') IS NULL
                    THEN 'Missing transaction reference.'

                WHEN (
                    SELECT COUNT(*)
                    FROM stg.Transactions S2
                    WHERE S2.transaction_ref = S.transaction_ref
                ) > 1
                    THEN 'Duplicate transaction reference.'

                WHEN NULLIF(TRIM(S.merchant_id), '') IS NOT NULL
                 AND TRY_CONVERT(INT, S.merchant_id) IS NULL
                    THEN 'Invalid merchant_id.'

                WHEN NULLIF(TRIM(S.merchant_id), '') IS NOT NULL
                 AND NOT EXISTS
                 (
                     SELECT 1
                     FROM dbo.merchants M
                     WHERE M.merchant_id =
                           TRY_CONVERT(INT, S.merchant_id)
                 )
                    THEN 'Merchant reference does not exist.'

                WHEN UPPER(TRIM(S.transaction_type))
                     NOT IN ('PAYMENT', 'DEPOSIT', 'WITHDRAWAL', 'TRANSFER')
                    THEN 'Invalid transaction type.'

                WHEN UPPER(TRIM(S.transaction_status))
                     NOT IN ('PENDING', 'COMPLETED', 'FAILED', 'REVERSED')
                    THEN 'Invalid transaction status.'

                WHEN TRY_CONVERT(DECIMAL(19,4), S.transaction_amount) IS NULL
                    THEN 'Invalid transaction amount.'

                WHEN TRY_CONVERT(DECIMAL(19,4), S.transaction_amount) <= 0
                    THEN 'Transaction amount must be greater than zero.'

                WHEN NULLIF(TRIM(S.currency_code), '') IS NULL
                  OR LEN(TRIM(S.currency_code)) <> 3
                    THEN 'Invalid currency code.'

                WHEN UPPER(TRIM(S.transaction_channel))
                     NOT IN ('UPI', 'CARD', 'NEFT', 'IMPS', 'RTGS', 'ATM', 'BRANCH')
                    THEN 'Invalid transaction channel.'

                WHEN TRY_CONVERT(DATETIME2(0), S.occurred_at) IS NULL
                    THEN 'Invalid transaction timestamp.'

            END AS rejection_reason,

            (
                SELECT
                    S.transaction_id,
                    S.transaction_ref,
                    S.merchant_id,
                    S.transaction_type,
                    S.transaction_status,
                    S.transaction_amount,
                    S.currency_code,
                    S.transaction_channel,
                    S.occurred_at,
                    S.loaded_at
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS raw_record

        INTO #InvalidTransactions

        FROM stg.Transactions AS S

        WHERE
            TRY_CONVERT(BIGINT, S.transaction_id) IS NULL

            OR NULLIF(TRIM(S.transaction_ref), '') IS NULL

            OR (
                SELECT COUNT(*)
                FROM stg.Transactions S2
                WHERE S2.transaction_ref = S.transaction_ref
            ) > 1

            OR (
                NULLIF(TRIM(S.merchant_id), '') IS NOT NULL
                AND TRY_CONVERT(INT, S.merchant_id) IS NULL
            )

            OR (
                NULLIF(TRIM(S.merchant_id), '') IS NOT NULL
                AND NOT EXISTS
                (
                    SELECT 1
                    FROM dbo.merchants M
                    WHERE M.merchant_id =
                          TRY_CONVERT(INT, S.merchant_id)
                )
            )

            OR UPPER(TRIM(S.transaction_type))
                NOT IN ('PAYMENT', 'DEPOSIT', 'WITHDRAWAL', 'TRANSFER')

            OR UPPER(TRIM(S.transaction_status))
                NOT IN ('PENDING', 'COMPLETED', 'FAILED', 'REVERSED')

            OR TRY_CONVERT(DECIMAL(19,4), S.transaction_amount) IS NULL

            OR TRY_CONVERT(DECIMAL(19,4), S.transaction_amount) <= 0

            OR NULLIF(TRIM(S.currency_code), '') IS NULL

            OR LEN(TRIM(S.currency_code)) <> 3

            OR UPPER(TRIM(S.transaction_channel))
                NOT IN ('UPI', 'CARD', 'NEFT', 'IMPS', 'RTGS', 'ATM', 'BRANCH')

            OR TRY_CONVERT(DATETIME2(0), S.occurred_at) IS NULL;


        /* Store rejected records in quarantine */

        INSERT INTO dq.RejectedRecords
        (
            source_table,
            source_record_key,
            rejection_reason,
            raw_record
        )
        SELECT
            'Transactions',
            COALESCE(
                I.source_record_key,
                '(MISSING_TRANSACTION_ID)'
            ),
            I.rejection_reason,
            I.raw_record

        FROM #InvalidTransactions AS I

        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dq.RejectedRecords AS R
            WHERE R.source_table = 'Transactions'
              AND R.source_record_key =
                  COALESCE(
                      I.source_record_key,
                      '(MISSING_TRANSACTION_ID)'
                  )
              AND R.rejection_reason = I.rejection_reason
              AND R.is_resolved = 0
        );


        /* Remove invalid records from staging */

        DELETE S
        FROM stg.Transactions AS S

        INNER JOIN #InvalidTransactions AS I
            ON S.transaction_id = I.source_record_key
            OR (
                S.transaction_id IS NULL
                AND I.source_record_key IS NULL
            );


        COMMIT TRANSACTION;


        /* Return transaction rejection report */

        SELECT
            rejection_id,
            source_record_key,
            rejection_reason,
            detected_at,
            is_resolved

        FROM dq.RejectedRecords

        WHERE source_table = 'Transactions'

        ORDER BY rejection_id DESC;


    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO
