
USE FinFlowDB;
GO

/* =========================================================
   FINFLOW - COMPLETE END-TO-END PIPELINE
   ========================================================= */


/* =========================================================
   1. CREATE MASTER PIPELINE EXECUTION LOG
   ========================================================= */

IF OBJECT_ID('dbo.FinFlowPipelineRunLog', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.FinFlowPipelineRunLog
    (
        log_id BIGINT IDENTITY(1,1) PRIMARY KEY,

        run_id UNIQUEIDENTIFIER NOT NULL,

        step_name VARCHAR(150) NOT NULL,

        execution_status VARCHAR(20) NOT NULL,

        started_at DATETIME2(0) NOT NULL,

        completed_at DATETIME2(0) NULL,

        error_message NVARCHAR(4000) NULL
    );
END;
GO


/* =========================================================
   2. CREATE MASTER FINFLOW PIPELINE
   ========================================================= */

CREATE OR ALTER PROCEDURE dbo.usp_RunFinFlowPipeline
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RunID UNIQUEIDENTIFIER = NEWID();

    DECLARE @StepName VARCHAR(150);

    DECLARE @StepStartedAt DATETIME2(0);

    DECLARE @PipelineStartedAt DATETIME2(0) =
        SYSUTCDATETIME();

    BEGIN TRY


        /* =============================================
           STEP 1: INCREMENTAL ETL + DATA QUALITY
           ============================================= */

        SET @StepName = 'Incremental ETL and Data Quality';

        SET @StepStartedAt = SYSUTCDATETIME();

        EXEC dbo.usp_RunStagingPipeline;

        INSERT INTO dbo.FinFlowPipelineRunLog
        (
            run_id,
            step_name,
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
           STEP 2: CLEAN LAYER REFRESH
           ============================================= */

        SET @StepName = 'Clean Layer Refresh';

        SET @StepStartedAt = SYSUTCDATETIME();

        EXEC etl.usp_RefreshCleanLayer;

        INSERT INTO dbo.FinFlowPipelineRunLog
        (
            run_id,
            step_name,
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
           STEP 3: CLEAN LAYER VALIDATION
           ============================================= */

        SET @StepName = 'Clean Layer Integrity Validation';

        SET @StepStartedAt = SYSUTCDATETIME();

        EXEC etl.usp_ValidateCleanLayer;

        INSERT INTO dbo.FinFlowPipelineRunLog
        (
            run_id,
            step_name,
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
           STEP 4: DATA WAREHOUSE REFRESH
           ============================================= */

        SET @StepName = 'Data Warehouse Refresh';

        SET @StepStartedAt = SYSUTCDATETIME();

        EXEC warehouse.usp_RefreshWarehouse;

        INSERT INTO dbo.FinFlowPipelineRunLog
        (
            run_id,
            step_name,
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
           STEP 5: FINAL PIPELINE EXECUTION SUMMARY
           ============================================= */

        SELECT
            run_id,
            step_name,
            execution_status,
            started_at,
            completed_at
        FROM dbo.FinFlowPipelineRunLog
        WHERE run_id = @RunID
        ORDER BY log_id;


        /* =============================================
           STEP 6: FINAL WAREHOUSE RECORD COUNTS
           ============================================= */

        SELECT
            'DimCustomer' AS table_name,
            COUNT_BIG(*) AS records
        FROM warehouse.DimCustomer

        UNION ALL

        SELECT 'DimBranch', COUNT_BIG(*)
        FROM warehouse.DimBranch

        UNION ALL

        SELECT 'DimMerchant', COUNT_BIG(*)
        FROM warehouse.DimMerchant

        UNION ALL

        SELECT 'DimAccount', COUNT_BIG(*)
        FROM warehouse.DimAccount

        UNION ALL

        SELECT 'FactTransactions', COUNT_BIG(*)
        FROM warehouse.FactTransactions

        UNION ALL

        SELECT 'FactLedgerEntries', COUNT_BIG(*)
        FROM warehouse.FactLedgerEntries;


    END TRY

    BEGIN CATCH

        INSERT INTO dbo.FinFlowPipelineRunLog
        (
            run_id,
            step_name,
            execution_status,
            started_at,
            completed_at,
            error_message
        )
        VALUES
        (
            @RunID,
            COALESCE(@StepName, 'Pipeline Initialization'),
            'FAILED',
            COALESCE(@StepStartedAt, @PipelineStartedAt),
            SYSUTCDATETIME(),
            ERROR_MESSAGE()
        );

        -- Return execution failure details.

        SELECT
            run_id,
            step_name,
            execution_status,
            error_message,
            started_at,
            completed_at
        FROM dbo.FinFlowPipelineRunLog
        WHERE run_id = @RunID
        ORDER BY log_id;

        THROW;

    END CATCH;
END;
GO


/* =========================================================
   3. VERIFY MASTER PROCEDURE CREATION
   ========================================================= */

SELECT
    SCHEMA_NAME(schema_id) AS schema_name,
    name AS procedure_name
FROM sys.procedures
WHERE object_id =
    OBJECT_ID('dbo.usp_RunFinFlowPipeline');
GO
