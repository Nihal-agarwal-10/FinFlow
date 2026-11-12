
# FinFlow — Dataset Sources and Provenance

## 1. Data Origin

FinFlow uses entirely synthetic financial data generated for educational and portfolio development purposes.

No real customer information, banking credentials, payment records or confidential financial information is used.

No external financial dataset is required to reproduce the project.

## 2. Data Generation

The initial dataset is generated using:

`ingestion/01_generate_financial_data.sql`

The generator creates the following initial records:

| Entity | Initial records |
|---|---:|
| Branches | 8 |
| Customers | 30 |
| Merchants | 20 |
| Accounts | 40 |
| Transactions | 300 |
| Transaction Entries | 600 |

The financial transactions use debit and credit ledger entries to simulate balanced transfers.

## 3. Test Data

Additional synthetic records are created during incremental ETL and data quality testing.

Examples include:

- BR009 — test branch for Change Tracking.
- Invalid customer records for quarantine testing.
- Test merchants and accounts.
- Invalid transaction and ledger-entry records.
- Additional customer versions for SCD Type 2 testing.

These records are development fixtures, not part of the original dataset.

Consequently, current database counts may differ from initial generator counts.

## 4. Data Characteristics

The dataset represents a simplified banking environment containing:

- Customer information.
- Banking branches.
- Merchant information.
- Customer accounts.
- Financial transactions.
- Debit and credit ledger entries.

Synthetic values are used for names, account identifiers, transaction references, contact details and financial amounts.

## 5. Reproducibility

To regenerate the original dataset:

1. Create the FinFlowDB database.
2. Create the operational database tables.
3. Apply constraints and indexes.
4. Execute the synthetic data generation script.

The generator is designed for an empty source database. It should not be rerun against an already populated database without resetting the source tables.

## 6. Disclaimer

FinFlow is an educational data engineering project.

The generated information is fictional and must not be interpreted as actual banking or payment data.
