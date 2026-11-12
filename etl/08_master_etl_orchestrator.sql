
USE FinFlowDB;
GO

IF OBJECT_ID('dbo.ETL_RunLog', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ETL_RunLog
    (
        log_id BIGINT IDENTITY(1,1) PRIMARY KEY,
        run_id UNIQUEIDENTIFIER NOT NULL,
        step_name VARCHAR(100) NOT NULL,
        execution_status VARCHAR(20) NOT NULL,
        detected_changes INT NULL,
        started_at DATETIME2(0) NOT NULL,
        completed_at DATETIME2(0) NULL,
        error_message NVARCHAR(4000) NULL
    );
END;
GO



CREATE OR ALTER PROCEDURE dbo.usp_RunIncrementalETL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RunID UNIQUEIDENTIFIER = NEWID();
    DECLARE @StepName VARCHAR(100);
    DECLARE @StepStartedAt DATETIME2(0);

    DECLARE @Result TABLE
    (
        previous_version BIGINT,
        current_version BIGINT,
        detected_changes INT
    );

    BEGIN TRY

        -- STEP 1: Branches
        SET @StepName = 'Branches';
        SET @StepStartedAt = SYSUTCDATETIME();

        DELETE FROM @Result;
        INSERT INTO @Result
        EXEC dbo.usp_SyncBranches;

        INSERT INTO dbo.ETL_RunLog
        (
            run_id, step_name, execution_status,
            detected_changes, started_at, completed_at
        )
        SELECT
            @RunID, @StepName, 'SUCCESS',
            detected_changes, @StepStartedAt, SYSUTCDATETIME()
        FROM @Result;


        -- STEP 2: Customers
        SET @StepName = 'Customers';
        SET @StepStartedAt = SYSUTCDATETIME();

        DELETE FROM @Result;
        INSERT INTO @Result
        EXEC dbo.usp_SyncCustomers;

        INSERT INTO dbo.ETL_RunLog
        (
            run_id, step_name, execution_status,
            detected_changes, started_at, completed_at
        )
        SELECT
            @RunID, @StepName, 'SUCCESS',
            detected_changes, @StepStartedAt, SYSUTCDATETIME()
        FROM @Result;


        -- STEP 3: Merchants
        SET @StepName = 'Merchants';
        SET @StepStartedAt = SYSUTCDATETIME();

        DELETE FROM @Result;
        INSERT INTO @Result
        EXEC dbo.usp_SyncMerchants;

        INSERT INTO dbo.ETL_RunLog
        (
            run_id, step_name, execution_status,
            detected_changes, started_at, completed_at
        )
        SELECT
            @RunID, @StepName, 'SUCCESS',
            detected_changes, @StepStartedAt, SYSUTCDATETIME()
        FROM @Result;


        -- STEP 4: Accounts
        SET @StepName = 'Accounts';
        SET @StepStartedAt = SYSUTCDATETIME();

        DELETE FROM @Result;
        INSERT INTO @Result
        EXEC dbo.usp_SyncAccounts;

        INSERT INTO dbo.ETL_RunLog
        (
            run_id, step_name, execution_status,
            detected_changes, started_at, completed_at
        )
        SELECT
            @RunID, @StepName, 'SUCCESS',
            detected_changes, @StepStartedAt, SYSUTCDATETIME()
        FROM @Result;


        -- STEP 5: Transactions
        SET @StepName = 'Transactions';
        SET @StepStartedAt = SYSUTCDATETIME();

        DELETE FROM @Result;
        INSERT INTO @Result
        EXEC dbo.usp_SyncTransactions;

        INSERT INTO dbo.ETL_RunLog
        (
            run_id, step_name, execution_status,
            detected_changes, started_at, completed_at
        )
        SELECT
            @RunID, @StepName, 'SUCCESS',
            detected_changes, @StepStartedAt, SYSUTCDATETIME()
        FROM @Result;


        -- STEP 6: Transaction Entries
        SET @StepName = 'Transaction Entries';
        SET @StepStartedAt = SYSUTCDATETIME();

        DELETE FROM @Result;
        INSERT INTO @Result
        EXEC dbo.usp_SyncTransactionEntries;

        INSERT INTO dbo.ETL_RunLog
        (
            run_id, step_name, execution_status,
            detected_changes, started_at, completed_at
        )
        SELECT
            @RunID, @StepName, 'SUCCESS',
            detected_changes, @StepStartedAt, SYSUTCDATETIME()
        FROM @Result;


        -- Return run summary
        SELECT
            run_id,
            step_name,
            execution_status,
            detected_changes,
            started_at,
            completed_at
        FROM dbo.ETL_RunLog
        WHERE run_id = @RunID
        ORDER BY log_id;

    END TRY

    BEGIN CATCH

        INSERT INTO dbo.ETL_RunLog
        (
            run_id, step_name, execution_status,
            started_at, completed_at, error_message
        )
        VALUES
        (
            @RunID, @StepName, 'FAILED',
            @StepStartedAt, SYSUTCDATETIME(), ERROR_MESSAGE()
        );

        SELECT
            run_id,
            step_name,
            execution_status,
            detected_changes,
            error_message
        FROM dbo.ETL_RunLog
        WHERE run_id = @RunID
        ORDER BY log_id;

        THROW;

    END CATCH;
END;
GO



USE FinFlowDB;
GO

EXEC dbo.usp_RunIncrementalETL;
GO


SELECT *
FROM dbo.ETL_RunLog
ORDER BY log_id DESC;
GO