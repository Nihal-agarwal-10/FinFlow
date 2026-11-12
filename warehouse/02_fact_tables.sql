
USE FinFlowDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Prevent accidental duplicate creation
    IF OBJECT_ID('warehouse.FactTransactions', 'U') IS NOT NULL
       OR OBJECT_ID('warehouse.FactLedgerEntries', 'U') IS NOT NULL
    BEGIN
        THROW 50004,
        'Fact tables already exist. Review before rerunning.',
        1;
    END;

    -- 1. Transaction fact table
    CREATE TABLE warehouse.FactTransactions (
        transaction_key BIGINT IDENTITY(1,1) PRIMARY KEY,
        transaction_id BIGINT NOT NULL UNIQUE,

        date_key INT NOT NULL,
        customer_key INT NOT NULL,
        merchant_key INT NULL,

        debit_account_key INT NOT NULL,
        credit_account_key INT NOT NULL,

        transaction_type_key INT NOT NULL,
        transaction_status_key INT NOT NULL,
        channel_key INT NOT NULL,

        transaction_amount DECIMAL(19,4) NOT NULL,
        currency_code CHAR(3) NOT NULL,

        CONSTRAINT FK_FactTransactions_Date
            FOREIGN KEY (date_key)
            REFERENCES warehouse.DimDate(date_key),

        CONSTRAINT FK_FactTransactions_Customer
            FOREIGN KEY (customer_key)
            REFERENCES warehouse.DimCustomer(customer_key),

        CONSTRAINT FK_FactTransactions_Merchant
            FOREIGN KEY (merchant_key)
            REFERENCES warehouse.DimMerchant(merchant_key),

        CONSTRAINT FK_FactTransactions_DebitAccount
            FOREIGN KEY (debit_account_key)
            REFERENCES warehouse.DimAccount(account_key),

        CONSTRAINT FK_FactTransactions_CreditAccount
            FOREIGN KEY (credit_account_key)
            REFERENCES warehouse.DimAccount(account_key),

        CONSTRAINT FK_FactTransactions_Type
            FOREIGN KEY (transaction_type_key)
            REFERENCES warehouse.DimTransactionType(transaction_type_key),

        CONSTRAINT FK_FactTransactions_Status
            FOREIGN KEY (transaction_status_key)
            REFERENCES warehouse.DimTransactionStatus(transaction_status_key),

        CONSTRAINT FK_FactTransactions_Channel
            FOREIGN KEY (channel_key)
            REFERENCES warehouse.DimChannel(channel_key),

        CONSTRAINT CK_FactTransactions_Amount
            CHECK (transaction_amount > 0)
    );

    -- 2. Ledger entry fact table
    CREATE TABLE warehouse.FactLedgerEntries (
        ledger_fact_key BIGINT IDENTITY(1,1) PRIMARY KEY,
        entry_id BIGINT NOT NULL UNIQUE,
        transaction_id BIGINT NOT NULL,

        date_key INT NOT NULL,
        account_key INT NOT NULL,

        entry_type VARCHAR(10) NOT NULL,
        entry_amount DECIMAL(19,4) NOT NULL,

        CONSTRAINT FK_FactLedgerEntries_Date
            FOREIGN KEY (date_key)
            REFERENCES warehouse.DimDate(date_key),

        CONSTRAINT FK_FactLedgerEntries_Account
            FOREIGN KEY (account_key)
            REFERENCES warehouse.DimAccount(account_key),

        CONSTRAINT CK_FactLedgerEntries_Type
            CHECK (entry_type IN ('DEBIT', 'CREDIT')),

        CONSTRAINT CK_FactLedgerEntries_Amount
            CHECK (entry_amount > 0)
    );

    COMMIT TRANSACTION;

    PRINT 'Both fact tables created successfully.';

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO


-- 3. Populate FactTransactions
-- Each transaction must have one debit and one credit entry.

;WITH TransactionAccounts AS (
    SELECT
        transaction_id,
        MAX(CASE WHEN entry_type = 'DEBIT'
                 THEN account_id END) AS debit_account_id,
        MAX(CASE WHEN entry_type = 'CREDIT'
                 THEN account_id END) AS credit_account_id,
        COUNT(*) AS entry_count,
        SUM(CASE WHEN entry_type = 'DEBIT' THEN 1 ELSE 0 END)
            AS debit_count,
        SUM(CASE WHEN entry_type = 'CREDIT' THEN 1 ELSE 0 END)
            AS credit_count
    FROM clean.TransactionEntries
    GROUP BY transaction_id
)
INSERT INTO warehouse.FactTransactions (
    transaction_id,
    date_key,
    customer_key,
    merchant_key,
    debit_account_key,
    credit_account_key,
    transaction_type_key,
    transaction_status_key,
    channel_key,
    transaction_amount,
    currency_code
)
SELECT
    t.transaction_id,
    CONVERT(INT, CONVERT(CHAR(8), CAST(t.occurred_at AS DATE), 112)),
    dc.customer_key,
    dm.merchant_key,
    da_debit.account_key,
    da_credit.account_key,
    dtt.transaction_type_key,
    dts.transaction_status_key,
    dch.channel_key,
    t.transaction_amount,
    t.currency_code
FROM clean.Transactions t
JOIN TransactionAccounts ta
    ON t.transaction_id = ta.transaction_id
JOIN clean.Accounts ca_debit
    ON ta.debit_account_id = ca_debit.account_id
JOIN clean.Accounts ca_credit
    ON ta.credit_account_id = ca_credit.account_id
JOIN warehouse.DimAccount da_debit
    ON ca_debit.account_id = da_debit.account_id
JOIN warehouse.DimAccount da_credit
    ON ca_credit.account_id = da_credit.account_id
JOIN warehouse.DimCustomer dc
    ON ca_debit.customer_id = dc.customer_id
LEFT JOIN warehouse.DimMerchant dm
    ON t.merchant_id = dm.merchant_id
JOIN warehouse.DimTransactionType dtt
    ON t.transaction_type = dtt.transaction_type
JOIN warehouse.DimTransactionStatus dts
    ON t.transaction_status = dts.transaction_status
JOIN warehouse.DimChannel dch
    ON t.transaction_channel = dch.transaction_channel
WHERE ta.entry_count = 2
  AND ta.debit_count = 1
  AND ta.credit_count = 1;


-- 4. Populate FactLedgerEntries
INSERT INTO warehouse.FactLedgerEntries (
    entry_id,
    transaction_id,
    date_key,
    account_key,
    entry_type,
    entry_amount
)
SELECT
    e.entry_id,
    e.transaction_id,
    CONVERT(INT, CONVERT(CHAR(8), CAST(t.occurred_at AS DATE), 112)),
    da.account_key,
    e.entry_type,
    e.entry_amount
FROM clean.TransactionEntries e
JOIN clean.Transactions t
    ON e.transaction_id = t.transaction_id
JOIN warehouse.DimAccount da
    ON e.account_id = da.account_id;


-- 5. Verify fact table counts
SELECT
    'FactTransactions' AS FactTable,
    COUNT(*) AS TotalRows
FROM warehouse.FactTransactions

UNION ALL

SELECT
    'FactLedgerEntries',
    COUNT(*)
FROM warehouse.FactLedgerEntries;
GO

USE FinFlowDB;
GO

SELECT
    'FactTransactions' AS TableName,
    COUNT(*) AS TotalRows
FROM warehouse.FactTransactions

UNION ALL

SELECT
    'FactLedgerEntries',
    COUNT(*)
FROM warehouse.FactLedgerEntries;
GO