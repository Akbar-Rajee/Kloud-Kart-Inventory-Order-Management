# Quality Assurance and Release Checklist

## Scope

This checklist separates source review from database execution. A successful static review is not evidence that PostgreSQL accepted every statement; the deployment and role tests below must also pass.

## Clean deployment order

1. Create a disposable PostgreSQL 18 database.
2. Run `M03_Resources/schema.sql`.
3. Run `M03_Resources/load.sql` from the `M03_Resources` directory so relative CSV paths resolve.
4. Run `sql/00_setup/01_sequences.sql`.
5. Run `sql/00_setup/02_stock_protection.sql`.
6. Run `sql/00_setup/03_execution_roles.sql`.
7. Install `sql/01_transactions/01_place_order.sql`.
8. Install both files in `sql/02_analytics/` in numerical order.
9. Install all four files in `sql/03_inventory/` in numerical order.
10. Install both files in `sql/04_diagnostics/` in numerical order.
11. Call `scan_data_quality_exceptions()` and inspect exception counts.
12. Run `sql/05_security/01_roles_and_grants.sql`.
13. Run `sql/05_security/02_application_role_smoke_tests.sql`.
14. Run `integrity_checks.sql` and the supplied concurrency test.

Use `psql -v ON_ERROR_STOP=1` for every SQL file. Run destructive schema setup only in the disposable database.

## Required runtime checks

- Every SQL file completes without an error on PostgreSQL 18.
- Customer report validation completes without raising an exception.
- The scanner can be called twice; the second run increases detection counts without creating duplicate exception keys.
- Order and inventory routines work when invoked under their respective application roles, not only as `postgres`.
- The order role cannot directly update products or insert orders.
- The inventory role cannot directly update products or insert inventory movements.
- The admin role can update only exception workflow fields and cannot delete exception records.
- The concurrent last-unit test produces exactly one successful order.
- A deliberately excessive inventory adjustment is rejected without changing stock or creating a movement.
- A failed CSV import rolls back all table loads.

## Evidence discipline

Record PostgreSQL version, database reset method, command, result, elapsed time and date for each run. Treat different elapsed times as separate observations, not conflicting results. Do not describe a source-level or static check as a successful database execution.
