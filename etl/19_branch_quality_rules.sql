
USE FinFlowDB;
GO

/* =========================================================
   BRANCH DATA QUALITY VALIDATION
   ========================================================= */

CREATE OR ALTER PROCEDURE dq.usp_QuarantineInvalidBranches
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT
            S.branch_id AS source_record_key,

            CASE
                WHEN TRY_CONVERT(INT, S.branch_id) IS NULL
                    THEN 'Invalid branch_id.'

                WHEN NULLIF(TRIM(S.branch_code), '') IS NULL
                    THEN 'Missing branch code.'

                WHEN (
                    SELECT COUNT(*)
                    FROM stg.Branches S2
                    WHERE S2.branch_code = S.branch_code
                ) > 1
                    THEN 'Duplicate branch code.'

                WHEN NULLIF(TRIM(S.branch_name), '') IS NULL
                    THEN 'Missing branch name.'

                WHEN NULLIF(TRIM(S.city), '') IS NULL
                    THEN 'Missing branch city.'

                WHEN NULLIF(TRIM(S.state), '') IS NULL
                    THEN 'Missing branch state.'
            END AS rejection_reason,

            (
                SELECT
                    S.branch_id,
                    S.branch_code,
                    S.branch_name,
                    S.city,
                    S.state,
                    S.loaded_at
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS raw_record

        INTO #InvalidBranches

        FROM stg.Branches AS S

        WHERE
            TRY_CONVERT(INT, S.branch_id) IS NULL
            OR NULLIF(TRIM(S.branch_code), '') IS NULL

            OR (
                SELECT COUNT(*)
                FROM stg.Branches S2
                WHERE S2.branch_code = S.branch_code
            ) > 1

            OR NULLIF(TRIM(S.branch_name), '') IS NULL
            OR NULLIF(TRIM(S.city), '') IS NULL
            OR NULLIF(TRIM(S.state), '') IS NULL;


        -- Save rejected records.

        INSERT INTO dq.RejectedRecords
        (
            source_table,
            source_record_key,
            rejection_reason,
            raw_record
        )
        SELECT
            'Branches',
            COALESCE(
                I.source_record_key,
                '(MISSING_BRANCH_ID)'
            ),
            I.rejection_reason,
            I.raw_record

        FROM #InvalidBranches AS I

        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dq.RejectedRecords AS R
            WHERE R.source_table = 'Branches'
              AND R.source_record_key =
                  COALESCE(
                      I.source_record_key,
                      '(MISSING_BRANCH_ID)'
                  )
              AND R.rejection_reason = I.rejection_reason
              AND R.is_resolved = 0
        );


        -- Remove invalid records from staging.

        DELETE S
        FROM stg.Branches AS S

        INNER JOIN #InvalidBranches AS I
            ON S.branch_id = I.source_record_key
            OR (
                S.branch_id IS NULL
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
        WHERE source_table = 'Branches'
        ORDER BY rejection_id DESC;

    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO
