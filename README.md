# Kloud Kart Inventory & Order Management

**SQL for Data Engineering - PostgreSQL project**

## 1. Project overview

Kloud Kart is an e-commerce inventory and order management system. This project improves the reliability of order placement, customer spending analytics, inventory visibility, inventory movement auditing and data-quality monitoring using PostgreSQL.

The implementation works with the supplied database schema and dataset. It does not require a new database server or infrastructure.

### Business objectives

- Prevent overselling during concurrent order requests.
- Generate a customer spending report with monthly and cumulative totals.
- Rank the top 100 customers by spending.
- Roll up low-stock products through a hierarchical category structure.
- Maintain an auditable record of sales, restocks and stock corrections.
- Identify and persist data-quality and inventory reconciliation exceptions.

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
|-- sql/
|   |-- 00_setup/
|   |   |-- 01_sequences.sql
|   |   `-- 02_stock_protection.sql
|   |-- 01_transactions/
|   |   `-- 01_place_order.sql
|   |-- 02_analytics/
|   |   `-- 01_customer_spending_report.sql
|   |-- 03_inventory/
|   |   |-- 01_low_stock_category_report.sql
|   |   |-- 02_category_exceptions.sql
|   |   |-- 03_inventory_reconciliation.sql
|   |   `-- 04_adjust_inventory.sql
|   `-- 04_diagnostics/
|       |-- 01_data_quality_exception_register.sql
|       `-- 02_scan_data_quality.sql
|-- reports/
|   `-- concurrency_test_results.md
|-- docs/
|-- tests/
|   |-- integration/
|   `-- unit/
|-- scripts/
|-- README.md
`-- .gitignore
```

## 4. Database setup

The following instructions assume that Docker is running and the PostgreSQL container is named `kloudkart`.

### Step 1: Create the database schema

From the project root:

```powershell
docker exec -w /lab/M03_Resources kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f schema.sql
```

### Step 2: Load the supplied dataset

```powershell
docker exec -w /lab/M03_Resources kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f load.sql
```

The original dataset contains:

| Table | Rows |
|---|---:|
| categories | 94 |
| products | 4,023 |
| customers | 40,420 |
| orders | 159,384 |
| order_items | 336,559 |
| inventory_log | 282,352 |

**Important:** `schema.sql` drops and recreates the original tables. Only run it when intentionally rebuilding the database.

### Step 3: Copy the project SQL into the container

```powershell
docker exec kloudkart rm -rf /tmp/kloudkart_sql
docker exec kloudkart mkdir -p /tmp/kloudkart_sql
docker cp .\sql\. kloudkart:/tmp/kloudkart_sql/
```

### Step 4: Install database objects in order

Run the following commands after the original schema and data load:

```powershell
docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/00_setup/01_sequences.sql

docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/00_setup/02_stock_protection.sql

docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/01_transactions/01_place_order.sql

docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/02_analytics/01_customer_spending_report.sql

docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/03_inventory/01_low_stock_category_report.sql

docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/03_inventory/02_category_exceptions.sql

docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/03_inventory/03_inventory_reconciliation.sql

docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/03_inventory/04_adjust_inventory.sql

docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/04_diagnostics/01_data_quality_exception_register.sql

docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -f /tmp/kloudkart_sql/04_diagnostics/02_scan_data_quality.sql
```

### Step 5: Populate the data-quality exception register

After installing the diagnostic table, function and scanner:

```powershell
docker exec kloudkart psql -U postgres -d kloud_kart -v ON_ERROR_STOP=1 -c "CALL scan_data_quality_exceptions();"
```

This scans the source tables and records detected exceptions without deleting or silently correcting the original records.

## 5. Implemented solutions

### Concurrent order placement

The `place_order()` function uses an atomic conditional stock update:

```sql
UPDATE products
SET stock_quantity = stock_quantity - p_quantity
WHERE product_id = p_product_id
  AND stock_quantity >= p_quantity
RETURNING price;
```

PostgreSQL row-level locking ensures competing transactions cannot both consume the same remaining stock.

The function also creates the order, order item and inventory movement within the same transaction.

### Customer spending analytics

The `customer_spending_report` view provides:

- Total customer spending.
- Number of eligible orders.
- Monthly spending.
- Cumulative monthly spending.
- Customer spending rank.
- Top-100 indicator.

### Inventory visibility and control

The inventory implementation provides:

- `low_stock_category_report`: low-stock products rolled up through category ancestors.
- `product_category_exceptions`: products assigned to missing or unreachable categories.
- `inventory_reconciliation_review`: inventory balances requiring reconciliation review.
- `adjust_inventory()`: controlled restocking and stock corrections with explanatory notes and corresponding inventory movements.

The adjustment function rejects zero quantity changes, invalid movement reasons, missing notes and adjustments that would produce negative stock.

### Data-quality exception monitoring

The diagnostic implementation provides:

- `data_quality_exceptions`: persistent exception register storing original row values as JSONB, issue types, detection timestamps, detection counts and investigation status.
- `record_data_quality_exception()`: records new exceptions and updates detection metadata when existing issues are detected again.
- `scan_data_quality_exceptions()`: scans source tables for identified data-quality problems and records the findings.

The register preserves the first captured source snapshot. It does not automatically resolve an exception when an issue disappears; resolution requires investigation.

## 6. Testing and performance evidence

### Concurrency testing

The supplied, unmodified `race_test.py` passed:

- 25/25 last-unit contention rounds.
- 400 simultaneous buyers competing for 50 units.
- Exactly 50 successful orders and 350 stock refusals.
- Zero overselling and zero errors.
- Five successful sales with five corresponding inventory movements in the audit test.

Flash-sale test execution time: **4.72 seconds**.

### Inventory adjustment testing

The `adjust_inventory()` function was tested inside a transaction that was rolled back:

- Restock of 5 units succeeded.
- Correction of -2 units succeeded.
- Excessive correction was rejected.
- NULL movement reason was rejected.
- Both successful movements were visible in the audit log during the test.
- Rollback restored the original stock and removed the temporary movements.

### Analytics performance

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

### Inventory validation

The restored dataset produced:

- 37 products with missing categories.
- 6 products in unreachable categories.
- 144 inventory reconciliation review exceptions.
- 521 low-stock products under Electronics.

## 7. Assumptions and limitations

- Eligible spending statuses are `completed`, `complete` and `shipped`. The business should confirm the treatment of cancelled, refunded and other status variants.
- The report generates 13 monthly labels, from the month containing the date 12 months ago through the current month. The first and last months may be partial.
- The reconciliation view is indicative because the supplied dataset does not establish a verified opening-stock balance.
- The inventory log does not contain a dedicated order ID column. The implemented order function records the order ID in the movement note.
- The stock protection CHECK constraint is initially `NOT VALID` because 14 historical products have negative stock. It enforces the constraint for new inserts and updates while those historical exceptions remain under investigation.
- The data-quality register records original snapshots and detection metadata; it is not a complete change-history system.
- Performance measurements reflect the supplied dataset and local Docker environment. They are not a production SLA.
- Category exceptions are reported rather than automatically corrected because appropriate category assignments require business validation.

## 8. Running the supplied concurrency test

From the project root, with the Python environment configured:

```powershell
python .\M03_Resources\race_test.py
```

The instructor's test script is used without modification.

## 9. Business outcome

The solution demonstrates safer order placement, customer analytics generated in seconds, hierarchical low-stock reporting, controlled inventory adjustments and persistent data-quality exception monitoring using the existing PostgreSQL environment.
