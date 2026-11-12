
USE FinFlowDB;
GO

/* =========================================================
   1. CREATE STAGING PIPELINE EXECUTION LOG
   ========================================================= */

IF OBJECT_ID('dbo.StagingPipelineRunLog', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.StagingPipelineRunLog
    (
        log_id BIGINT IDENTITY(1,1) PRIMARY KEY,

        run_id UNIQUEIDENTIFIER NOT NULL,

        step_name VARCHAR(100) NOT NULL,

        execution_status VARCHAR(20) NOT NULL,

        started_at DATETIME2(0) NOT NULL,

        completed_at DATETIME2(0) NULL,

        error_message NVARCHAR(4000) NULL
    );
END;
GO


/* =========================================================
   2. CREATE MASTER STAGING PIPELINE ORCHESTRATOR
   ========================================================= */

CREATE OR ALTER PROCEDURE dbo.usp_RunStagingPipeline
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RunID UNIQUEIDENTIFIER = NEWID();

    DECLARE @StepName VARCHAR(100);

    DECLARE @StepStartedAt DATETIME2(0);


    BEGIN TRY

        /* =============================================
           STEP 1: INCREMENTAL ETL
           ============================================= */

        SET @StepName = 'Incremental Source-to-Staging ETL';

        SET @StepStartedAt = SYSUTCDATETIME();

        EXEC dbo.usp_RunIncrementalETL;

        INSERT INTO dbo.StagingPipelineRunLog
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
           STEP 2: DATA QUALITY VALIDATION
           ============================================= */

        SET @StepName = 'Data Quality Validation';

        SET @StepStartedAt = SYSUTCDATETIME();

        EXEC dq.usp_RunAllDataQualityChecks;

        INSERT INTO dbo.StagingPipelineRunLog
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
           STEP 3: RETURN PIPELINE EXECUTION SUMMARY
           ============================================= */

        SELECT
            run_id,
            step_name,
            execution_status,
            started_at,
            completed_at
        FROM dbo.StagingPipelineRunLog
        WHERE run_id = @RunID
        ORDER BY log_id;

    END TRY

    BEGIN CATCH

        INSERT INTO dbo.StagingPipelineRunLog
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
            @StepName,
            'FAILED',
            COALESCE(@StepStartedAt, SYSUTCDATETIME()),
            SYSUTCDATETIME(),
            ERROR_MESSAGE()
        );

        SELECT
            run_id,
            step_name,
            execution_status,
            error_message
        FROM dbo.StagingPipelineRunLog
        WHERE run_id = @RunID;

        THROW;

    END CATCH;
END;
GO


/* =========================================================
   3. VERIFY PIPELINE OBJECTS
   ========================================================= */

SELECT
    name AS procedure_name
FROM sys.procedures
WHERE name IN
(
    'usp_RunIncrementalETL',
    'usp_RunStagingPipeline'
);

GO


USE FinFlowDB;
GO

EXEC dbo.usp_RunStagingPipeline;
GO

SELECT *
FROM dbo.StagingPipelineRunLog
ORDER BY log_id DESC;
GO