
/*
=========================================================
PROJECT      : FinFlow
MODULE       : Database Schema Creation
DATABASE     : FinFlowDB
SQL ENGINE   : Microsoft SQL Server 2025
PURPOSE      : Create core transactional database tables
=========================================================
*/

USE FinFlowDB;
GO

/* 1. BRANCHES */

CREATE TABLE dbo.branches
(
    branch_id       INT IDENTITY(1,1) PRIMARY KEY,
    branch_code     VARCHAR(20) NOT NULL UNIQUE,
    branch_name     VARCHAR(100) NOT NULL,
    city            VARCHAR(80) NOT NULL,
    state           VARCHAR(80) NOT NULL,
    created_at      DATETIME2(0) NOT NULL
                    DEFAULT SYSUTCDATETIME()
);
GO

/* 2. CUSTOMERS */

CREATE TABLE dbo.customers
(
    customer_id     BIGINT IDENTITY(1,1) PRIMARY KEY,
    customer_ref    VARCHAR(30) NOT NULL UNIQUE,
    first_name      VARCHAR(60) NOT NULL,
    last_name       VARCHAR(60) NOT NULL,
    email           VARCHAR(150) NOT NULL UNIQUE,
    phone           VARCHAR(20) NOT NULL UNIQUE,
    date_of_birth   DATE NULL,
    customer_status VARCHAR(15) NOT NULL
                    DEFAULT 'ACTIVE',
    created_at      DATETIME2(0) NOT NULL
                    DEFAULT SYSUTCDATETIME(),

    CONSTRAINT CK_customers_status
        CHECK (customer_status IN
        ('ACTIVE', 'INACTIVE', 'SUSPENDED')),

    CONSTRAINT CK_customers_dob
        CHECK (date_of_birth IS NULL
               OR date_of_birth <= CAST(GETDATE() AS DATE))
);
GO

/* 3. MERCHANTS */

CREATE TABLE dbo.merchants
(
    merchant_id     INT IDENTITY(1,1) PRIMARY KEY,
    merchant_code   VARCHAR(30) NOT NULL UNIQUE,
    merchant_name   VARCHAR(120) NOT NULL,
    merchant_category VARCHAR(50) NOT NULL,
    city            VARCHAR(80) NULL,
    country         VARCHAR(80) NOT NULL DEFAULT 'India',
    created_at      DATETIME2(0) NOT NULL
                    DEFAULT SYSUTCDATETIME()
);
GO

/* 4. ACCOUNTS */

CREATE TABLE dbo.accounts
(
    account_id      BIGINT IDENTITY(1,1) PRIMARY KEY,
    account_number  VARCHAR(30) NOT NULL UNIQUE,
    customer_id     BIGINT NOT NULL,
    branch_id       INT NOT NULL,
    account_type    VARCHAR(20) NOT NULL,
    account_status  VARCHAR(15) NOT NULL DEFAULT 'ACTIVE',
    currency_code   CHAR(3) NOT NULL DEFAULT 'INR',
    current_balance DECIMAL(19,4) NOT NULL DEFAULT 0,
    opened_at       DATETIME2(0) NOT NULL
                    DEFAULT SYSUTCDATETIME(),
    modified_at     DATETIME2(0) NOT NULL
                    DEFAULT SYSUTCDATETIME(),
    row_version     ROWVERSION,

    CONSTRAINT FK_accounts_customers
        FOREIGN KEY (customer_id)
        REFERENCES dbo.customers(customer_id),

    CONSTRAINT FK_accounts_branches
        FOREIGN KEY (branch_id)
        REFERENCES dbo.branches(branch_id),

    CONSTRAINT CK_accounts_type
        CHECK (account_type IN
        ('SAVINGS', 'CURRENT', 'SALARY')),

    CONSTRAINT CK_accounts_status
        CHECK (account_status IN
        ('ACTIVE', 'INACTIVE', 'FROZEN', 'CLOSED')),

    CONSTRAINT CK_accounts_balance
        CHECK (current_balance >= 0)
);
GO

/* 5. TRANSACTIONS */

CREATE TABLE dbo.transactions
(
    transaction_id  BIGINT IDENTITY(1,1) PRIMARY KEY,
    transaction_ref VARCHAR(40) NOT NULL UNIQUE,
    merchant_id     INT NULL,
    transaction_type VARCHAR(20) NOT NULL,
    transaction_status VARCHAR(15) NOT NULL DEFAULT 'PENDING',
    transaction_amount DECIMAL(19,4) NOT NULL,
    currency_code   CHAR(3) NOT NULL DEFAULT 'INR',
    transaction_channel VARCHAR(20) NOT NULL,
    occurred_at     DATETIME2(0) NOT NULL,
    created_at      DATETIME2(0) NOT NULL
                    DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_transactions_merchants
        FOREIGN KEY (merchant_id)
        REFERENCES dbo.merchants(merchant_id),

    CONSTRAINT CK_transactions_type
        CHECK (transaction_type IN
        ('PAYMENT', 'DEPOSIT', 'WITHDRAWAL', 'TRANSFER')),

    CONSTRAINT CK_transactions_status
        CHECK (transaction_status IN
        ('PENDING', 'COMPLETED', 'FAILED', 'REVERSED')),

    CONSTRAINT CK_transactions_amount
        CHECK (transaction_amount > 0),

    CONSTRAINT CK_transactions_channel
        CHECK (transaction_channel IN
        ('UPI', 'CARD', 'NEFT', 'IMPS', 'RTGS', 'ATM', 'BRANCH'))
);
GO

/* 6. TRANSACTION ENTRIES */

CREATE TABLE dbo.transaction_entries
(
    entry_id        BIGINT IDENTITY(1,1) PRIMARY KEY,
    transaction_id  BIGINT NOT NULL,
    account_id      BIGINT NOT NULL,
    entry_type      VARCHAR(10) NOT NULL,
    entry_amount    DECIMAL(19,4) NOT NULL,
    entry_timestamp DATETIME2(0) NOT NULL
                    DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_entries_transactions
        FOREIGN KEY (transaction_id)
        REFERENCES dbo.transactions(transaction_id),

    CONSTRAINT FK_entries_accounts
        FOREIGN KEY (account_id)
        REFERENCES dbo.accounts(account_id),

    CONSTRAINT CK_entries_type
        CHECK (entry_type IN ('DEBIT', 'CREDIT')),

    CONSTRAINT CK_entries_amount
        CHECK (entry_amount > 0)
);
GO

PRINT 'All six FinFlow tables created successfully.';
GO
