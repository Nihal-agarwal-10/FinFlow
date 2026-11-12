CREATE OR ALTER PROCEDURE dbo.usp_GetAccountTransactionHistory
    @AccountNumber VARCHAR(30),
    @StartDate DATETIME2(0),
    @EndDate DATETIME2(0)
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
      AND t.occurred_at >= @StartDate
      AND t.occurred_at < @EndDate
    ORDER BY t.occurred_at DESC;
END;
GO

EXEC dbo.usp_GetAccountTransactionHistory
    @AccountNumber = 'FF0000000001',
    @StartDate = '2026-11-02',
    @EndDate = '2026-11-03';
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetAccountTransactionSummary
    @AccountNumber VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        a.account_number,
        COUNT(DISTINCT t.transaction_id) AS total_transactions,
        SUM(t.transaction_amount) AS total_transaction_value,
        AVG(t.transaction_amount) AS average_transaction_value,
        MIN(t.transaction_amount) AS minimum_transaction,
        MAX(t.transaction_amount) AS maximum_transaction
    FROM dbo.transaction_entries te
    JOIN dbo.accounts a
        ON te.account_id = a.account_id
    JOIN dbo.transactions t
        ON te.transaction_id = t.transaction_id
    WHERE a.account_number = @AccountNumber
    GROUP BY a.account_number;
END;
GO

EXEC dbo.usp_GetAccountTransactionSummary
    @AccountNumber = 'FF0000000001';
GO