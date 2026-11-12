
USE FinFlowDB;
GO

/* =========================================================
   FINFLOW - OPERATIONAL DATABASE CHECK CONSTRAINTS
   =========================================================

   These constraints enforce valid business rules at
   the database level.

   Existing constraints are checked before creation,
   making this script safe to execute repeatedly.
   ========================================================= */


/* =========================================================
   1. ACCOUNT CONSTRAINTS
   ========================================================= */

-- Account balance cannot be negative.

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_accounts_balance'
      AND parent_object_id = OBJECT_ID('dbo.accounts')
)
BEGIN
    ALTER TABLE dbo.accounts
    WITH CHECK ADD CONSTRAINT CK_accounts_balance
    CHECK (current_balance >= 0);
END;
GO


-- Valid account statuses.

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_accounts_status'
      AND parent_object_id = OBJECT_ID('dbo.accounts')
)
BEGIN
    ALTER TABLE dbo.accounts
    WITH CHECK ADD CONSTRAINT CK_accounts_status
    CHECK (
        account_status IN
        ('ACTIVE', 'INACTIVE', 'FROZEN', 'CLOSED')
    );
END;
GO


-- Valid account types.

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_accounts_type'
      AND parent_object_id = OBJECT_ID('dbo.accounts')
)
BEGIN
    ALTER TABLE dbo.accounts
    WITH CHECK ADD CONSTRAINT CK_accounts_type
    CHECK (
        account_type IN
        ('SAVINGS', 'CURRENT', 'SALARY')
    );
END;
GO


/* =========================================================
   2. CUSTOMER CONSTRAINTS
   ========================================================= */

-- Date of birth cannot be in the future.

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_customers_dob'
      AND parent_object_id = OBJECT_ID('dbo.customers')
)
BEGIN
    ALTER TABLE dbo.customers
    WITH CHECK ADD CONSTRAINT CK_customers_dob
    CHECK (
        date_of_birth IS NULL
        OR date_of_birth <= CONVERT(DATE, GETDATE())
    );
END;
GO


-- Valid customer statuses.

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_customers_status'
      AND parent_object_id = OBJECT_ID('dbo.customers')
)
BEGIN
    ALTER TABLE dbo.customers
    WITH CHECK ADD CONSTRAINT CK_customers_status
    CHECK (
        customer_status IN
        ('ACTIVE', 'INACTIVE', 'SUSPENDED')
    );
END;
GO


/* =========================================================
   3. TRANSACTION ENTRY CONSTRAINTS
   ========================================================= */

-- Ledger entry amount must be positive.

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_entries_amount'
      AND parent_object_id =
          OBJECT_ID('dbo.transaction_entries')
)
BEGIN
    ALTER TABLE dbo.transaction_entries
    WITH CHECK ADD CONSTRAINT CK_entries_amount
    CHECK (entry_amount > 0);
END;
GO


-- Valid ledger entry types.

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_entries_type'
      AND parent_object_id =
          OBJECT_ID('dbo.transaction_entries')
)
BEGIN
    ALTER TABLE dbo.transaction_entries
    WITH CHECK ADD CONSTRAINT CK_entries_type
    CHECK (entry_type IN ('DEBIT', 'CREDIT'));
END;
GO


/* =========================================================
   4. TRANSACTION CONSTRAINTS
   ========================================================= */

-- Transaction amount must be positive.

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_transactions_amount'
      AND parent_object_id = OBJECT_ID('dbo.transactions')
)
BEGIN
    ALTER TABLE dbo.transactions
    WITH CHECK ADD CONSTRAINT CK_transactions_amount
    CHECK (transaction_amount > 0);
END;
GO


-- Valid transaction channels.

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_transactions_channel'
      AND parent_object_id = OBJECT_ID('dbo.transactions')
)
BEGIN
    ALTER TABLE dbo.transactions
    WITH CHECK ADD CONSTRAINT CK_transactions_channel
    CHECK (
        transaction_channel IN
        ('UPI', 'CARD', 'NEFT', 'IMPS', 'RTGS', 'ATM', 'BRANCH')
    );
END;
GO


-- Valid transaction statuses.

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_transactions_status'
      AND parent_object_id = OBJECT_ID('dbo.transactions')
)
BEGIN
    ALTER TABLE dbo.transactions
    WITH CHECK ADD CONSTRAINT CK_transactions_status
    CHECK (
        transaction_status IN
        ('PENDING', 'COMPLETED', 'FAILED', 'REVERSED')
    );
END;
GO


-- Valid transaction types.

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_transactions_type'
      AND parent_object_id = OBJECT_ID('dbo.transactions')
)
BEGIN
    ALTER TABLE dbo.transactions
    WITH CHECK ADD CONSTRAINT CK_transactions_type
    CHECK (
        transaction_type IN
        ('TRANSFER', 'WITHDRAWAL', 'DEPOSIT', 'PAYMENT')
    );
END;
GO


/* =========================================================
   5. VERIFY OPERATIONAL CHECK CONSTRAINTS
   ========================================================= */

SELECT
    OBJECT_NAME(parent_object_id) AS table_name,
    name AS constraint_name,
    definition,
    is_disabled,
    is_not_trusted
FROM sys.check_constraints
WHERE parent_object_id IN
(
    OBJECT_ID('dbo.accounts'),
    OBJECT_ID('dbo.customers'),
    OBJECT_ID('dbo.transactions'),
    OBJECT_ID('dbo.transaction_entries')
)
ORDER BY table_name, constraint_name;
GO
