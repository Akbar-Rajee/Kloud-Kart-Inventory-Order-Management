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

- PostgreSQL 18
- Docker Desktop
- Python 3
- psycopg2
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
|   |-- 00_setup/
|   |   |-- 01_sequences.sql
|   |   |-- 02_stock_protection.sql
|   |   `-- 03_execution_roles.sql
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
|   |   |-- 01_data_quality_exception_register.sql
|   |   `-- 02_scan_data_quality.sql
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
|-- README.md
|-- 01_reconnaissance.sql
|-- integrity_checks.sql
`-- .gitignore
```

The repository contains only maintained project files; temporary development backups are excluded from deployment.

## 4. Database setup and deployment

The following instructions assume Docker is running and the PostgreSQL container is named `kloudkart`.

### Step 0: Make the source files available inside the container

The `docker exec -w /lab/M03_Resources` commands below assume the project directory has been mounted at `/lab/M03_Resources` in the `kloudkart` container. If it is not mounted, copy the resources from PowerShell first:

```powershell
docker exec kloudkart mkdir -p /lab/M03_Resources/data
docker cp .\M03_Resources\schema.sql kloudkart:/lab/M03_Resources/schema.sql
docker cp .\M03_Resources\load.sql kloudkart:/lab/M03_Resources/load.sql
docker cp .\M03_Resources\data\. kloudkart:/lab/M03_Resources/data/
```

### Step 1: Create the database schema

From the project root:

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

### Step 4: Install database objects in order

Run the following commands after creating the original schema and loading the dataset.

**4.1 Create sequences, stock protection and restricted execution-owner roles**

```powershell
docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/00_setup/01_sequences.sql

docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/00_setup/02_stock_protection.sql

docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/00_setup/03_execution_roles.sql
```

**4.2 Install transactional order processing**

```powershell
docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/01_transactions/01_place_order.sql
```

**4.3 Install customer analytics**

```powershell
docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/02_analytics/01_customer_spending_report.sql
```

**4.4 Install inventory reporting and adjustment routines**

```powershell
docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/03_inventory/01_low_stock_category_report.sql

docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/03_inventory/02_category_exceptions.sql

docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/03_inventory/03_inventory_reconciliation.sql

docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/03_inventory/04_adjust_inventory.sql
```

**4.5 Install data-quality monitoring**

```powershell
docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/04_diagnostics/01_data_quality_exception_register.sql

docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/04_diagnostics/02_scan_data_quality.sql
```

### Step 5: Validate the customer spending report

```powershell
docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/02_analytics/02_validate_customer_spending_report.sql
```

### Step 6: Populate the data-quality exception register

After installing the diagnostic table and scanner procedure:

```powershell
docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -c "CALL scan_data_quality_exceptions();"
```

This scans the source tables and records detected exceptions without deleting or silently correcting the original records.

### Step 7: Configure application roles and permissions

Run this after all tables, views and routines have been installed:

```powershell
docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/05_security/01_roles_and_grants.sql
```

The script creates four non-login application roles and uses three dedicated non-login execution-owner roles. The execution-owner roles receive only the table and sequence privileges required by their respective routines. The privileged routines use `SECURITY DEFINER` with a pinned search path and are owned by these restricted roles.

The script creates four non-login roles:

- `kloudkart_reader`
- `kloudkart_order_user`
- `kloudkart_inventory_user`
- `kloudkart_admin`

It grants schema access, role-specific read permissions and restricted execution of the order, inventory and diagnostic routines. The administrator can update only the exception status, resolution timestamp and resolution note; it cannot delete exception records.

Run the permission smoke tests after role configuration:

```powershell
docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/05_security/02_application_role_smoke_tests.sql
```

The script does not create application login accounts. Production login accounts should be provisioned separately and granted only the role memberships they require.

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

The report uses window functions and aggregation to calculate the customer metrics. Customers without eligible orders are retained in the report.

The business assumption is that `completed`, `complete` and `shipped` orders count as eligible spending. This should be confirmed with the business.

### 5.3 Inventory visibility and control

The inventory implementation provides:

- `low_stock_category_report`: low-stock products rolled up through category ancestors using a recursive query.
- `product_category_exceptions`: products assigned to missing or unreachable categories.
- `inventory_reconciliation_review`: inventory balances requiring reconciliation review.
- `adjust_inventory()`: controlled restocking and stock corrections with explanatory notes and corresponding inventory movements.

The category roll-up supports arbitrary hierarchy depth and includes cycle protection.

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

Flash-sale test execution time: **4.72 seconds**.

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

The reconciliation exceptions require business review because the supplied dataset does not establish a verified opening-stock balance.

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

- Eligible spending statuses are `completed`, `complete` and `shipped`. The business should confirm the treatment of cancelled, refunded and other status variants.
- The report generates 13 monthly labels, from the month containing the date 12 months ago through the current month. The first and last months may be partial. The separate trailing 12-month metric is calculated for each customer.
- The reconciliation view is indicative because the supplied dataset does not establish a verified opening-stock balance.
- The inventory log does not contain a dedicated order ID column. The implemented order function records the order ID in the movement note.
- The stock protection CHECK constraint is initially `NOT VALID` because 14 historical products have negative stock. It enforces the constraint for new inserts and updates while those historical exceptions remain under investigation.
- The data-quality register records original snapshots and detection metadata; it is not a complete change-history system.
- Performance measurements reflect the supplied dataset and local Docker environment. They are not a production SLA.
- Category exceptions are reported rather than automatically corrected because appropriate category assignments require business validation.
- The database security script creates non-login roles, not production application login accounts.

## 8. Running the supplied concurrency test

From the project root, with the Python environment configured:

```powershell
python .\M03_Resources\race_test.py
```

The instructor's test script is used without modification.

## 9. Business outcome

The solution demonstrates safer order placement, customer analytics generated in seconds, hierarchical low-stock reporting, controlled inventory adjustments, auditable stock movements, database access controls and persistent data-quality exception monitoring using the existing PostgreSQL environment.

The implementation provides a tested foundation for Kloud Kart's inventory and order management processes. Historical data-quality issues remain visible for business investigation rather than being silently corrected.
