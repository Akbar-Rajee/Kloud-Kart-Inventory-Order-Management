# Quality Assurance and Release Checklist

## Scope

This checklist separates source review from database execution. A successful static review is not evidence that PostgreSQL accepted every statement; the deployment and role tests below must also pass.

## Clean deployment order

1. Create a disposable PostgreSQL 18 database using the pinned image reference in the README.
2. Run `M03_Resources/schema.sql`.
3. Run `M03_Resources/load.sql` from the `M03_Resources` directory so relative CSV paths resolve.
4. Copy `sql/` into the container and run `sql/install_all.psql` with `psql -v ON_ERROR_STOP=1`.
5. Run the supplied concurrency test using the pinned Python image and `requirements.txt`.
6. After all negative historical stock balances have been investigated and corrected, run `sql/00_setup/04_validate_stock_protection.sql`.

Use `psql -v ON_ERROR_STOP=1` for every SQL file. Run destructive schema setup only in the disposable database. `04_validate_stock_protection.sql` is intentionally gated: it should fail with the outstanding product IDs until those balances are remediated, and pass only when no negative stock remains.

## Required runtime checks

- `install_all.psql` completes without an error on PostgreSQL 18.
- Customer report validation completes without raising an exception.
- The scanner can be called twice; the second run increases detection counts without creating duplicate exception keys.
- The application-role smoke test completes after `install_all.psql` installs the roles.
- Order and inventory routines work when invoked under their respective application roles, not only as `postgres`.
- The order role cannot directly update products or insert orders.
- The inventory role cannot directly update products or insert inventory movements.
- The admin role can update only exception workflow fields and cannot delete exception records.
- The concurrent last-unit test produces exactly one successful order.
- A deliberately excessive inventory adjustment is rejected without changing stock or creating a movement.
- A failed CSV import rolls back all table loads.

## Evidence discipline

Record PostgreSQL version, database reset method, command, result, elapsed time and date for each run. Treat different elapsed times as separate observations, not conflicting results. Do not describe a source-level or static check as a successful database execution.
