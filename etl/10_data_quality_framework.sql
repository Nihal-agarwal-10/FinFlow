
USE FinFlowDB;
GO

/* =========================================================
   1. INSERT INVALID TEST CUSTOMER
   ========================================================= */

IF NOT EXISTS (
    SELECT 1
    FROM stg.Customers
    WHERE customer_ref = 'CUST_DQ_TEST'
)
BEGIN
    INSERT INTO stg.Customers
    (
        customer_id,
        customer_ref,
        first_name,
        last_name,
        email,
        phone,
        date_of_birth,
        customer_status
    )
    VALUES
    (
        'BAD_ID_001',
        'CUST_DQ_TEST',
        'Test',
        'Customer',
        'dqtest@finflow.demo',
        '9999999990',
        '2002-05-15',
        'ACTIVE'
    );
END;
GO


/* =========================================================
   2. EXECUTE QUARANTINE PROCEDURE
   ========================================================= */

EXEC dq.usp_QuarantineInvalidCustomers;
GO


/* =========================================================
   3. VERIFY REJECTED RECORD
   ========================================================= */

SELECT
    rejection_id,
    source_table,
    source_record_key,
    rejection_reason,
    raw_record,
    is_resolved
FROM dq.RejectedRecords
WHERE source_record_key = 'BAD_ID_001';
GO


/* =========================================================
   4. VERIFY STAGING CLEANUP
   ========================================================= */

SELECT *
FROM stg.Customers
WHERE customer_ref = 'CUST_DQ_TEST';
GO


/* =========================================================
   5. VERIFY DUPLICATE PREVENTION
   ========================================================= */

SELECT
    source_record_key,
    COUNT(*) AS rejection_count
FROM dq.RejectedRecords
WHERE source_table = 'Customers'
  AND source_record_key = 'BAD_ID_001'
GROUP BY source_record_key;
GO
