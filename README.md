# Kloud Kart Inventory & Order Management

**SQL for Data Engineering – PostgreSQL Project**

## 1. Project overview

Kloud Kart is an e-commerce inventory and order management system. This project improves the reliability of order placement, customer spending analytics, inventory visibility, inventory movement auditing and data-quality monitoring using PostgreSQL.

The solution works with the supplied database schema and dataset. It does not require a new database server or additional infrastructure.

### Business objectives

- Prevent overselling during concurrent order requests.
- Generate customer spending reports with monthly and cumulative totals.
- Calculate trailing 12-month customer spending and rank the top 100 customers.
- Roll up low-stock products through an arbitrary-depth category hierarchy.
- Maintain an auditable record of sales, restocks and stock corrections.
- Identify, record and monitor data-quality and inventory reconciliation exceptions.

## 2. Technology

- PostgreSQL 18 (`postgres:18` image; reproducible image digest shown below)
- Docker Desktop
- Python 3.12
- `psycopg2-binary==2.9.13` (see `requirements.txt`)
- PowerShell

## 3. Repository structure

```text
Kloud-Kart-Inventory-Order-Management/
|-- M03_Resources/
|   |-- data/
|   |-- schema.sql
|   |-- load.sql
|   `-- race_test.py
|-- sql/
|   |-- install_all.psql
|   |-- 00_setup/
|   |   |-- 01_sequences.sql
|   |   |-- 02_stock_protection.sql
|   |   |-- 03_execution_roles.sql
|   |   `-- 04_validate_stock_protection.sql
|   |-- 01_transactions/
|   |   `-- 01_place_order.sql
|   |-- 02_analytics/
|   |   |-- 01_customer_spending_report.sql
|   |   `-- 02_validate_customer_spending_report.sql
|   |-- 03_inventory/
|   |   |-- 01_low_stock_category_report.sql
|   |   |-- 02_category_exceptions.sql
|   |   |-- 03_inventory_reconciliation.sql
|   |   `-- 04_adjust_inventory.sql
|   |-- 04_diagnostics/
|   |   |-- 00_reconnaissance.sql
|   |   |-- 01_data_quality_exception_register.sql
|   |   |-- 02_scan_data_quality.sql
|   |   `-- 03_integrity_checks.sql
|   `-- 05_security/
|       |-- 01_roles_and_grants.sql
|       `-- 02_application_role_smoke_tests.sql
|-- docs/
|   |-- business_memo.md
|   |-- data_quality_diagnosis.md
|   |-- improvement_beyond_brief.md
|   |-- quality_assurance.md
|   `-- adr/
|-- reports/
|   `-- concurrency_test_results.md
|-- requirements.txt
|-- README.md
`-- .gitignore
```

Local `.bak` development backups are excluded by the `*.bak` rule in [`.gitignore`](./.gitignore). The supplied fixture CSVs remain tracked project inputs.

## 4. Database setup and deployment

The following instructions assume Docker is running and the PostgreSQL container is named `kloudkart`.

### Step 0: Create a reproducible PostgreSQL container (first-time setup)

From PowerShell at the repository root, populate `POSTGRES_PASSWORD` from a local secret source, then create the container. This mounts the supplied schema and CSVs read-only and persists database files in a named volume:

```powershell
# Set POSTGRES_PASSWORD from your local secret manager before this command.
if ([string]::IsNullOrWhiteSpace($env:POSTGRES_PASSWORD)) { throw "Set POSTGRES_PASSWORD from a local secret source first." }
docker run --name kloudkart -d `
  --env POSTGRES_USER=postgres `
  --env POSTGRES_DB=kloud_kart `
  --env POSTGRES_PASSWORD `
  --publish 5432:5432 `
  --volume kloudkart_pgdata:/var/lib/postgresql/data `
  --volume "${PWD}\M03_Resources:/lab/M03_Resources:ro" `
  postgres:18@sha256:eece53c7c4410fb9c6556a19b8e0f2d61708a5893e2aa0a1e3c716661374ab18
Remove-Item Env:POSTGRES_PASSWORD
```

This is a one-time container creation command. If `kloudkart` already exists, do not run it again; use the copy fallback below to refresh project files. The image digest pins the PostgreSQL image used for the recorded test environment.

The setup commands use `postgres` as a database administrator for this lab. Production applications must connect through dedicated non-superuser roles; provide all credentials through a secret manager or protected environment variables, never in source control or a shared command transcript.

If the existing container does not have the project files mounted, copy the source files from PowerShell:

```powershell
docker exec kloudkart mkdir -p /lab/M03_Resources/data
docker cp .\M03_Resources\schema.sql kloudkart:/lab/M03_Resources/schema.sql
docker cp .\M03_Resources\load.sql kloudkart:/lab/M03_Resources/load.sql
docker cp .\M03_Resources\data\. kloudkart:/lab/M03_Resources/data/
```

### Step 1: Create the database schema

```powershell
docker exec -w /lab/M03_Resources kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f schema.sql
```

### Step 2: Load the supplied dataset

```powershell
docker exec -w /lab/M03_Resources kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f load.sql
```

The supplied dataset contains:

| Table | Rows |
|---|---:|
| categories | 94 |
| products | 4,023 |
| customers | 40,420 |
| orders | 159,384 |
| order_items | 336,559 |
| inventory_log | 282,352 |

**Important:** `schema.sql` drops and recreates the original tables. Only run it when intentionally rebuilding the database. Do not run it against a database whose existing data must be preserved. The CSV loader runs in one transaction; a failed import rolls back the complete load. Setup sequences and the stock-protection constraint are safe to rerun.

### Step 3: Copy the project SQL into the container

```powershell
docker exec kloudkart rm -rf /tmp/kloudkart_sql
docker exec kloudkart mkdir -p /tmp/kloudkart_sql
docker cp .\sql\. kloudkart:/tmp/kloudkart_sql/
```

### Step 4: Install and verify database objects in order

After the original schema and data are loaded, run the single ordered driver:

```powershell
docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/install_all.psql
```

`install_all.psql` runs the ordered setup, transaction, analytics, inventory, diagnostics, role configuration and smoke-test scripts. It also calls the exception scanner and runs the read-only integrity summary. It stops on the first SQL error. It intentionally does not rebuild the original schema or validate the historical stock constraint.

