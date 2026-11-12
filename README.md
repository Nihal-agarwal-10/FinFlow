# FinFlow — End-to-End Financial Transaction Data Engineering Platform

**FinFlow** is a SQL Server-based data engineering project that simulates a financial transaction processing environment and implements an end-to-end data pipeline.

The platform demonstrates relational database design, incremental ETL, data quality enforcement, dimensional modelling, historical data tracking, fraud detection and query optimization using T-SQL.

---

## Project Overview

Financial systems process large volumes of transactions that require reliable ingestion, validation, transformation and analytical storage.

FinFlow addresses this workflow by implementing a layered data engineering architecture that moves synthetic financial data from operational tables into a structured analytical warehouse.

**Primary objective:** Build a reproducible, SQL-first financial data engineering platform using Microsoft SQL Server.

## Architecture

```text
              SOURCE DATABASE
          (Customers, Accounts,
       Branches, Merchants, Transactions)
                     |
                     v
              STAGING LAYER
             (Raw Data Landing)
                     |
                     v
             INCREMENTAL ETL
          (SQL Server Change Tracking)
                     |
                     v
             DATA QUALITY LAYER
          (Validation and Quarantine)
                     |
                     v
                CLEAN LAYER
        (Type Conversion and Standardization)
                     |
                     v
              DATA WAREHOUSE
          (Dimensions and Fact Tables)
                     |
                     v
             ANALYTICAL SQL
       (Customer, Transaction and Fraud Analysis)
```

## Technology Stack

| Technology | Purpose |
|---|---|
| Microsoft SQL Server Express | Relational database engine |
| T-SQL | Data processing and analytics |
| Visual Studio Code | SQL development environment |
| SQL Server Extension (`mssql`) | Database connectivity and query execution |
| SQL Server Change Tracking | Incremental change detection |
| SQL Server Execution Plans | Query performance analysis |

## Core Features

### 1. Relational Database Design
- Six operational tables.
- Primary keys, foreign keys and unique constraints.
- CHECK constraints for financial and business rules.
- Appropriate data types and indexing.

### 2. Data Ingestion and ETL
- Synthetic financial transaction data generation.
- Raw staging tables.
- Data type conversion and standardization.
- Incremental INSERT, UPDATE and DELETE synchronization.
- Change Tracking with per-table synchronization checkpoints.

### 3. Data Quality Management
- Invalid record detection.
- Rejected record quarantine.
- Original record preservation in JSON format.
- Duplicate detection.
- Referential integrity checks.
- Centralized data quality reporting.

### 4. Data Warehousing
- Dimension and fact table modelling.
- Star-schema architecture.
- Transaction-level and ledger-entry-level fact tables.
- Surrogate keys.
- Date dimension.
- Slowly Changing Dimension Type 2 for customer history.

### 5. Advanced SQL Analytics
- Customer transaction summaries.
- Transaction channel analysis.
- Branch performance analysis.
- Monthly transaction trends.
- Rule-based suspicious transaction detection.
- Stored procedures for reusable analytical queries.

### 6. Performance Optimization
- Nonclustered indexes.
- Composite indexes.
- Covering indexes.
- SARGable date filtering.
- Logical reads and execution-plan analysis.

### 7. Pipeline Orchestration
- Incremental ETL orchestration.
- Data quality orchestration.
- Clean-layer refresh and validation.
- Warehouse refresh procedure.
- End-to-end master execution procedure.
- Execution and error logging.

## Database Structure

The project contains six operational source tables:

| Table | Description |
|---|---|
| Customers | Customer information |
| Branches | Banking branch information |
| Merchants | Merchant information |
| Accounts | Customer bank accounts |
| Transactions | Financial transactions |
| Transaction Entries | Debit and credit ledger entries |

The staging and clean layers contain corresponding representations of these entities.

The warehouse contains dimension tables and two fact tables:

| Warehouse table | Grain |
|---|---|
| FactTransactions | One row per transaction |
| FactLedgerEntries | One row per ledger entry |

## Repository Structure

```text
FinFlow/
│
├── README.md
│
├── database/
│   ├── 01_create_database.sql
│   ├── 02_create_tables.sql
│   ├── 03_constraints.sql
│   └── ...
│
├── ingestion/
│   ├── 01_generate_financial_data.sql
│   ├── 01_staging_tables.sql
│   └── 02_data_loading.sql
│
├── etl/
│   ├── 01_validation.sql
│   ├── 02_cleaning.sql
│   ├── 04_incremental_loading.sql
│   ├── 05_change_tracking.sql
│   ├── 06_incremental_etl_procedure.sql
│   ├── 08_master_etl_orchestrator.sql
│   ├── 10_data_quality_framework.sql
│   ├── 27_clean_layer_refresh.sql
│   ├── 28_clean_layer_validation.sql
│   └── 30_finflow_master_pipeline.sql
│
├── warehouse/
│   ├── 01_create_dimensions.sql
│   ├── 02_fact_tables.sql
│   ├── 03_scd_type_2.sql
│   └── 05_warehouse_refresh_procedure.sql
│
├── analytics/
│   ├── 01_customer_analysis.sql
│   ├── 02_stored_procedures.sql
│   └── 03_fraud_detection_procedure.sql
│
├── optimization/
│   ├── 01_query_performance.sql
│   └── 02_query_optimization.sql
│
└── documentation/
    └── performance_results.md
```

*The tree highlights key files; it is not an exhaustive listing.*

## Running the Project

### Prerequisites
- Microsoft SQL Server Express.
- Visual Studio Code.
- Microsoft SQL Server (`mssql`) extension.
- Access to a SQL Server instance.

### Execution

1. Create the `FinFlowDB` database.
2. Execute the database schema, constraints and index scripts.
3. Create and populate the synthetic source data.
4. Create staging tables and load source data.
5. Enable SQL Server Change Tracking.
6. Create the incremental ETL procedures and checkpoints.
7. Set up the data quality framework and quarantine procedures.
8. Create and refresh the clean layer.
9. Create warehouse dimensions, fact tables and SCD Type 2 logic.
10. Execute the warehouse refresh procedure.
11. Execute the end-to-end pipeline:

```sql
USE FinFlowDB;
GO

EXEC dbo.usp_RunFinFlowPipeline;
GO
```

## Current Dataset

The development dataset contains synthetic records, including:

| Entity | Records |
|---|---:|
| Branches | 9 |
| Customers | 30 |
| Merchants | 20 |
| Accounts | 40 |
| Transactions | 300 |
| Transaction Entries | 600 |

The warehouse also maintains historical customer versions through SCD Type 2.

These are development dataset counts, not real-world financial statistics.

## Engineering Considerations

FinFlow is an educational and portfolio project. Its data is synthetic and it is not designed or certified for processing real financial transactions.

The implementation focuses on demonstrating SQL-based data engineering concepts, transaction consistency, data quality controls and reproducible ETL workflows.

## Author

**Nihal Agarwal**

Computer Science and Business Systems
GITAM University, Hyderabad

**Project:** FinFlow — End-to-End Financial Transaction Data Engineering Platform