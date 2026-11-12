DELETE FROM dbo.merchants
WHERE merchant_code = 'MER_CT_001';
GO

EXEC dbo.usp_SyncMerchants;
GO

SELECT *
FROM stg.Merchants
WHERE merchant_code = 'MER_CT_001';
GO