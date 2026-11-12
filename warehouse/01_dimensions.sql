
USE FinFlowDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (
        SELECT 1 FROM sys.schemas WHERE name = 'warehouse'
    )
        EXEC('CREATE SCHEMA warehouse');

    -- Prevent accidental recreation
    IF OBJECT_ID('warehouse.DimDate', 'U') IS NOT NULL
       OR OBJECT_ID('warehouse.DimCustomer', 'U') IS NOT NULL
       OR OBJECT_ID('warehouse.DimBranch', 'U') IS NOT NULL
       OR OBJECT_ID('warehouse.DimMerchant', 'U') IS NOT NULL
       OR OBJECT_ID('warehouse.DimAccount', 'U') IS NOT NULL
       OR OBJECT_ID('warehouse.DimTransactionType', 'U') IS NOT NULL
       OR OBJECT_ID('warehouse.DimTransactionStatus', 'U') IS NOT NULL
       OR OBJECT_ID('warehouse.DimChannel', 'U') IS NOT NULL
    BEGIN
        THROW 50003,
        'Warehouse dimension tables already exist.',
        1;
    END;

    -- 1. Date dimension
    CREATE TABLE warehouse.DimDate (
        date_key INT PRIMARY KEY,
        full_date DATE NOT NULL UNIQUE,
        day_number TINYINT NOT NULL,
        month_number TINYINT NOT NULL,
        month_name VARCHAR(20) NOT NULL,
        quarter_number TINYINT NOT NULL,
        year_number SMALLINT NOT NULL,
        day_of_week VARCHAR(15) NOT NULL,
        is_weekend BIT NOT NULL
    );

    -- 2. Customer dimension
    CREATE TABLE warehouse.DimCustomer (
        customer_key INT IDENTITY(1,1) PRIMARY KEY,
        customer_id BIGINT NOT NULL UNIQUE,
        customer_ref VARCHAR(30) NOT NULL,
        full_name VARCHAR(130) NOT NULL,
        email VARCHAR(150),
        customer_status VARCHAR(15)
    );

    -- 3. Branch dimension
    CREATE TABLE warehouse.DimBranch (
        branch_key INT IDENTITY(1,1) PRIMARY KEY,
        branch_id INT NOT NULL UNIQUE,
        branch_code VARCHAR(20) NOT NULL,
        branch_name VARCHAR(100) NOT NULL,
        city VARCHAR(80),
        state VARCHAR(80)
    );

    -- 4. Merchant dimension
    CREATE TABLE warehouse.DimMerchant (
        merchant_key INT IDENTITY(1,1) PRIMARY KEY,
        merchant_id INT NOT NULL UNIQUE,
        merchant_code VARCHAR(30) NOT NULL,
        merchant_name VARCHAR(120) NOT NULL,
        merchant_category VARCHAR(50),
        city VARCHAR(80),
        country VARCHAR(80)
    );

    -- 5. Account dimension
    CREATE TABLE warehouse.DimAccount (
        account_key INT IDENTITY(1,1) PRIMARY KEY,
        account_id BIGINT NOT NULL UNIQUE,
        account_number VARCHAR(30) NOT NULL,
        customer_id BIGINT NOT NULL,
        branch_id INT NOT NULL,
        account_type VARCHAR(20),
        account_status VARCHAR(15),
        currency_code CHAR(3)
    );

    -- 6. Transaction type dimension
    CREATE TABLE warehouse.DimTransactionType (
        transaction_type_key INT IDENTITY(1,1) PRIMARY KEY,
        transaction_type VARCHAR(20) NOT NULL UNIQUE
    );

    -- 7. Transaction status dimension
    CREATE TABLE warehouse.DimTransactionStatus (
        transaction_status_key INT IDENTITY(1,1) PRIMARY KEY,
        transaction_status VARCHAR(15) NOT NULL UNIQUE
    );

    -- 8. Transaction channel dimension
    CREATE TABLE warehouse.DimChannel (
        channel_key INT IDENTITY(1,1) PRIMARY KEY,
        transaction_channel VARCHAR(20) NOT NULL UNIQUE
    );

    COMMIT TRANSACTION;

    PRINT 'All warehouse dimension tables created successfully.';

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO


