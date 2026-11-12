
USE FinFlowDB;
GO

/* =========================================================
   TRANSACTION ENTRY DATA QUALITY VALIDATION
   ========================================================= */

CREATE OR ALTER PROCEDURE dq.usp_QuarantineInvalidTransactionEntries
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        BEGIN TRANSACTION;

        /* Identify invalid transaction entries */

        SELECT
            S.entry_id AS source_record_key,

            CASE
                WHEN TRY_CONVERT(BIGINT, S.entry_id) IS NULL
                    THEN 'Invalid entry_id.'

                WHEN TRY_CONVERT(BIGINT, S.transaction_id) IS NULL
                    THEN 'Invalid transaction_id.'

                WHEN NOT EXISTS
                (
                    SELECT 1
                    FROM dbo.transactions T
                    WHERE T.transaction_id =
                          TRY_CONVERT(BIGINT, S.transaction_id)
                )
                    THEN 'Transaction reference does not exist.'

                WHEN TRY_CONVERT(BIGINT, S.account_id) IS NULL
                    THEN 'Invalid account_id.'

                WHEN NOT EXISTS
                (
                    SELECT 1
                    FROM dbo.accounts A
                    WHERE A.account_id =
                          TRY_CONVERT(BIGINT, S.account_id)
                )
                    THEN 'Account reference does not exist.'

                WHEN NULLIF(TRIM(S.entry_type), '') IS NULL
                  OR UPPER(TRIM(S.entry_type)) NOT IN ('DEBIT', 'CREDIT')
                    THEN 'Invalid entry type.'

                WHEN TRY_CONVERT(DECIMAL(19,4), S.entry_amount) IS NULL
                    THEN 'Invalid entry amount.'

                WHEN TRY_CONVERT(DECIMAL(19,4), S.entry_amount) <= 0
                    THEN 'Entry amount must be greater than zero.'

                WHEN TRY_CONVERT(DATETIME2(0), S.entry_timestamp) IS NULL
                    THEN 'Invalid entry timestamp.'

            END AS rejection_reason,

            (
                SELECT
                    S.entry_id,
                    S.transaction_id,
                    S.account_id,
                    S.entry_type,
                    S.entry_amount,
                    S.entry_timestamp,
                    S.loaded_at
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS raw_record

        INTO #InvalidEntries

        FROM stg.TransactionEntries AS S

        WHERE
            TRY_CONVERT(BIGINT, S.entry_id) IS NULL

            OR TRY_CONVERT(BIGINT, S.transaction_id) IS NULL

            OR NOT EXISTS
            (
                SELECT 1
                FROM dbo.transactions T
                WHERE T.transaction_id =
                      TRY_CONVERT(BIGINT, S.transaction_id)
            )

            OR TRY_CONVERT(BIGINT, S.account_id) IS NULL

            OR NOT EXISTS
            (
                SELECT 1
                FROM dbo.accounts A
                WHERE A.account_id =
                      TRY_CONVERT(BIGINT, S.account_id)
            )

            OR NULLIF(TRIM(S.entry_type), '') IS NULL

            OR UPPER(TRIM(S.entry_type))
                   NOT IN ('DEBIT', 'CREDIT')

            OR TRY_CONVERT(DECIMAL(19,4), S.entry_amount) IS NULL

            OR TRY_CONVERT(DECIMAL(19,4), S.entry_amount) <= 0

            OR TRY_CONVERT(DATETIME2(0), S.entry_timestamp) IS NULL;


        /* Insert rejected records into quarantine */

        INSERT INTO dq.RejectedRecords
        (
            source_table,
            source_record_key,
            rejection_reason,
            raw_record
        )
        SELECT
            'Transaction Entries',
            COALESCE(
                I.source_record_key,
                '(MISSING_ENTRY_ID)'
            ),
            I.rejection_reason,
            I.raw_record

        FROM #InvalidEntries AS I

        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dq.RejectedRecords AS R
            WHERE R.source_table = 'Transaction Entries'
              AND R.source_record_key =
                  COALESCE(
                      I.source_record_key,
                      '(MISSING_ENTRY_ID)'
                  )
              AND R.rejection_reason = I.rejection_reason
              AND R.is_resolved = 0
        );


        /* Remove quarantined invalid entries from staging */

        DELETE S
        FROM stg.TransactionEntries AS S

        INNER JOIN #InvalidEntries AS I
            ON S.entry_id = I.source_record_key
            OR (
                S.entry_id IS NULL
                AND I.source_record_key IS NULL
            );


        COMMIT TRANSACTION;


        /* Return rejection report */

        SELECT
            rejection_id,
            source_record_key,
            rejection_reason,
            detected_at,
            is_resolved

        FROM dq.RejectedRecords

        WHERE source_table = 'Transaction Entries'

        ORDER BY rejection_id DESC;


    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO
