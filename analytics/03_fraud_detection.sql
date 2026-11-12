USE FinFlowDB;
GO

CREATE TABLE #FraudResults
(
    account_number VARCHAR(30),
    transaction_id BIGINT,
    transaction_ref VARCHAR(40),
    transaction_amount DECIMAL(19,4),
    occurred_at DATETIME2(0),
    risk_reason VARCHAR(50)
);

INSERT INTO #FraudResults
EXEC dbo.usp_DetectSuspiciousTransactions;

SELECT
    risk_reason,
    COUNT(*) AS flagged_transactions,
    SUM(transaction_amount) AS flagged_value
FROM #FraudResults
GROUP BY risk_reason;

DROP TABLE #FraudResults;
GO