The driver requires a database administrator because it creates roles and assigns routine ownership. The four application roles and their responsibilities are listed once in [section 5.5](#55-database-security-and-least-privilege). Three restricted, non-login execution-owner roles are also created.

For an optional read-only profile after loading the source data, run `04_diagnostics/00_reconnaissance.sql`; the persistent scanner and compact integrity summary are run by the installer.

### Step 5: Validate historical stock protection after remediation

The initial stock-protection constraint is `NOT VALID` because 14 historical products have negative stock. Investigate and correct those records only after business review. After the query below returns no rows, run the guarded validation script:

```powershell
docker exec kloudkart psql -U postgres -d kloud_kart -c "SELECT product_id, stock_quantity FROM products WHERE stock_quantity < 0 ORDER BY product_id;"
docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/00_setup/04_validate_stock_protection.sql
```

The guard refuses validation and lists any remaining negative product IDs. Do not silently clamp or discard historical balances. Production login accounts should be provisioned separately and granted only the required application-role memberships.

## 5. Implemented solutions

### 5.1 Concurrent order placement

The `place_order()` function uses an atomic conditional stock update:

```sql
UPDATE products
SET stock_quantity = stock_quantity - p_quantity
WHERE product_id = p_product_id
  AND stock_quantity >= p_quantity
  AND stock_quantity IS NOT NULL
  AND price IS NOT NULL
RETURNING price INTO v_price;
```

The conditional update is the central overselling protection. PostgreSQL row-level locking ensures competing transactions cannot both consume the same remaining stock.

The function also creates the order, order item and corresponding inventory movement within the same transaction. If an order cannot be fulfilled, the transaction does not leave partial order records or inventory changes.

The function is implemented as a `SECURITY DEFINER` routine owned by a dedicated non-login role with narrowly scoped table and sequence permissions, a pinned search path, and limited application-role execution.

### 5.2 Customer spending analytics

The `customer_spending_report` view provides:

- Total customer spending.
- Number of eligible orders.
- Monthly spending.
- Cumulative monthly spending.
- Running per-customer cumulative spending.
- Trailing 12-month spending.
- Customer spending rank.
- Top-100 customer indicator.

The report uses window functions and aggregation to calculate the customer metrics. Customers without eligible orders are retained in the report. The project's fixed reporting policy includes statuses `completed`, `complete` and `shipped`; other statuses are excluded. This is an explicit assignment policy for reproducible results, not a claim of stakeholder approval for production.

For Adwoa's exact trailing-12-month figure, use `trailing_12_month_spend`. `monthly_spend` and `running_total` are the month-by-month breakdown of that same rolling interval. The grid has 13 calendar-month labels because the exact 12-month interval can begin and end partway through calendar months; the sum of `monthly_spend` reconciles to `trailing_12_month_spend`. `total_spent`, `order_count` and `spending_rank` are lifetime measures.

### 5.3 Inventory visibility and control

The inventory implementation provides:

- `low_stock_category_report`: low-stock products rolled up through category ancestors using a recursive query.
- The project default low-stock threshold is 5 units, named in the view's `low_stock_settings.low_stock_threshold` CTE.
- `product_category_exceptions`: products assigned to missing or unreachable categories.
- `inventory_reconciliation_review`: inventory balances requiring reconciliation review.
- `adjust_inventory()`: controlled restocking and stock corrections with explanatory notes and corresponding inventory movements.

The category roll-up supports arbitrary hierarchy depth and includes cycle protection.
The reconciliation status `MATCHES_ZERO_OPENING_BALANCE_ASSUMPTION` means only that current stock equals net logged movement under a zero-opening-balance assumption; it is not proof of a verified match.

The adjustment function rejects zero quantity changes, invalid movement reasons, missing notes and adjustments that would produce negative stock.

Sales, restocks and corrections are represented in the inventory movement audit trail.

### 5.4 Data-quality exception monitoring

The diagnostic implementation provides:

- `data_quality_exceptions`: persistent exception register storing original row values as JSONB, issue types, detection timestamps, detection counts and investigation status.
- `record_data_quality_exception()`: retained as an internal helper; it is not exposed to application roles. The scanner performs a set-based batch upsert for performance.
- `scan_data_quality_exceptions()`: scans source tables for identified data-quality problems and records the findings.

The register preserves the first captured source snapshot. It does not automatically resolve an exception when an issue disappears; resolution requires investigation. The scanner monitors 20 issue types, including negative prices and nonpositive order-item quantities.

### 5.5 Database security and least privilege

The `sql/05_security/01_roles_and_grants.sql` script implements four non-login application roles:

- `kloudkart_reader`: reporting access.
- `kloudkart_order_user`: order-processing access.
- `kloudkart_inventory_user`: inventory-management access.
- `kloudkart_admin`: data-quality and administrative access.

Privileged routines have restricted execution permissions. Application roles receive only the table access and routine execution permissions required for their responsibilities.

The project avoids giving ordinary application roles unrestricted direct write access to the underlying tables.

### 5.6 Additional improvement: Persistent data-quality exception register

Beyond the core requirements, the project implements a persistent exception register.

It preserves source snapshots, records detection history, tracks recurring problems and supports investigation and resolution tracking. This gives Nana and Adwoa a repeatable way to monitor data-quality problems instead of relying on one-off diagnostic queries.

The scanner uses batch processing and conflict-aware inserts to avoid creating duplicate exception records during repeated scans.

## 6. Testing and performance evidence

### 6.1 Concurrency testing

The supplied, unmodified `race_test.py` passed:

- 25/25 last-unit contention rounds.
- 400 simultaneous buyers competing for 50 units.
- Exactly 50 successful orders and 350 stock refusals.
- Zero overselling and zero errors.
- Five successful sales with five corresponding inventory movements in the audit test.

Canonical flash-sale observation: **3.53 seconds** in the latest recorded full-suite run. Earlier timings are retained as historical observations in [`reports/concurrency_test_results.md`](reports/concurrency_test_results.md); they are not competing canonical results.

These results demonstrate that the order function protects stock under concurrent requests in the supplied test environment.

### 6.2 Inventory adjustment testing

The `adjust_inventory()` function was tested inside a transaction that was rolled back:

- Restock of 5 units succeeded.
- Correction of -2 units succeeded.
- Excessive correction was rejected.
- NULL movement reason was rejected.
- Both successful movements were visible in the audit log during the test.
- Rollback restored the original stock and removed the temporary movements.

### 6.3 Analytics performance

The complete customer spending report was benchmarked using:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM customer_spending_report;
```

Measured results:

| Metric | Result |
|---|---:|
| Customers | 40,420 |
| Eligible orders | 115,230 |
| Report rows | 525,460 |
| Distinct top-100 customers | 100 |
| Full report execution | 1.90 seconds |

The measured execution time is within the assignment's seconds-level reporting target on the tested local environment.

### 6.4 Inventory validation

The restored dataset produced:

- 37 products with missing categories.
- 6 products in unreachable categories.
- 144 inventory reconciliation review exceptions.
- 521 low-stock products under Electronics.

The reconciliation exceptions require business review because the supplied dataset does not establish a verified opening-stock balance. Equality with net logged movements is labeled as matching only under the zero-opening-balance assumption.

### 6.5 Data-quality scanner performance

The original row-by-row scanner exceeded 10 minutes and was cancelled. The optimized scanner uses batch processing and conflict-aware inserts.

| Measurement | Result |
|---|---:|
| First optimized scan | 14.53 seconds |
| Repeat scan | 13.04 seconds |
| Recorded exception rows | 377,647 |
| Issue types with recorded rows | 15 |
| Total detections recorded | 1,130,662 |
| New exception rows on first optimized scan | 2,279 |
| Duplicate exception keys after repeat scan | 0 |

The scanner contains 20 issue types. Five checks returned no matching records in this dataset:

- `ORDER_ITEM_PRODUCT_MISSING`
- `PRODUCT_CATEGORY_NOT_FOUND`
- `ORDER_ITEM_QUANTITY_NONPOSITIVE`
- `ORDER_ITEM_UNIT_PRICE_NEGATIVE`
- `PRODUCT_PRICE_NEGATIVE`

The original scan was cancelled, so an exact like-for-like speedup ratio is not claimed. The optimized scanner completed successfully, and repeated execution did not create duplicate exception records.

For the full release checklist and role-level verification requirements, see [`docs/quality_assurance.md`](docs/quality_assurance.md).

## 7. Assumptions and limitations

- The project's fixed reporting policy counts `completed`, `complete` and `shipped` as eligible spending; all other statuses are excluded. Production use requires the business owner to approve or replace this explicit project policy.
- The report generates 13 calendar-month labels for an exact rolling 12-month interval. The first and current-month labels can be partial. Use `trailing_12_month_spend` for Adwoa's single trailing-12-month figure; the monthly columns are its breakdown.
- The reconciliation view is indicative because the supplied dataset does not establish a verified opening-stock balance.
- The inventory log does not contain a dedicated order ID column. The implemented order function records the order ID in the movement note.
- The stock protection CHECK constraint is initially `NOT VALID` because 14 historical products have negative stock. It enforces the constraint for new inserts and updates while those historical exceptions remain under investigation. Their IDs and balances are listed in [`docs/data_quality_diagnosis.md`](docs/data_quality_diagnosis.md). After they are investigated and corrected, run `sql/00_setup/04_validate_stock_protection.sql` to validate the constraint.
- The data-quality register records original snapshots and detection metadata; it is not a complete change-history system.
- Performance measurements reflect the supplied dataset and local Docker environment. They are not a production SLA.
- Category exceptions are reported rather than automatically corrected because appropriate category assignments require business validation.
- The database security script creates non-login roles, not production application login accounts.

## 8. Running the supplied concurrency test

The test reads `DATABASE_URL` from the process environment. Keep the connection string in a local secret manager or an ignored `.env` file; do not put a real password in source code or a command-history entry. The original instructor script's inline DSN is illustrative only. For a local `.env` containing only the connection string, load it in PowerShell with:

```powershell
$env:DATABASE_URL = (Get-Content .\.env -Raw).Trim()
python -m pip install -r .\requirements.txt
python .\M03_Resources\race_test.py
```

For a Dockerized test runner, run from the project root after setting `DATABASE_URL` to use `host.docker.internal` and the published PostgreSQL port:

```powershell
docker run --rm `
  --mount "type=bind,source=$($PWD.Path),target=/workspace,readonly" `
  --workdir /workspace `
  --env DATABASE_URL `
  python:3.12-slim@sha256:191083cdf6c7bda8c76158983163ead5d5cf7b77cf3033e805bb0f5296f51b4b `
  sh -c "python -m pip install --no-cache-dir -r requirements.txt && python M03_Resources/race_test.py"
```

The instructor's test script is used without modification. It creates and removes fixture rows; use a test database, not production.

## 9. Business outcome

The solution demonstrates safer order placement, customer analytics generated in seconds, hierarchical low-stock reporting, controlled inventory adjustments, auditable stock movements, database access controls and persistent data-quality exception monitoring using the existing PostgreSQL environment.

The implementation provides a tested foundation for Kloud Kart's inventory and order management processes. Historical data-quality issues remain visible for business investigation rather than being silently corrected.
