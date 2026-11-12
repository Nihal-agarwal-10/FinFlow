
USE FinFlowDB;
GO

/* =========================================================
   CENTRALIZED DATA QUALITY MONITORING
   ========================================================= */

CREATE OR ALTER PROCEDURE dq.usp_GetDataQualityReport
AS
BEGIN
    SET NOCOUNT ON;

    /* =====================================================
       REPORT 1: SUMMARY BY SOURCE TABLE
       ===================================================== */

    WITH SourceTables AS
    (
        SELECT source_table
        FROM
        (
            VALUES
                ('Branches'),
                ('Customers'),
                ('Merchants'),
                ('Accounts'),
                ('Transactions'),
                ('Transaction Entries')
        ) AS S(source_table)
    )

    SELECT
        S.source_table,

        COUNT(R.rejection_id) AS total_rejections,

        COUNT(DISTINCT R.source_record_key)
            AS affected_records,

        SUM(
            CASE
                WHEN R.is_resolved = 0 THEN 1
                ELSE 0
            END
        ) AS unresolved_rejections,

        SUM(
            CASE
                WHEN R.is_resolved = 1 THEN 1
                ELSE 0
            END
        ) AS resolved_rejections,

        MAX(R.detected_at) AS latest_rejection,

        CASE
            WHEN COUNT(R.rejection_id) = 0
                THEN 'CLEAN'
            WHEN SUM(
                CASE WHEN R.is_resolved = 0 THEN 1 ELSE 0 END
            ) > 0
                THEN 'ACTION REQUIRED'
            ELSE 'RESOLVED'
        END AS quality_status

    FROM SourceTables AS S

    LEFT JOIN dq.RejectedRecords AS R
        ON S.source_table = R.source_table

    GROUP BY S.source_table

    ORDER BY S.source_table;


    /* =====================================================
       REPORT 2: REJECTION BREAKDOWN BY REASON
       ===================================================== */

    SELECT
        source_table,
        rejection_reason,

        COUNT(*) AS rejection_count,

        SUM(
            CASE
                WHEN is_resolved = 0 THEN 1
                ELSE 0
            END
        ) AS unresolved_count,

        SUM(
            CASE
                WHEN is_resolved = 1 THEN 1
                ELSE 0
            END
        ) AS resolved_count

    FROM dq.RejectedRecords

    GROUP BY
        source_table,
        rejection_reason

    ORDER BY
        source_table,
        rejection_count DESC;


    /* =====================================================
       REPORT 3: LATEST UNRESOLVED REJECTIONS
       ===================================================== */

    SELECT TOP 100

        rejection_id,
        source_table,
        source_record_key,
        rejection_reason,
        detected_at,
        is_resolved

    FROM dq.RejectedRecords

    WHERE is_resolved = 0

    ORDER BY detected_at DESC;

END;
GO


EXEC dq.usp_GetDataQualityReport;
GO