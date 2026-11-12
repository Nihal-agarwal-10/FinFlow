USE FinFlowDB;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetAccountTransactionHistory
    @AccountNumber VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        a.account_number,
        t.transaction_id,
        t.transaction_ref,
        t.transaction_type,
        t.transaction_amount,
        t.transaction_status,
        t.occurred_at
    FROM dbo.transaction_entries te
    JOIN dbo.accounts a
        ON te.account_id = a.account_id
    JOIN dbo.transactions t
        ON te.transaction_id = t.transaction_id
    WHERE a.account_number = @AccountNumber
    ORDER BY t.occurred_at DESC;
END;
GO

EXEC dbo.usp_GetAccountTransactionHistory
    @AccountNumber = 'FF0000000001';
GO