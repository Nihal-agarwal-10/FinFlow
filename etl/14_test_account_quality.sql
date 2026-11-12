USE FinFlowDB;
GO

/* Insert an intentionally invalid account into staging */

INSERT INTO stg.Accounts
(
    account_id,
    account_number,
    customer_id,
    branch_id,
    account_type,
    account_status,
    currency_code,
    current_balance,
    opened_at,
    modified_at
)
VALUES
(
    '9999999996',
    'FF_DQ_TEST_001',
    '1',
    '1',
    'SAVINGS',
    'ACTIVE',
    'INR',
    '-500',
    '2026-01-01',
    '2026-11-06'
);
GO

/* Verify test record */

SELECT *
FROM stg.Accounts
WHERE account_number = 'FF_DQ_TEST_001';
GO

/* Execute account validation */

EXEC dq.usp_QuarantineInvalidAccounts;
GO

/* Verify quarantine */

SELECT
    source_table,
    source_record_key,
    rejection_reason,
    raw_record,
    is_resolved
FROM dq.RejectedRecords
WHERE source_record_key = '9999999996';
GO

/* Verify staging cleanup */

SELECT *
FROM stg.Accounts
WHERE account_number = 'FF_DQ_TEST_001';
GO
