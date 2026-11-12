
USE FinFlowDB;
GO

-- Create staging schema
IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'stg'
)
    EXEC('CREATE SCHEMA stg');
GO

-- 1. Branches
CREATE TABLE stg.Branches (
    branch_id NVARCHAR(50),
    branch_code NVARCHAR(100),
    branch_name NVARCHAR(200),
    city NVARCHAR(150),
    state NVARCHAR(150),
    loaded_at DATETIME2 DEFAULT SYSUTCDATETIME()
);
GO

-- 2. Customers
CREATE TABLE stg.Customers (
    customer_id NVARCHAR(50),
    customer_ref NVARCHAR(100),
    first_name NVARCHAR(150),
    last_name NVARCHAR(150),
    email NVARCHAR(250),
    phone NVARCHAR(50),
    date_of_birth NVARCHAR(50),
    customer_status NVARCHAR(50),
    loaded_at DATETIME2 DEFAULT SYSUTCDATETIME()
);
GO

-- 3. Merchants
CREATE TABLE stg.Merchants (
    merchant_id NVARCHAR(50),
    merchant_code NVARCHAR(100),
    merchant_name NVARCHAR(200),
    merchant_category NVARCHAR(100),
    city NVARCHAR(150),
    country NVARCHAR(100),
    loaded_at DATETIME2 DEFAULT SYSUTCDATETIME()
);
GO

-- 4. Accounts
CREATE TABLE stg.Accounts (
    account_id NVARCHAR(50),
    account_number NVARCHAR(100),
    customer_id NVARCHAR(50),
    branch_id NVARCHAR(50),
    account_type NVARCHAR(50),
    account_status NVARCHAR(50),
    currency_code NVARCHAR(20),
    current_balance NVARCHAR(100),
    opened_at NVARCHAR(50),
    modified_at NVARCHAR(50),
    loaded_at DATETIME2 DEFAULT SYSUTCDATETIME()
);
GO

-- 5. Transactions
CREATE TABLE stg.Transactions (
    transaction_id NVARCHAR(50),
    transaction_ref NVARCHAR(100),
    merchant_id NVARCHAR(50),
    transaction_type NVARCHAR(50),
    transaction_status NVARCHAR(50),
    transaction_amount NVARCHAR(100),
    currency_code NVARCHAR(20),
    transaction_channel NVARCHAR(50),
    occurred_at NVARCHAR(50),
    created_at NVARCHAR(50),
    loaded_at DATETIME2 DEFAULT SYSUTCDATETIME()
);
GO

-- 6. Transaction Entries
CREATE TABLE stg.TransactionEntries (
    entry_id NVARCHAR(50),
    transaction_id NVARCHAR(50),
    account_id NVARCHAR(50),
    entry_type NVARCHAR(50),
    entry_amount NVARCHAR(100),
    entry_timestamp NVARCHAR(50),
    loaded_at DATETIME2 DEFAULT SYSUTCDATETIME()
);
GO
