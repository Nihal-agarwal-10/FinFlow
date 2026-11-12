
USE FinFlowDB;
GO

/* =========================================================
   1. INSERT AN INVALID TEST TRANSACTION
   ========================================================= */

IF NOT EXISTS (
    SELECT 1
    FROM stg.Transactions
    WHERE transaction_id = '9999999995'
)
BEGIN
    INSERT INTO stg.Transactions
    (
        transaction_id,
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
        '9999999995',
        'TXN_DQ_TEST_001',
        NULL,
        'TRANSFER',
        'COMPLETED',
        '-500',
        'INR',
        'UPI',
        '2026-11-06 12:00:00'
    );
END;
GO


/* =========================================================
   2. EXECUTE TRANSACTION QUALITY VALIDATION
   ========================================================= */

EXEC dq.usp_QuarantineInvalidTransactions;
GO


/* =========================================================
   3. VERIFY QUARANTINED RECORD
   ========================================================= */

SELECT
    rejection_id,
    source_record_key,
    rejection_reason,
    raw_record,
    is_resolved
FROM dq.RejectedRecords
WHERE source_table = 'Transactions'
  AND source_record_key = '9999999995';
GO


/* =========================================================
   4. VERIFY STAGING CLEANUP
   ========================================================= */

SELECT *
FROM stg.Transactions
WHERE transaction_id = '9999999995';
GO
