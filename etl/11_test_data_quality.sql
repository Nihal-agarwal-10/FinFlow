USE FinFlowDB;
GO

-- Test 1: Invalid customer status
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
    '9999999998',
    'CUST_DQ_STATUS_TEST',
    'Test',
    'Status',
    'dqstatus@finflow.demo',
    '9999999993',
    '2002-05-15',
    'UNKNOWN'
);

-- Test 2: Future date of birth
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
    '9999999997',
    'CUST_DQ_DOB_TEST',
    'Test',
    'Date',
    'dqdob@finflow.demo',
    '9999999994',
    '2099-01-01',
    'ACTIVE'
);
GO

EXEC dq.usp_QuarantineInvalidCustomerAttributes;
GO

SELECT
    source_record_key,
    rejection_reason,
    is_resolved
FROM dq.RejectedRecords
WHERE source_record_key IN ('9999999998', '9999999997');
GO