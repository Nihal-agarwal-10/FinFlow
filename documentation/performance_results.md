
# FinFlow — SQL Performance Analysis and Optimization

## 1. Overview

This document records SQL query performance experiments conducted on the FinFlow financial transaction database.

The objective is to evaluate query execution behaviour, indexing strategies, logical reads, execution plans and SARGable filtering.

The experiments use SQL Server execution statistics and actual execution plans.

## 2. Test Environment

| Property | Configuration |
|---|---|
| Database | FinFlowDB |
| Database engine | Microsoft SQL Server Express |
| SQL development environment | Visual Studio Code |
| Source transactions | 300 |
| Ledger entries | 600 |
| Accounts | 40 |
| Customers | 30 |

The dataset is synthetic and relatively small. Results should not be interpreted as production-scale benchmarks.

## 3. Performance Measurement Methodology

The following SQL Server commands were used:

```sql
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Execute the test query here.

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
```

Actual execution plans were also inspected to understand the operators used by SQL Server.

Key metrics:

- Logical Reads: Number of data pages accessed from the buffer pool.
- Physical Reads: Number of pages read from storage.
- CPU Time: Processor time used by the query.
- Elapsed Time: Total query execution duration.
- Execution Plan: Operators selected by the SQL Server optimizer.

## 4. Experiment 1 — Account Transaction History

### Objective

Retrieve all transactions associated with a particular bank account.

### Query

```sql
SELECT
    A.account_number,
    T.transaction_id,
    T.transaction_ref,
    T.transaction_type,
    T.transaction_amount,
    T.transaction_status,
    T.occurred_at

FROM dbo.transaction_entries TE

INNER JOIN dbo.accounts A
    ON TE.account_id = A.account_id

INNER JOIN dbo.transactions T
    ON TE.transaction_id = T.transaction_id

WHERE A.account_number = 'FF0000000001'

ORDER BY T.occurred_at DESC;
```

The query returned 15 transactions.

### Baseline measurements

Before adding the account transaction index:

| Metric | Observed value |
|---|---:|
| Transactions logical reads | 30 |
| Transaction Entries logical reads | 2 |
| Accounts logical reads | 2 |
| Total logical reads | 34 |
| CPU time | 0 ms |
| Elapsed time | 10 ms |

### Indexing strategy

A nonclustered index was created on the transaction entries table.

```sql
CREATE NONCLUSTERED INDEX
IX_TransactionEntries_AccountID

ON dbo.transaction_entries (account_id)

INCLUDE
(
    transaction_id,
    entry_type,
    entry_amount
);
```

A subsequent composite index was also evaluated:

```sql
CREATE NONCLUSTERED INDEX
IX_TransactionEntries_Account_Transaction

ON dbo.transaction_entries
(
    account_id,
    transaction_id
)

INCLUDE
(
    entry_type,
    entry_amount
);
```

The narrower overlapping index was removed, retaining the composite index.

### Observed measurements after indexing

| Metric | Observed value |
|---|---:|
| Transactions logical reads | 30 |
| Transaction Entries logical reads | 2 |
| Accounts logical reads | 2 |
| Total logical reads | 34 |
| CPU time | 0 ms |
| Elapsed time | Approximately 1 ms |

### Execution plan observations

The actual execution plan showed:

- Index Seek on accounts using the account number lookup.
- Index Seek on transaction entries.
- Clustered Index Seek on transactions.
- Nested Loops Join.
- Sort operator for descending transaction timestamps.

### Conclusion

The index was selected by the query optimizer, but the recorded logical reads remained at 34.

The observed elapsed-time difference is too small and too sensitive to caching to establish a reliable performance improvement.

This experiment demonstrates that an index can improve access-path selection without necessarily reducing logical reads on a small dataset.

## 5. Experiment 2 — SARGable Date Filtering

### Objective

Compare a date filter that applies a function to a timestamp column with a date-range predicate.

### Non-SARGable query

```sql
SELECT *
FROM dbo.transactions

WHERE CAST(occurred_at AS DATE) = '2026-11-02';
```

### SARGable query

```sql
SELECT *
FROM dbo.transactions

WHERE occurred_at >= '2026-11-02'
  AND occurred_at < '2026-11-03'

ORDER BY occurred_at DESC;
```

Both queries returned 85 records.

### Observed date-range measurements

| Metric | Observed value |
|---|---:|
| Rows returned | 85 |
| Transactions scan count | 1 |
| Logical reads | 6 |
| CPU time | 16 ms |
| Elapsed time | 0 ms |

A before-and-after logical-read comparison for the CAST version was not retained. Therefore, a measured improvement cannot be claimed.

### Indexing strategy

The following index was created for timestamp-based transaction retrieval:

```sql
CREATE NONCLUSTERED INDEX
IX_Transactions_OccurredAt

ON dbo.transactions (occurred_at DESC)

INCLUDE
(
    transaction_ref,
    transaction_type,
    transaction_amount,
    transaction_status
);
```

Post-index measurements were not captured.

### Conclusion

The date-range predicate is preferable because it avoids applying a function to the indexed timestamp column and allows SQL Server to consider an index range seek.

However, the actual performance improvement remains unquantified in this experiment.

## 6. Index Inventory

The following indexing strategies were implemented or evaluated.

| Table | Index | Purpose |
|---|---|---|
| transaction_entries | IX_TransactionEntries_Account_Transaction | Account and transaction lookups |
| transactions | IX_Transactions_OccurredAt | Timestamp-based retrieval |
| accounts | Unique account number constraint/index | Account number lookup |

The database also contains clustered primary key indexes and other indexes associated with unique constraints.

## 7. Key Findings

1. Appropriate indexes provide additional access paths for transaction retrieval.
2. Composite indexes can support queries filtering by account and retrieving transaction identifiers.
3. Included columns can reduce the need for additional lookups.
4. SARGable date predicates are preferable to applying CAST directly to timestamp columns.
5. Index usefulness depends on data volume, selectivity and query patterns.
6. Performance measurements on small datasets can be dominated by caching and execution overhead.
7. Creating overlapping indexes can introduce unnecessary storage and write overhead.

## 8. Limitations

The current dataset contains only 300 transactions and 600 ledger entries.

This is insufficient to establish meaningful production-scale performance characteristics.

Other limitations include:

- Limited repeated benchmark runs.
- Cache-sensitive elapsed-time measurements.
- No retained post-index date-query statistics.
- No large-volume concurrency or write-load testing.

## 9. Future Optimization Opportunities

Further experiments could include:

- Generating one million or more synthetic transactions.
- Repeated benchmark runs with median execution times.
- Comparing index seek and scan behaviour at different data volumes.
- Measuring index maintenance overhead.
- Testing query performance under concurrent workloads.
- Evaluating additional covering indexes based on actual query patterns.

## 10. Final Assessment

FinFlow demonstrates practical SQL Server performance engineering through indexing, query-plan inspection, logical-read measurement and SARGable filtering.

The experiments emphasize evidence-based optimization rather than assuming that every additional index guarantees better performance.
