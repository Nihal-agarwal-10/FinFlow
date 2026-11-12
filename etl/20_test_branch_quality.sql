
USE FinFlowDB;
GO

/* 1. Insert invalid test branch */

IF NOT EXISTS (
    SELECT 1
    FROM stg.Branches
    WHERE branch_id = '99999999'
)
BEGIN
    INSERT INTO stg.Branches
    (
        branch_id,
        branch_code,
        branch_name,
        city,
        state
    )
    VALUES
    (
        '99999999',
        'BR_DQ_TEST',
        'Test Branch',
        '',
        'Telangana'
    );
END;
GO

/* 2. Verify test record */

SELECT *
FROM stg.Branches
WHERE branch_id = '99999999';
GO

/* 3. Execute branch validation */

EXEC dq.usp_QuarantineInvalidBranches;
GO

/* 4. Verify quarantine */

SELECT
    rejection_id,
    source_record_key,
    rejection_reason,
    raw_record,
    is_resolved
FROM dq.RejectedRecords
WHERE source_table = 'Branches'
  AND source_record_key = '99999999';
GO

/* 5. Verify staging cleanup */

SELECT *
FROM stg.Branches
WHERE branch_id = '99999999';
GO