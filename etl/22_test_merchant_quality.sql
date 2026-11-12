
USE FinFlowDB;
GO

/* 1. Insert invalid test merchant */

IF NOT EXISTS (
    SELECT 1
    FROM stg.Merchants
    WHERE merchant_id = '9999999993'
)
BEGIN
    INSERT INTO stg.Merchants
    (
        merchant_id,
        merchant_code,
        merchant_name,
        merchant_category,
        city,
        country
    )
    VALUES
    (
        '9999999993',
        'MER_DQ_TEST',
        'Test Merchant',
        '',
        'Hyderabad',
        'India'
    );
END;
GO

/* 2. Verify test record */

SELECT *
FROM stg.Merchants
WHERE merchant_id = '9999999993';
GO

/* 3. Execute merchant validation */

EXEC dq.usp_QuarantineInvalidMerchants;
GO

/* 4. Verify quarantine */

SELECT
    rejection_id,
    source_record_key,
    rejection_reason,
    raw_record,
    is_resolved
FROM dq.RejectedRecords
WHERE source_table = 'Merchants'
  AND source_record_key = '9999999993';
GO

/* 5. Verify staging cleanup */

SELECT *
FROM stg.Merchants
WHERE merchant_id = '9999999993';
GO
