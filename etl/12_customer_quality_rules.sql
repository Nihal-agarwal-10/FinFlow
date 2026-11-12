
USE FinFlowDB;
GO

/* =========================================================
   CUSTOMER ATTRIBUTE QUALITY VALIDATION
   ========================================================= */

CREATE OR ALTER PROCEDURE dq.usp_QuarantineInvalidCustomerAttributes
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        BEGIN TRANSACTION;

        -- Identify customers with invalid attributes.
        -- Customer IDs must already be valid numeric IDs.

        SELECT
            S.customer_id AS source_record_key,

            CASE
                WHEN NULLIF(TRIM(S.customer_ref), '') IS NULL
                    THEN 'Missing customer reference.'

                WHEN NULLIF(TRIM(S.first_name), '') IS NULL
                    THEN 'Missing customer first name.'

                WHEN NULLIF(TRIM(S.last_name), '') IS NULL
                    THEN 'Missing customer last name.'

                WHEN NULLIF(TRIM(S.email), '') IS NULL
                    THEN 'Missing customer email.'

                WHEN S.email LIKE '% %'
                  OR S.email NOT LIKE '%_@_%.__%'
                    THEN 'Invalid customer email format.'

                WHEN NULLIF(TRIM(S.phone), '') IS NULL
                    THEN 'Missing customer phone number.'

                WHEN UPPER(TRIM(S.customer_status))
                     NOT IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')
                    THEN 'Invalid customer status.'

                WHEN NULLIF(TRIM(S.date_of_birth), '') IS NOT NULL
                 AND TRY_CONVERT(DATE, S.date_of_birth) IS NULL
                    THEN 'Invalid date of birth format.'

                WHEN TRY_CONVERT(DATE, S.date_of_birth) > CONVERT(DATE, SYSUTCDATETIME())
                    THEN 'Date of birth cannot be in the future.'

            END AS rejection_reason,

            (
                SELECT
                    S.customer_id,
                    S.customer_ref,
                    S.first_name,
                    S.last_name,
                    S.email,
                    S.phone,
                    S.date_of_birth,
                    S.customer_status,
                    S.loaded_at
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS raw_record

        INTO #InvalidCustomers

        FROM stg.Customers AS S

        WHERE TRY_CONVERT(BIGINT, S.customer_id) IS NOT NULL

          AND
          (
              NULLIF(TRIM(S.customer_ref), '') IS NULL
              OR NULLIF(TRIM(S.first_name), '') IS NULL
              OR NULLIF(TRIM(S.last_name), '') IS NULL
              OR NULLIF(TRIM(S.email), '') IS NULL
              OR S.email LIKE '% %'
              OR S.email NOT LIKE '%_@_%.__%'
              OR NULLIF(TRIM(S.phone), '') IS NULL
              OR UPPER(TRIM(S.customer_status))
                    NOT IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')
              OR (
                    NULLIF(TRIM(S.date_of_birth), '') IS NOT NULL
                    AND TRY_CONVERT(DATE, S.date_of_birth) IS NULL
                 )
              OR TRY_CONVERT(DATE, S.date_of_birth)
                    > CONVERT(DATE, SYSUTCDATETIME())
          );


        -- Store rejected records.
        -- Avoid duplicate unresolved rejection records.

        INSERT INTO dq.RejectedRecords
        (
            source_table,
            source_record_key,
            rejection_reason,
            raw_record
        )
        SELECT
            'Customers',
            I.source_record_key,
            I.rejection_reason,
            I.raw_record

        FROM #InvalidCustomers AS I

        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dq.RejectedRecords AS R
            WHERE R.source_table = 'Customers'
              AND R.source_record_key = I.source_record_key
              AND R.rejection_reason = I.rejection_reason
              AND R.is_resolved = 0
        );


        -- Remove quarantined invalid customers from staging.

        DELETE S
        FROM stg.Customers AS S

        INNER JOIN #InvalidCustomers AS I
            ON S.customer_id = I.source_record_key;


        COMMIT TRANSACTION;


        -- Return the latest customer attribute rejections.

        SELECT
            rejection_id,
            source_record_key,
            rejection_reason,
            detected_at,
            is_resolved

        FROM dq.RejectedRecords

        WHERE source_table = 'Customers'

        ORDER BY rejection_id DESC;

    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO

USE FinFlowDB;
GO

IF NOT EXISTS (
    SELECT 1
    FROM stg.Customers
    WHERE customer_id = '9999999999'
)
BEGIN
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
    VALUES
    (
        '9999999999',
        'CUST_DQ_EMAIL_TEST',
        'Test',
        'Customer',
        'invalid-email',
        '9999999992',
        '2002-05-15',
        'ACTIVE'
    );
END;
GO


SELECT *
FROM stg.Customers
WHERE customer_ref = 'CUST_DQ_EMAIL_TEST';
GO

EXEC dq.usp_QuarantineInvalidCustomerAttributes;
GO

USE FinFlowDB;
GO

-- Verify original invalid data was preserved.
SELECT
    source_record_key,
    rejection_reason,
    raw_record
FROM dq.RejectedRecords
WHERE source_record_key = '9999999999';
GO

-- Verify invalid customer was removed from staging.
SELECT *
FROM stg.Customers
WHERE customer_ref = 'CUST_DQ_EMAIL_TEST';
GO