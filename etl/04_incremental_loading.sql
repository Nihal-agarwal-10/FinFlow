
USE FinFlowDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE
        @BranchesInserted INT = 0,
        @BranchesUpdated INT = 0,
        @CustomersInserted INT = 0,
        @CustomersUpdated INT = 0,
        @MerchantsInserted INT = 0,
        @MerchantsUpdated INT = 0,
        @AccountsInserted INT = 0,
        @AccountsUpdated INT = 0,
        @TransactionsInserted INT = 0,
        @TransactionsUpdated INT = 0,
        @EntriesInserted INT = 0,
        @EntriesUpdated INT = 0;

    /* =========================================
       1. BRANCHES
       ========================================= */

    UPDATE s
    SET
        s.branch_code = b.branch_code,
        s.branch_name = b.branch_name,
        s.city = b.city,
        s.state = b.state
    FROM stg.Branches s
    JOIN dbo.branches b
        ON TRY_CONVERT(INT, s.branch_id) = b.branch_id
    WHERE
        ISNULL(s.branch_code, '') <> ISNULL(b.branch_code, '')
        OR ISNULL(s.branch_name, '') <> ISNULL(b.branch_name, '')
        OR ISNULL(s.city, '') <> ISNULL(b.city, '')
        OR ISNULL(s.state, '') <> ISNULL(b.state, '');

    SET @BranchesUpdated = @@ROWCOUNT;

    INSERT INTO stg.Branches
        (branch_id, branch_code, branch_name, city, state)
    SELECT
        b.branch_id, b.branch_code, b.branch_name, b.city, b.state
    FROM dbo.branches b
    WHERE NOT EXISTS (
        SELECT 1
        FROM stg.Branches s
        WHERE TRY_CONVERT(INT, s.branch_id) = b.branch_id
    );

    SET @BranchesInserted = @@ROWCOUNT;


    /* =========================================
       2. CUSTOMERS
       ========================================= */

    UPDATE s
    SET
        s.customer_ref = c.customer_ref,
        s.first_name = c.first_name,
        s.last_name = c.last_name,
        s.email = c.email,
        s.phone = c.phone,
        s.date_of_birth = c.date_of_birth,
        s.customer_status = c.customer_status
    FROM stg.Customers s
    JOIN dbo.customers c
        ON TRY_CONVERT(BIGINT, s.customer_id) = c.customer_id
    WHERE
        ISNULL(s.customer_ref, '') <> ISNULL(c.customer_ref, '')
        OR ISNULL(s.first_name, '') <> ISNULL(c.first_name, '')
        OR ISNULL(s.last_name, '') <> ISNULL(c.last_name, '')
        OR ISNULL(s.email, '') <> ISNULL(c.email, '')
        OR ISNULL(s.phone, '') <> ISNULL(c.phone, '')
        OR ISNULL(s.date_of_birth, '') <> ISNULL(CONVERT(NVARCHAR(30), c.date_of_birth, 23), '')
        OR ISNULL(s.customer_status, '') <> ISNULL(c.customer_status, '');

    SET @CustomersUpdated = @@ROWCOUNT;

    INSERT INTO stg.Customers
        (customer_id, customer_ref, first_name, last_name,
         email, phone, date_of_birth, customer_status)
    SELECT
        c.customer_id, c.customer_ref, c.first_name, c.last_name,
        c.email, c.phone, c.date_of_birth, c.customer_status
    FROM dbo.customers c
    WHERE NOT EXISTS (
        SELECT 1
        FROM stg.Customers s
        WHERE TRY_CONVERT(BIGINT, s.customer_id) = c.customer_id
    );

    SET @CustomersInserted = @@ROWCOUNT;


    /* =========================================
       3. MERCHANTS
       ========================================= */

    UPDATE s
    SET
        s.merchant_code = m.merchant_code,
        s.merchant_name = m.merchant_name,
        s.merchant_category = m.merchant_category,
        s.city = m.city,
        s.country = m.country
    FROM stg.Merchants s
    JOIN dbo.merchants m
        ON TRY_CONVERT(INT, s.merchant_id) = m.merchant_id
    WHERE
        ISNULL(s.merchant_code, '') <> ISNULL(m.merchant_code, '')
        OR ISNULL(s.merchant_name, '') <> ISNULL(m.merchant_name, '')
        OR ISNULL(s.merchant_category, '') <> ISNULL(m.merchant_category, '')
        OR ISNULL(s.city, '') <> ISNULL(m.city, '')
        OR ISNULL(s.country, '') <> ISNULL(m.country, '');

    SET @MerchantsUpdated = @@ROWCOUNT;

    INSERT INTO stg.Merchants
        (merchant_id, merchant_code, merchant_name,
         merchant_category, city, country)
    SELECT
        m.merchant_id, m.merchant_code, m.merchant_name,
        m.merchant_category, m.city, m.country
    FROM dbo.merchants m
    WHERE NOT EXISTS (
        SELECT 1
        FROM stg.Merchants s
        WHERE TRY_CONVERT(INT, s.merchant_id) = m.merchant_id
    );

    SET @MerchantsInserted = @@ROWCOUNT;


    /* =========================================
       4. ACCOUNTS
       ========================================= */

    UPDATE s
    SET
        s.account_number = a.account_number,
        s.customer_id = a.customer_id,
        s.branch_id = a.branch_id,
        s.account_type = a.account_type,
        s.account_status = a.account_status,
        s.currency_code = a.currency_code,
        s.current_balance = a.current_balance,
        s.opened_at = a.opened_at,
        s.modified_at = a.modified_at
    FROM stg.Accounts s
    JOIN dbo.accounts a
        ON TRY_CONVERT(BIGINT, s.account_id) = a.account_id
    WHERE
        ISNULL(s.account_number, '') <> ISNULL(a.account_number, '')
        OR TRY_CONVERT(BIGINT, s.customer_id) <> a.customer_id
        OR TRY_CONVERT(INT, s.branch_id) <> a.branch_id
        OR ISNULL(s.account_type, '') <> ISNULL(a.account_type, '')
        OR ISNULL(s.account_status, '') <> ISNULL(a.account_status, '')
        OR ISNULL(s.currency_code, '') <> ISNULL(a.currency_code, '')
        OR TRY_CONVERT(DECIMAL(19,4), s.current_balance) <> a.current_balance
        OR TRY_CONVERT(DATETIME2(0), s.modified_at) <> a.modified_at;

    SET @AccountsUpdated = @@ROWCOUNT;

    INSERT INTO stg.Accounts
        (account_id, account_number, customer_id, branch_id,
         account_type, account_status, currency_code,
         current_balance, opened_at, modified_at)
    SELECT
        a.account_id, a.account_number, a.customer_id, a.branch_id,
        a.account_type, a.account_status, a.currency_code,
        a.current_balance, a.opened_at, a.modified_at
    FROM dbo.accounts a
    WHERE NOT EXISTS (
        SELECT 1
        FROM stg.Accounts s
        WHERE TRY_CONVERT(BIGINT, s.account_id) = a.account_id
    );

    SET @AccountsInserted = @@ROWCOUNT;


    /* =========================================
       5. TRANSACTIONS
       ========================================= */

    UPDATE s
    SET
        s.transaction_ref = t.transaction_ref,
        s.merchant_id = t.merchant_id,
        s.transaction_type = t.transaction_type,
        s.transaction_status = t.transaction_status,
        s.transaction_amount = t.transaction_amount,
        s.currency_code = t.currency_code,
        s.transaction_channel = t.transaction_channel,
        s.occurred_at = t.occurred_at,
        s.created_at = t.created_at
    FROM stg.Transactions s
    JOIN dbo.transactions t
        ON TRY_CONVERT(BIGINT, s.transaction_id) = t.transaction_id
    WHERE
        ISNULL(s.transaction_ref, '') <> ISNULL(t.transaction_ref, '')
        OR TRY_CONVERT(INT, s.merchant_id) <> t.merchant_id
        OR ISNULL(s.transaction_type, '') <> ISNULL(t.transaction_type, '')
        OR ISNULL(s.transaction_status, '') <> ISNULL(t.transaction_status, '')
        OR TRY_CONVERT(DECIMAL(19,4), s.transaction_amount) <> t.transaction_amount
        OR ISNULL(s.currency_code, '') <> ISNULL(t.currency_code, '')
        OR ISNULL(s.transaction_channel, '') <> ISNULL(t.transaction_channel, '')
        OR TRY_CONVERT(DATETIME2(0), s.occurred_at) <> t.occurred_at;

    SET @TransactionsUpdated = @@ROWCOUNT;

    INSERT INTO stg.Transactions
        (transaction_id, transaction_ref, merchant_id,
         transaction_type, transaction_status, transaction_amount,
         currency_code, transaction_channel, occurred_at, created_at)
    SELECT
        t.transaction_id, t.transaction_ref, t.merchant_id,
        t.transaction_type, t.transaction_status, t.transaction_amount,
        t.currency_code, t.transaction_channel,
        t.occurred_at, t.created_at
    FROM dbo.transactions t
    WHERE NOT EXISTS (
        SELECT 1
        FROM stg.Transactions s
        WHERE TRY_CONVERT(BIGINT, s.transaction_id) = t.transaction_id
    );

    SET @TransactionsInserted = @@ROWCOUNT;


    /* =========================================
       6. TRANSACTION ENTRIES
       ========================================= */

    UPDATE s
    SET
        s.transaction_id = e.transaction_id,
        s.account_id = e.account_id,
        s.entry_type = e.entry_type,
        s.entry_amount = e.entry_amount,
        s.entry_timestamp = e.entry_timestamp
    FROM stg.TransactionEntries s
    JOIN dbo.transaction_entries e
        ON TRY_CONVERT(BIGINT, s.entry_id) = e.entry_id
    WHERE
        TRY_CONVERT(BIGINT, s.transaction_id) <> e.transaction_id
        OR TRY_CONVERT(BIGINT, s.account_id) <> e.account_id
        OR ISNULL(s.entry_type, '') <> ISNULL(e.entry_type, '')
        OR TRY_CONVERT(DECIMAL(19,4), s.entry_amount) <> e.entry_amount
        OR TRY_CONVERT(DATETIME2(0), s.entry_timestamp) <> e.entry_timestamp;

    SET @EntriesUpdated = @@ROWCOUNT;

    INSERT INTO stg.TransactionEntries
        (entry_id, transaction_id, account_id,
         entry_type, entry_amount, entry_timestamp)
    SELECT
        e.entry_id, e.transaction_id, e.account_id,
        e.entry_type, e.entry_amount, e.entry_timestamp
    FROM dbo.transaction_entries e
    WHERE NOT EXISTS (
        SELECT 1
        FROM stg.TransactionEntries s
        WHERE TRY_CONVERT(BIGINT, s.entry_id) = e.entry_id
    );

    SET @EntriesInserted = @@ROWCOUNT;


    /* =========================================
       COMMIT AND SUMMARY
       ========================================= */

    COMMIT TRANSACTION;

    SELECT
        table_name,
        inserted_records,
        updated_records
    FROM
    (
        SELECT 'Branches' AS table_name,
               @BranchesInserted AS inserted_records,
               @BranchesUpdated AS updated_records
        UNION ALL
        SELECT 'Customers', @CustomersInserted, @CustomersUpdated
        UNION ALL
        SELECT 'Merchants', @MerchantsInserted, @MerchantsUpdated
        UNION ALL
        SELECT 'Accounts', @AccountsInserted, @AccountsUpdated
        UNION ALL
        SELECT 'Transactions', @TransactionsInserted, @TransactionsUpdated
        UNION ALL
        SELECT 'Transaction Entries', @EntriesInserted, @EntriesUpdated
    ) AS LoadSummary;

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

SELECT
    branch_id,
    branch_code,
    branch_name,
    city,
    state
FROM stg.Branches
WHERE branch_code = 'BR009';
GO