
USE FinFlowDB;
GO

-- =============================================
-- PART 1: REMOVE UNIQUE CONSTRAINT ON CUSTOMER_ID
-- =============================================

DECLARE @ConstraintName SYSNAME;
DECLARE @SQL NVARCHAR(MAX);

SELECT @ConstraintName = kc.name
FROM sys.key_constraints kc
JOIN sys.index_columns ic
    ON kc.parent_object_id = ic.object_id
   AND kc.unique_index_id = ic.index_id
JOIN sys.columns c
    ON ic.object_id = c.object_id
   AND ic.column_id = c.column_id
WHERE kc.parent_object_id = OBJECT_ID('warehouse.DimCustomer')
  AND kc.type = 'UQ'
  AND c.name = 'customer_id';

IF @ConstraintName IS NOT NULL
BEGIN
    SET @SQL =
        N'ALTER TABLE warehouse.DimCustomer DROP CONSTRAINT '
        + QUOTENAME(@ConstraintName);

    EXEC sp_executesql @SQL;
END;
GO


-- =============================================
-- PART 2: ADD SCD TYPE 2 COLUMNS
-- =============================================

IF COL_LENGTH('warehouse.DimCustomer', 'effective_from') IS NULL
BEGIN
    ALTER TABLE warehouse.DimCustomer
    ADD effective_from DATETIME2(0) NOT NULL
        CONSTRAINT DF_DimCustomer_EffectiveFrom
        DEFAULT SYSUTCDATETIME() WITH VALUES;
END;

IF COL_LENGTH('warehouse.DimCustomer', 'effective_to') IS NULL
BEGIN
    ALTER TABLE warehouse.DimCustomer
    ADD effective_to DATETIME2(0) NOT NULL
        CONSTRAINT DF_DimCustomer_EffectiveTo
        DEFAULT ('9999-12-31 23:59:59') WITH VALUES;
END;

IF COL_LENGTH('warehouse.DimCustomer', 'is_current') IS NULL
BEGIN
    ALTER TABLE warehouse.DimCustomer
    ADD is_current BIT NOT NULL
        CONSTRAINT DF_DimCustomer_IsCurrent
        DEFAULT 1 WITH VALUES;
END;

IF COL_LENGTH('warehouse.DimCustomer', 'version_number') IS NULL
BEGIN
    ALTER TABLE warehouse.DimCustomer
    ADD version_number INT NOT NULL
        CONSTRAINT DF_DimCustomer_Version
        DEFAULT 1 WITH VALUES;
END;
GO


-- =============================================
-- PART 3: CREATE FILTERED UNIQUE INDEX
-- =============================================

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('warehouse.DimCustomer')
      AND name = 'UX_DimCustomer_Current'
)
BEGIN
    CREATE UNIQUE INDEX UX_DimCustomer_Current
    ON warehouse.DimCustomer(customer_id)
    WHERE is_current = 1;
END;
GO


-- =============================================
-- PART 4: CREATE SCD TYPE 2 PROCEDURE
-- =============================================

CREATE OR ALTER PROCEDURE warehouse.usp_LoadDimCustomer_SCD2
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @LoadTime DATETIME2(0) = SYSUTCDATETIME();

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Expire records whose attributes changed
        UPDATE target
        SET
            target.effective_to = @LoadTime,
            target.is_current = 0
        FROM warehouse.DimCustomer target
        INNER JOIN clean.Customers source
            ON target.customer_id = source.customer_id
        WHERE target.is_current = 1
          AND (
              ISNULL(target.customer_ref, '') <>
                  ISNULL(source.customer_ref, '')
              OR ISNULL(target.full_name, '') <>
                  ISNULL(CONCAT(source.first_name, ' ', source.last_name), '')
              OR ISNULL(target.email, '') <>
                  ISNULL(source.email, '')
              OR ISNULL(target.customer_status, '') <>
                  ISNULL(source.customer_status, '')
          );

        -- Insert new customers or changed customer versions
        INSERT INTO warehouse.DimCustomer (
            customer_id,
            customer_ref,
            full_name,
            email,
            customer_status,
            effective_from,
            effective_to,
            is_current,
            version_number
        )
        SELECT
            source.customer_id,
            source.customer_ref,
            CONCAT(source.first_name, ' ', source.last_name),
            source.email,
            source.customer_status,
            @LoadTime,
            '9999-12-31 23:59:59',
            1,
            ISNULL((
                SELECT MAX(old.version_number)
                FROM warehouse.DimCustomer old
                WHERE old.customer_id = source.customer_id
            ), 0) + 1
        FROM clean.Customers source
        WHERE NOT EXISTS (
            SELECT 1
            FROM warehouse.DimCustomer current_row
            WHERE current_row.customer_id = source.customer_id
              AND current_row.is_current = 1
        );

        COMMIT TRANSACTION;

        PRINT 'SCD Type 2 load completed successfully.';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO


-- =============================================
-- PART 5: INITIAL SCD LOAD
-- =============================================

EXEC warehouse.usp_LoadDimCustomer_SCD2;
GO


-- =============================================
-- PART 6: VERIFY CUSTOMER HISTORY
-- =============================================

SELECT
    customer_id,
    customer_ref,
    full_name,
    email,
    customer_status,
    version_number,
    effective_from,
    effective_to,
    is_current
FROM warehouse.DimCustomer
ORDER BY customer_id, version_number;

SELECT
    COUNT(*) AS total_customer_versions,
    COUNT(DISTINCT customer_id) AS unique_customers,
    SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END)
        AS current_records,
    SUM(CASE WHEN is_current = 0 THEN 1 ELSE 0 END)
        AS historical_records
FROM warehouse.DimCustomer;
GO

USE FinFlowDB;
GO

-- Step 1: Change one customer's email in the clean source
UPDATE clean.Customers
SET email = 'customer1_updated@finflow.demo'
WHERE customer_id = 1;

-- Step 2: Run the SCD Type 2 procedure
EXEC warehouse.usp_LoadDimCustomer_SCD2;
GO

-- Step 3: Inspect the customer's history
SELECT
    customer_id,
    full_name,
    email,
    version_number,
    effective_from,
    effective_to,
    is_current
FROM warehouse.DimCustomer
WHERE customer_id = 1
ORDER BY version_number;
GO