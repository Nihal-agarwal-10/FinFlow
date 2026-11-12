
USE FinFlowDB;
GO

/* =========================================================
   MERCHANT DATA QUALITY VALIDATION
   ========================================================= */

CREATE OR ALTER PROCEDURE dq.usp_QuarantineInvalidMerchants
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT
            S.merchant_id AS source_record_key,

            CASE
                WHEN TRY_CONVERT(INT, S.merchant_id) IS NULL
                    THEN 'Invalid merchant_id.'

                WHEN NULLIF(TRIM(S.merchant_code), '') IS NULL
                    THEN 'Missing merchant code.'

                WHEN (
                    SELECT COUNT(*)
                    FROM stg.Merchants S2
                    WHERE S2.merchant_code = S.merchant_code
                ) > 1
                    THEN 'Duplicate merchant code.'

                WHEN NULLIF(TRIM(S.merchant_name), '') IS NULL
                    THEN 'Missing merchant name.'

                WHEN NULLIF(TRIM(S.merchant_category), '') IS NULL
                    THEN 'Missing merchant category.'

                WHEN NULLIF(TRIM(S.country), '') IS NULL
                    THEN 'Missing merchant country.'
            END AS rejection_reason,

            (
                SELECT
                    S.merchant_id,
                    S.merchant_code,
                    S.merchant_name,
                    S.merchant_category,
                    S.city,
                    S.country,
                    S.loaded_at
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS raw_record

        INTO #InvalidMerchants

        FROM stg.Merchants AS S

        WHERE
            TRY_CONVERT(INT, S.merchant_id) IS NULL

            OR NULLIF(TRIM(S.merchant_code), '') IS NULL

            OR (
                SELECT COUNT(*)
                FROM stg.Merchants S2
                WHERE S2.merchant_code = S.merchant_code
            ) > 1

            OR NULLIF(TRIM(S.merchant_name), '') IS NULL
            OR NULLIF(TRIM(S.merchant_category), '') IS NULL
            OR NULLIF(TRIM(S.country), '') IS NULL;


        -- Preserve rejected records.

        INSERT INTO dq.RejectedRecords
        (
            source_table,
            source_record_key,
            rejection_reason,
            raw_record
        )
        SELECT
            'Merchants',
            COALESCE(
                I.source_record_key,
                '(MISSING_MERCHANT_ID)'
            ),
            I.rejection_reason,
            I.raw_record

        FROM #InvalidMerchants AS I

        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dq.RejectedRecords AS R
            WHERE R.source_table = 'Merchants'
              AND R.source_record_key =
                  COALESCE(
                      I.source_record_key,
                      '(MISSING_MERCHANT_ID)'
                  )
              AND R.rejection_reason = I.rejection_reason
              AND R.is_resolved = 0
        );


        -- Remove invalid records from staging.

        DELETE S
        FROM stg.Merchants AS S

        INNER JOIN #InvalidMerchants AS I
            ON S.merchant_id = I.source_record_key
            OR (
                S.merchant_id IS NULL
                AND I.source_record_key IS NULL
            );


        COMMIT TRANSACTION;


        -- Return rejection report.

        SELECT
            rejection_id,
            source_record_key,
            rejection_reason,
            detected_at,
            is_resolved
        FROM dq.RejectedRecords
        WHERE source_table = 'Merchants'
        ORDER BY rejection_id DESC;

    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO
