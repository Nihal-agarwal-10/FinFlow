USE master;
GO

ALTER DATABASE FinFlowDB
SET CHANGE_TRACKING = ON
(
    CHANGE_RETENTION = 2 DAYS,
    AUTO_CLEANUP = ON
);
GO

USE FinFlowDB;
GO

ALTER TABLE dbo.branches
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);
GO

ALTER TABLE dbo.customers
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);
GO

ALTER TABLE dbo.merchants
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);
GO

ALTER TABLE dbo.accounts
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);
GO

ALTER TABLE dbo.transactions
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);
GO

ALTER TABLE dbo.transaction_entries
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);
GO

SELECT
    OBJECT_NAME(object_id) AS table_name,
    is_track_columns_updated_on
FROM sys.change_tracking_tables
ORDER BY table_name;
GO

USE FinFlowDB;
GO

SELECT
    t.name AS table_name,
    CASE
        WHEN ct.object_id IS NOT NULL THEN 'ENABLED'
        ELSE 'NOT ENABLED'
    END AS change_tracking_status
FROM sys.tables t
LEFT JOIN sys.change_tracking_tables ct
    ON t.object_id = ct.object_id
WHERE t.schema_id = SCHEMA_ID('dbo')
  AND t.name IN (
      'branches',
      'customers',
      'merchants',
      'accounts',
      'transactions',
      'transaction_entries'
  )
ORDER BY t.name;
GO

USE FinFlowDB;
GO

SELECT
    CHANGE_TRACKING_CURRENT_VERSION() AS current_tracking_version,
    CHANGE_TRACKING_MIN_VALID_VERSION(
        OBJECT_ID('dbo.branches')
    ) AS minimum_valid_version;
GO

USE FinFlowDB;
GO

-- Step 1: Capture the baseline version
DECLARE @LastSyncVersion BIGINT;

SET @LastSyncVersion = CHANGE_TRACKING_CURRENT_VERSION();

SELECT @LastSyncVersion AS baseline_version;


-- Step 2: Update one source record
UPDATE dbo.branches
SET branch_name = 'Test Branch CT Demo'
WHERE branch_code = 'BR009';


-- Step 3: Capture the new version
SELECT
    CHANGE_TRACKING_CURRENT_VERSION() AS current_version;


-- Step 4: Retrieve only changed branch records
SELECT
    CT.SYS_CHANGE_OPERATION AS change_operation,
    CT.SYS_CHANGE_VERSION AS change_version,
    B.branch_id,
    B.branch_code,
    B.branch_name,
    B.city,
    B.state
FROM CHANGETABLE(
    CHANGES dbo.branches,
    @LastSyncVersion
) AS CT
JOIN dbo.branches AS B
    ON B.branch_id = CT.branch_id;
GO