USE FinFlowDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Date dimension: cover transaction dates
    DECLARE @StartDate DATE = (
        SELECT MIN(CAST(occurred_at AS DATE))
        FROM clean.Transactions
    );

    DECLARE @EndDate DATE = (
        SELECT MAX(CAST(occurred_at AS DATE))
        FROM clean.Transactions
    );

    ;WITH DateSeries AS (
        SELECT @StartDate AS CalendarDate
        UNION ALL
        SELECT DATEADD(DAY, 1, CalendarDate)
        FROM DateSeries
        WHERE CalendarDate < @EndDate
    )
    INSERT INTO warehouse.DimDate (
        date_key, full_date, day_number, month_number,
        month_name, quarter_number, year_number,
        day_of_week, is_weekend
    )
    SELECT
        CONVERT(INT, CONVERT(CHAR(8), CalendarDate, 112)),
        CalendarDate,
        DAY(CalendarDate),
        MONTH(CalendarDate),
        DATENAME(MONTH, CalendarDate),
        DATEPART(QUARTER, CalendarDate),
        YEAR(CalendarDate),
        DATENAME(WEEKDAY, CalendarDate),
        CASE WHEN DATEDIFF(DAY, '19000101', CalendarDate) % 7
                  IN (5, 6)
             THEN 1 ELSE 0 END
    FROM DateSeries
    OPTION (MAXRECURSION 0);

    -- Customer dimension
    INSERT INTO warehouse.DimCustomer (
        customer_id, customer_ref, full_name, email, customer_status
    )
    SELECT
        customer_id,
        customer_ref,
        CONCAT(first_name, ' ', last_name),
        email,
        customer_status
    FROM clean.Customers;

    -- Branch dimension
    INSERT INTO warehouse.DimBranch (
        branch_id, branch_code, branch_name, city, state
    )
    SELECT
        branch_id, branch_code, branch_name, city, state
    FROM clean.Branches;

    -- Merchant dimension
    INSERT INTO warehouse.DimMerchant (
        merchant_id, merchant_code, merchant_name,
        merchant_category, city, country
    )
    SELECT
        merchant_id, merchant_code, merchant_name,
        merchant_category, city, country
    FROM clean.Merchants;

    -- Account dimension
    INSERT INTO warehouse.DimAccount (
        account_id, account_number, customer_id, branch_id,
        account_type, account_status, currency_code
    )
    SELECT
        account_id, account_number, customer_id, branch_id,
        account_type, account_status, currency_code
    FROM clean.Accounts;

    -- Transaction type dimension
    INSERT INTO warehouse.DimTransactionType (transaction_type)
    SELECT DISTINCT transaction_type
    FROM clean.Transactions;

    -- Transaction status dimension
    INSERT INTO warehouse.DimTransactionStatus (transaction_status)
    SELECT DISTINCT transaction_status
    FROM clean.Transactions;

    -- Channel dimension
    INSERT INTO warehouse.DimChannel (transaction_channel)
    SELECT DISTINCT transaction_channel
    FROM clean.Transactions;

    COMMIT TRANSACTION;

    PRINT 'All dimension tables populated successfully.';

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

-- Verify dimension counts
SELECT 'DimDate' AS Dimension, COUNT(*) AS Total
FROM warehouse.DimDate
UNION ALL
SELECT 'DimCustomer', COUNT(*) FROM warehouse.DimCustomer
UNION ALL
SELECT 'DimBranch', COUNT(*) FROM warehouse.DimBranch
UNION ALL
SELECT 'DimMerchant', COUNT(*) FROM warehouse.DimMerchant
UNION ALL
SELECT 'DimAccount', COUNT(*) FROM warehouse.DimAccount
UNION ALL
SELECT 'DimTransactionType', COUNT(*) FROM warehouse.DimTransactionType
UNION ALL
SELECT 'DimTransactionStatus', COUNT(*) FROM warehouse.DimTransactionStatus
UNION ALL
SELECT 'DimChannel', COUNT(*) FROM warehouse.DimChannel;
GO
