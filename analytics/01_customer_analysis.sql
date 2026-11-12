USE FinFlowDB;
GO

-- 1. Customer transaction summary

SELECT
    dc.customer_id,
    dc.full_name,
    COUNT(ft.transaction_id) AS total_transactions,
    SUM(ft.transaction_amount) AS total_transaction_value,
    AVG(ft.transaction_amount) AS average_transaction_value,
    MAX(ft.transaction_amount) AS largest_transaction
FROM warehouse.FactTransactions ft
JOIN warehouse.DimCustomer dc
    ON ft.customer_key = dc.customer_key
WHERE dc.is_current = 1
GROUP BY
    dc.customer_id,
    dc.full_name
ORDER BY total_transaction_value DESC;
GO

-- 2. Transaction channel performance

SELECT
    ch.transaction_channel,
    COUNT(*) AS total_transactions,
    SUM(ft.transaction_amount) AS total_transaction_value,
    AVG(ft.transaction_amount) AS average_transaction_value,
    MIN(ft.transaction_amount) AS minimum_transaction,
    MAX(ft.transaction_amount) AS maximum_transaction
FROM warehouse.FactTransactions ft
JOIN warehouse.DimChannel ch
    ON ft.channel_key = ch.channel_key
GROUP BY
    ch.transaction_channel
ORDER BY
    total_transaction_value DESC;
GO

-- 3. Monthly transaction trends

SELECT
    YEAR(dd.full_date) AS transaction_year,
    MONTH(dd.full_date) AS transaction_month,
    DATENAME(MONTH, dd.full_date) AS month_name,
    COUNT(*) AS total_transactions,
    SUM(ft.transaction_amount) AS total_transaction_value,
    AVG(ft.transaction_amount) AS average_transaction_value
FROM warehouse.FactTransactions ft
JOIN warehouse.DimDate dd
    ON ft.date_key = dd.date_key
GROUP BY
    YEAR(dd.full_date),
    MONTH(dd.full_date),
    DATENAME(MONTH, dd.full_date)
ORDER BY
    transaction_year,
    transaction_month;
GO


-- 4. Rule-based suspicious transaction detection

WITH TransactionActivity AS (
    SELECT
        ft.transaction_id,
        ft.debit_account_key,
        t.occurred_at,
        ft.transaction_amount,
        ft.currency_code,

        COUNT(*) OVER (
            PARTITION BY ft.debit_account_key
            ORDER BY t.occurred_at
            RANGE BETWEEN UNBOUNDED PRECEDING
                  AND CURRENT ROW
        ) AS cumulative_account_transactions

    FROM warehouse.FactTransactions ft
    JOIN clean.Transactions t
        ON ft.transaction_id = t.transaction_id
),
SuspiciousTransactions AS (
    SELECT
        a.*,
        (
            SELECT COUNT(*)
            FROM TransactionActivity b
            WHERE b.debit_account_key = a.debit_account_key
              AND b.occurred_at BETWEEN
                  DATEADD(MINUTE, -60, a.occurred_at)
                  AND a.occurred_at
        ) AS transactions_in_last_hour
    FROM TransactionActivity a
)
SELECT
    transaction_id,
    debit_account_key,
    occurred_at,
    transaction_amount,
    transactions_in_last_hour,
    CASE
        WHEN transaction_amount > 900
         AND transactions_in_last_hour >= 3
            THEN 'HIGH RISK'
        WHEN transaction_amount > 900
            THEN 'HIGH VALUE'
        WHEN transactions_in_last_hour >= 3
            THEN 'RAPID ACTIVITY'
    END AS risk_reason
FROM SuspiciousTransactions
WHERE transaction_amount > 900
   OR transactions_in_last_hour >= 3
ORDER BY
    transactions_in_last_hour DESC,
    transaction_amount DESC;
GO


-- 5. Branch performance analysis

SELECT
    b.branch_id,
    b.branch_name,
    b.city,
    b.state,
    COUNT(ft.transaction_id) AS total_transactions,
    SUM(ft.transaction_amount) AS total_transaction_value,
    AVG(ft.transaction_amount) AS average_transaction_value,
    COUNT(DISTINCT ft.customer_key) AS unique_customers
FROM warehouse.FactTransactions ft
JOIN warehouse.DimAccount da
    ON ft.debit_account_key = da.account_key
JOIN warehouse.DimBranch b
    ON da.branch_id = b.branch_id
GROUP BY
    b.branch_id,
    b.branch_name,
    b.city,
    b.state
ORDER BY
    total_transaction_value DESC;
GO
