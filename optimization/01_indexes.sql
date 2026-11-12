
USE FinFlowDB;
GO

/* =========================================================
   FINFLOW - INDEX PERFORMANCE ANALYSIS
   =========================================================

   Purpose:
   1. Inspect existing database indexes.
   2. Analyze index usage.
   3. Inspect index fragmentation.
   4. Identify unused or potentially redundant indexes.
   5. Inspect statistics freshness.

   Index creation is managed separately in:
   database/04_indexes.sql
   ========================================================= */


/* =========================================================
   1. INDEX INVENTORY
   ========================================================= */

SELECT
    OBJECT_SCHEMA_NAME(I.object_id) AS schema_name,
    OBJECT_NAME(I.object_id) AS table_name,
    I.name AS index_name,
    I.type_desc AS index_type,
    I.is_unique,
    I.is_primary_key,
    I.is_disabled,

    C.name AS column_name,
    IC.key_ordinal,
    IC.is_included_column,
    IC.is_descending_key

FROM sys.indexes I

INNER JOIN sys.index_columns IC
    ON I.object_id = IC.object_id
    AND I.index_id = IC.index_id

INNER JOIN sys.columns C
    ON IC.object_id = C.object_id
    AND IC.column_id = C.column_id

WHERE I.object_id IN
(
    OBJECT_ID('dbo.branches'),
    OBJECT_ID('dbo.customers'),
    OBJECT_ID('dbo.merchants'),
    OBJECT_ID('dbo.accounts'),
    OBJECT_ID('dbo.transactions'),
    OBJECT_ID('dbo.transaction_entries')
)

AND I.name IS NOT NULL

ORDER BY
    table_name,
    index_name,
    IC.key_ordinal,
    IC.index_column_id;
GO


/* =========================================================
   2. INDEX USAGE STATISTICS
   ========================================================= */

SELECT
    OBJECT_NAME(I.object_id) AS table_name,
    I.name AS index_name,

    COALESCE(U.user_seeks, 0) AS user_seeks,
    COALESCE(U.user_scans, 0) AS user_scans,
    COALESCE(U.user_lookups, 0) AS user_lookups,
    COALESCE(U.user_updates, 0) AS user_updates,

    U.last_user_seek,
    U.last_user_scan,
    U.last_user_lookup,
    U.last_user_update

FROM sys.indexes I

LEFT JOIN sys.dm_db_index_usage_stats U
    ON I.object_id = U.object_id
    AND I.index_id = U.index_id
    AND U.database_id = DB_ID()

WHERE I.object_id IN
(
    OBJECT_ID('dbo.accounts'),
    OBJECT_ID('dbo.transactions'),
    OBJECT_ID('dbo.transaction_entries')
)

AND I.name IS NOT NULL

ORDER BY
    COALESCE(U.user_seeks, 0) DESC,
    COALESCE(U.user_scans, 0) DESC;
GO


/* =========================================================
   3. INDEX FRAGMENTATION ANALYSIS
   ========================================================= */

SELECT
    OBJECT_NAME(PS.object_id) AS table_name,
    I.name AS index_name,

    PS.index_type_desc,

    PS.page_count,

    CAST(
        PS.avg_fragmentation_in_percent
        AS DECIMAL(10,2)
    ) AS fragmentation_percentage

FROM sys.dm_db_index_physical_stats
(
    DB_ID(),
    NULL,
    NULL,
    NULL,
    'SAMPLED'
) PS

INNER JOIN sys.indexes I
    ON PS.object_id = I.object_id
    AND PS.index_id = I.index_id

WHERE PS.index_id > 0

ORDER BY
    PS.avg_fragmentation_in_percent DESC;
GO


/* =========================================================
   4. INDEX UPDATE VS READ ACTIVITY
   ========================================================= */

SELECT
    OBJECT_NAME(I.object_id) AS table_name,
    I.name AS index_name,

    COALESCE(U.user_seeks, 0)
        + COALESCE(U.user_scans, 0)
        + COALESCE(U.user_lookups, 0)
        AS total_reads,

    COALESCE(U.user_updates, 0)
        AS total_updates,

    CASE
        WHEN COALESCE(U.user_seeks, 0)
           + COALESCE(U.user_scans, 0)
           + COALESCE(U.user_lookups, 0) = 0
        THEN 'NO RECORDED READS'

        WHEN COALESCE(U.user_updates, 0) >
             COALESCE(U.user_seeks, 0)
           + COALESCE(U.user_scans, 0)
           + COALESCE(U.user_lookups, 0)
        THEN 'HIGH WRITE ACTIVITY'

        ELSE 'READ ACTIVITY RECORDED'
    END AS usage_observation

FROM sys.indexes I

LEFT JOIN sys.dm_db_index_usage_stats U
    ON I.object_id = U.object_id
    AND I.index_id = U.index_id
    AND U.database_id = DB_ID()

WHERE I.object_id IN
(
    OBJECT_ID('dbo.accounts'),
    OBJECT_ID('dbo.transactions'),
    OBJECT_ID('dbo.transaction_entries')
)

AND I.name IS NOT NULL

ORDER BY total_reads ASC;
GO


/* =========================================================
   5. INDEX STATISTICS FRESHNESS
   ========================================================= */

SELECT
    OBJECT_NAME(S.object_id) AS table_name,
    S.name AS statistics_name,

    SP.last_updated,
    SP.rows,
    SP.rows_sampled,
    SP.modification_counter

FROM sys.stats S

CROSS APPLY sys.dm_db_stats_properties
(
    S.object_id,
    S.stats_id
) SP

WHERE S.object_id IN
(
    OBJECT_ID('dbo.accounts'),
    OBJECT_ID('dbo.transactions'),
    OBJECT_ID('dbo.transaction_entries')
)

ORDER BY
    table_name,
    statistics_name;
GO


/* =========================================================
   6. FINAL INDEX SUMMARY
   ========================================================= */

SELECT
    OBJECT_NAME(object_id) AS table_name,

    COUNT(*) AS total_indexes,

    SUM(CASE
        WHEN type_desc = 'CLUSTERED'
        THEN 1 ELSE 0
    END) AS clustered_indexes,

    SUM(CASE
        WHEN type_desc = 'NONCLUSTERED'
        THEN 1 ELSE 0
    END) AS nonclustered_indexes,

    SUM(CASE
        WHEN is_unique = 1
        THEN 1 ELSE 0
    END) AS unique_indexes

FROM sys.indexes

WHERE object_id IN
(
    OBJECT_ID('dbo.branches'),
    OBJECT_ID('dbo.customers'),
    OBJECT_ID('dbo.merchants'),
    OBJECT_ID('dbo.accounts'),
    OBJECT_ID('dbo.transactions'),
    OBJECT_ID('dbo.transaction_entries')
)

AND index_id > 0

GROUP BY object_id

ORDER BY table_name;
GO
