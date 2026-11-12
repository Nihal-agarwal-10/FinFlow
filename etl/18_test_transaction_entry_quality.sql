
USE FinFlowDB;
GO

/* =========================================================
   1. INSERT AN INVALID TEST TRANSACTION ENTRY
   ========================================================= */

IF NOT EXISTS (
    SELECT 1
    FROM stg.TransactionEntries
    WHERE entry_id = '9999999994'
)
BEGIN
    INSERT INTO stg.TransactionEntries
    (
        entry_id,
        transaction_id,
        account_id,
        entry_type,
        entry_amount,
        entry_timestamp
    )
    VALUES
    (
        '9999999994',
        '1',
        '1',
        'DEBIT',
        '-250',
        '2026-11-06 12:00:00'
    );
END;
GO


/* =========================================================
   2. EXECUTE QUALITY VALIDATION
   ========================================================= */

EXEC dq.usp_QuarantineInvalidTransactionEntries;
GO


/* =========================================================
   3. VERIFY QUARANTINED RECORD
   ========================================================= */

SELECT
    rejection_id,
    source_table,
    source_record_key,
    rejection_reason,
    raw_record,
    is_resolved
FROM dq.RejectedRecords
WHERE source_table = 'Transaction Entries'
  AND source_record_key = '9999999994';
GO


/* =========================================================
   4. VERIFY STAGING CLEANUP
   ========================================================= */

SELECT *
FROM stg.TransactionEntries
WHERE entry_id = '9999999994';
GO
