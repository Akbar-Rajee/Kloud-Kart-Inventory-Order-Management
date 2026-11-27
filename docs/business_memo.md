# Business Memo

**To:** Nana Adjei, Operations Manager
**From:** Kloud Kart Data Engineering Project Team
**Date:** 27 November 2026
**Subject:** Improving Order Reliability, Inventory Visibility and Customer Reporting

## Executive Summary

Kloud Kart's existing PostgreSQL database can support safer order processing, faster customer-spending reports, improved inventory visibility and more traceable stock movements without purchasing new infrastructure or replacing the existing database.

The implemented solution addresses the main operational requirements and has passed the supplied concurrency test. It also introduces persistent data-quality monitoring so historical problems can be investigated rather than silently ignored.

## What Has Improved

### 1. Safer flash-sale orders

The new order-processing function prevents competing buyers from successfully purchasing the same remaining stock.

In the latest recorded supplied test, 400 buyers competed for 50 units: exactly 50 orders succeeded, 350 were refused, and no overselling occurred. The canonical observed duration was 3.53 seconds; the environment details are recorded in `reports/concurrency_test_results.md`.

### 2. Faster customer-spending reporting

The customer-spending report completed in approximately 1.90 seconds in the test environment, returning 525,460 customer-month rows.

It provides total spend, eligible order count, monthly spend, cumulative spend, spending rank and a top-100 indicator.
For Adwoa's exact trailing-12-month figure, use `trailing_12_month_spend`; the monthly columns are a breakdown across 13 calendar-month labels, including partial boundary months.

### 3. Better low-stock visibility

A recursive category report rolls low-stock products up through parent categories. It accommodates changing category hierarchy depths rather than relying on a fixed number of levels.

### 4. More controlled inventory movements

Sales, restocking and stock corrections are supported by database functions that update stock and record the corresponding inventory movement within the same transaction.

The adjustment function restricts movement reasons, requires explanatory notes and rejects adjustments that would create negative stock. This improves accountability for inventory changes.

### 5. Persistent data-quality monitoring

A data-quality exception register records detected issues, affected source records, original-value snapshots, detection timestamps, repeat detection counts and investigation status.

The latest scanner results recorded **377,647 open exception records across 15 issue types**, representing 1,130,662 cumulative detections across repeated scans.

Important findings include:

- 14 products with negative stock.
- 692 order items referencing missing orders.
- 210 orders referencing missing customers.
- 120 inventory movements referencing missing products.
- 148 order items with missing unit prices.
- 90,900 orders with status-formatting variations.
- 281,927 inventory records without explanatory notes.
- 2,279 order-total mismatches.

These findings are recorded for investigation. They have not all been automatically corrected because doing so without business confirmation could damage valid historical records.

## Risks Requiring Management Attention

The database contains historical integrity issues that affect confidence in inventory balances, transaction relationships and financial reporting.

Inventory reconciliation also requires a verified opening-stock balance before differences can be treated as confirmed errors.

Some apparent exceptions may have legitimate explanations. Duplicate email addresses do not necessarily represent duplicate customers; zero-priced items may be promotions or free gifts; and large quantities may represent genuine bulk orders.

## Decisions Requested

1. Before production use, approve or replace the project's explicit reporting policy: `completed`, `complete` and `shipped` count as eligible spend; all other statuses are excluded.
2. Confirm the treatment of cancelled, refunded and zero-priced orders before changing the project policy.
3. Approve investigation of negative stock and orphaned transaction records before historical corrections are applied.
4. Confirm opening inventory balances so reconciliation differences can be assessed accurately.
5. Consider adding a dedicated order reference column to the inventory log to strengthen audit traceability.

## Recommendation

Adopt the new order-processing, reporting and controlled inventory functions following deployment validation.

Use the persistent exception register to prioritize data-cleanup investigations, and monitor concurrency and reporting performance as order volumes grow.

**Limitations and assurance:** We cannot yet personally certify the accuracy of historical stock balances or every historical transaction. The original opening-stock position is unknown, and several historical data exceptions remain unresolved. The reported tests demonstrate the behaviour of the implemented functions under the supplied test conditions; they do not constitute an independent audit of all historical business records.

The solution provides practical operational improvements using the existing PostgreSQL environment while making unresolved data risks and business assumptions visible.
