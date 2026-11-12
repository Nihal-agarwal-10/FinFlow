
USE FinFlowDB;
GO

/* =========================================================
   1. CREATE DATA QUALITY EXECUTION LOG
   ========================================================= */

IF OBJECT_ID('dq.QualityRunLog', 'U') IS NULL
BEGIN
    CREATE TABLE dq.QualityRunLog
    (
        log_id BIGINT IDENTITY(1,1) PRIMARY KEY,

        run_id UNIQUEIDENTIFIER NOT NULL,

        check_name VARCHAR(100) NOT NULL,

        execution_status VARCHAR(20) NOT NULL,

        started_at DATETIME2(0) NOT NULL,

        completed_at DATETIME2(0) NULL,

        error_message NVARCHAR(4000) NULL
    );
END;
GO


/* =========================================================
   2. CREATE MASTER DATA QUALITY ORCHESTRATOR
   ========================================================= */

CREATE OR ALTER PROCEDURE dq.usp_RunAllDataQualityChecks
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RunID UNIQUEIDENTIFIER = NEWID();

    DECLARE @StepName VARCHAR(100);

    DECLARE @StepStartedAt DATETIME2(0);


    BEGIN TRY

        /* =============================================
           STEP 1: BRANCH VALIDATION
           ============================================= */

        SET @StepName = 'Branches';
        SET @StepStartedAt = SYSUTCDATETIME();

        EXEC dq.usp_QuarantineInvalidBranches;

        INSERT INTO dq.QualityRunLog
        (
            run_id,
            check_name,
            execution_status,
            started_at,
            completed_at
        )
        VALUES
        (
            @RunID,
            @StepName,
            'SUCCESS',
            @StepStartedAt,
            SYSUTCDATETIME()
        );


        /* =============================================
           STEP 2: CUSTOMER ID VALIDATION
           ============================================= */

        SET @StepName = 'Customer ID Validation';
        SET @StepStartedAt = SYSUTCDATETIME();

        EXEC dq.usp_QuarantineInvalidCustomers;

        INSERT INTO dq.QualityRunLog
        (
            run_id,
            check_name,
            execution_status,
            started_at,
            completed_at
        )
        VALUES
        (
            @RunID,
            @StepName,
            'SUCCESS',
            @StepStartedAt,
            SYSUTCDATETIME()
        );


        /* =============================================
           STEP 3: CUSTOMER ATTRIBUTE VALIDATION
           ============================================= */

        SET @StepName = 'Customer Attribute Validation';
        SET @StepStartedAt = SYSUTCDATETIME();

        EXEC dq.usp_QuarantineInvalidCustomerAttributes;

        INSERT INTO dq.QualityRunLog
        (
            run_id,
            check_name,
            execution_status,
            started_at,
            completed_at
        )
        VALUES
        (
            @RunID,
            @StepName,
            'SUCCESS',
            @StepStartedAt,
            SYSUTCDATETIME()
        );


        /* =============================================
           STEP 4: MERCHANT VALIDATION
           ============================================= */

        SET @StepName = 'Merchants';
        SET @StepStartedAt = SYSUTCDATETIME();

        EXEC dq.usp_QuarantineInvalidMerchants;

        INSERT INTO dq.QualityRunLog
        (
            run_id,
            check_name,
            execution_status,
            started_at,
            completed_at
        )
        VALUES
        (
            @RunID,
            @StepName,
            'SUCCESS',
            @StepStartedAt,
            SYSUTCDATETIME()
        );


        /* =============================================
           STEP 5: ACCOUNT VALIDATION
           ============================================= */

        SET @StepName = 'Accounts';
        SET @StepStartedAt = SYSUTCDATETIME();

        EXEC dq.usp_QuarantineInvalidAccounts;

        INSERT INTO dq.QualityRunLog
        (
            run_id,
            check_name,
            execution_status,
            started_at,
            completed_at
        )
        VALUES
        (
            @RunID,
            @StepName,
            'SUCCESS',
            @StepStartedAt,
            SYSUTCDATETIME()
        );


        /* =============================================
           STEP 6: TRANSACTION VALIDATION
           ============================================= */

        SET @StepName = 'Transactions';
        SET @StepStartedAt = SYSUTCDATETIME();

        EXEC dq.usp_QuarantineInvalidTransactions;

        INSERT INTO dq.QualityRunLog
        (
            run_id,
            check_name,
            execution_status,
            started_at,
            completed_at
        )
        VALUES
        (
            @RunID,
            @StepName,
            'SUCCESS',
            @StepStartedAt,
            SYSUTCDATETIME()
        );


        /* =============================================
           STEP 7: TRANSACTION ENTRY VALIDATION
           ============================================= */

        SET @StepName = 'Transaction Entries';
        SET @StepStartedAt = SYSUTCDATETIME();

        EXEC dq.usp_QuarantineInvalidTransactionEntries;

        INSERT INTO dq.QualityRunLog
        (
            run_id,
            check_name,
            execution_status,
            started_at,
            completed_at
        )
        VALUES
        (
            @RunID,
            @StepName,
            'SUCCESS',
            @StepStartedAt,
            SYSUTCDATETIME()
        );


        /* =============================================
           STEP 8: GENERATE CENTRALIZED QUALITY REPORT
           ============================================= */

        EXEC dq.usp_GetDataQualityReport;


        /* =============================================
           STEP 9: RETURN EXECUTION SUMMARY
           ============================================= */

        SELECT
            run_id,
            check_name,
            execution_status,
            started_at,
            completed_at
        FROM dq.QualityRunLog
        WHERE run_id = @RunID
        ORDER BY log_id;


    END TRY

    BEGIN CATCH

        INSERT INTO dq.QualityRunLog
        (
            run_id,
            check_name,
            execution_status,
            started_at,
            completed_at,
            error_message
        )
        VALUES
        (
            @RunID,
            @StepName,
            'FAILED',
            @StepStartedAt,
            SYSUTCDATETIME(),
            ERROR_MESSAGE()
        );

        THROW;

    END CATCH;
END;
GO


USE FinFlowDB;
GO

EXEC dq.usp_RunAllDataQualityChecks;
GO

SELECT *
FROM dq.QualityRunLog
ORDER BY log_id DESC;
GO