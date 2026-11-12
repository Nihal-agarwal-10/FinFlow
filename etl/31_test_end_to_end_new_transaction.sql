
USE FinFlowDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* =========================================================
   FINFLOW END-TO-END INCREMENTAL LOAD TEST

   Test transaction:
   Amount: INR 100
   Type: TRANSFER
   Status: COMPLETED
   Channel: UPI

   Two accounts are selected automatically.
   ========================================================= */

DECLARE @DebitAccountID BIGINT;
DECLARE @CreditAccountID BIGINT;

DECLARE @TransactionID BIGINT;
DECLARE @TransactionRef VARCHAR(40);

DECLARE @Amount DECIMAL(19,4) = 100.0000;


/* =========================================================
   1. SELECT TWO ACTIVE ACCOUNTS
   ========================================================= */

DECLARE @SelectedAccounts TABLE
(
    selection_order INT IDENTITY(1,1),
    account_id BIGINT,
    account_number VARCHAR(30),
    current_balance DECIMAL(19,4)
);

BEGIN TRY

    BEGIN TRANSACTION;

    INSERT INTO @SelectedAccounts
    (
        account_id,
        account_number,
        current_balance
    )
    SELECT TOP (2)
        account_id,
        account_number,
        current_balance
    FROM dbo.accounts WITH (UPDLOCK, HOLDLOCK)
    WHERE account_status = 'ACTIVE'
      AND current_balance >= @Amount
    ORDER BY account_id;

    IF (SELECT COUNT(*) FROM @SelectedAccounts) <> 2
        THROW 50101,
            'Two eligible active accounts were not found.',
            1;

    SELECT
        @DebitAccountID = account_id
    FROM @SelectedAccounts
    WHERE selection_order = 1;

    SELECT
        @CreditAccountID = account_id
    FROM @SelectedAccounts
    WHERE selection_order = 2;


    /* =====================================================
       2. GENERATE UNIQUE TRANSACTION REFERENCE
       ===================================================== */

    SET @TransactionRef =
        CONCAT(
            'E2E-',
            REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', '')
        );


    /* =====================================================
       3. INSERT TRANSACTION
       ===================================================== */

    INSERT INTO dbo.transactions
    (
        transaction_ref,
        merchant_id,
        transaction_type,
        transaction_status,
        transaction_amount,
        currency_code,
        transaction_channel,
        occurred_at
    )
    VALUES
    (
        @TransactionRef,
        NULL,
        'TRANSFER',
        'COMPLETED',
        @Amount,
        'INR',
        'UPI',
        SYSUTCDATETIME()
    );

    SET @TransactionID =
        CONVERT(BIGINT, SCOPE_IDENTITY());


    /* =====================================================
       4. INSERT BALANCED LEDGER ENTRIES
       ===================================================== */

    INSERT INTO dbo.transaction_entries
    (
        transaction_id,
        account_id,
        entry_type,
        entry_amount
    )
    VALUES
    (
        @TransactionID,
        @DebitAccountID,
        'DEBIT',
        @Amount
    ),
    (
        @TransactionID,
        @CreditAccountID,
        'CREDIT',
        @Amount
    );


    /* =====================================================
       5. UPDATE ACCOUNT BALANCES
       ===================================================== */

    UPDATE dbo.accounts
    SET
        current_balance =
            CASE
                WHEN account_id = @DebitAccountID
                    THEN current_balance - @Amount

                WHEN account_id = @CreditAccountID
                    THEN current_balance + @Amount
            END,
        modified_at = SYSUTCDATETIME()
    WHERE account_id IN
    (
        @DebitAccountID,
        @CreditAccountID
    );

    IF @@ROWCOUNT <> 2
        THROW 50102,
            'Account balance update failed.',
            1;


    COMMIT TRANSACTION;


    /* =====================================================
       6. RETURN TEST TRANSACTION DETAILS
       ===================================================== */

    SELECT
        @TransactionID AS transaction_id,
        @TransactionRef AS transaction_ref,
        @Amount AS transaction_amount,
        'INR' AS currency_code,
        'COMPLETED' AS transaction_status,
        @DebitAccountID AS debit_account_id,
        @CreditAccountID AS credit_account_id,
        'SUCCESS' AS insertion_status;


    SELECT
        account_id,
        account_number,
        current_balance
    FROM dbo.accounts
    WHERE account_id IN
    (
        @DebitAccountID,
        @CreditAccountID
    )
    ORDER BY account_id;


    SELECT
        entry_id,
        transaction_id,
        account_id,
        entry_type,
        entry_amount
    FROM dbo.transaction_entries
    WHERE transaction_id = @TransactionID
    ORDER BY entry_id;


END TRY

BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
GO
