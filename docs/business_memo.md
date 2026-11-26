# Business Memo

**To:** Nana Adjei, Operations Manager
**From:** Kloud Kart Data Engineering Project Team
**Date:** 26 November 2026
**Subject:** Improving Order Reliability, Inventory Visibility and Customer Reporting

## Executive summary

Kloud Kart's existing PostgreSQL database can support safer order processing, faster customer-spending reports, improved inventory visibility and more traceable stock movements without purchasing new infrastructure or replacing the existing database.

The implemented solution addresses the main operational requirements and has passed the supplied concurrency test.

## What has improved

### 1. Safer flash-sale orders

The new order-processing function prevents competing buyers from successfully purchasing the same remaining stock. In the supplied test, 400 buyers competed for 50 units: exactly 50 orders succeeded, 350 were refused, and no overselling occurred. The test completed in approximately 4.72 seconds.

### 2. Faster customer-spending reporting

The customer-spending report completed in approximately 1.90 seconds in the test environment, returning 525,460 customer-month rows. It provides total spend, eligible order count, monthly spend, cumulative spend, spending rank and a top-100 indicator.

### 3. Better low-stock visibility

A recursive category report rolls low-stock products up through parent categories. It accommodates changing category hierarchy depths rather than relying on a fixed number of levels.

### 4. More controlled inventory movements

Sales, restocking and stock corrections are supported by database functions that update stock and record the corresponding inventory movement within the same transaction.

The adjustment function restricts movement reasons, requires explanatory notes and rejects adjustments that would create negative stock. This improves accountability for inventory changes.

### 5. Persistent data-quality monitoring

A data-quality exception register records detected issues, the affected source record, an original-value snapshot, detection timestamps, repeat detection counts and investigation status.

This gives the operations team a persistent list of issues to investigate instead of relying only on temporary query results. Exceptions are not automatically marked as resolved when an issue disappears.

## Risks requiring management attention

The supplied data contains negative stock balances, missing customer and order references, missing prices, inconsistent order statuses, duplicate normalized email addresses and category hierarchy defects.

These historical issues have been identified and recorded for review. They have not all been automatically corrected because doing so without business confirmation could damage valid records.

Inventory reconciliation also requires a verified opening-stock balance before differences can be treated as confirmed errors.

## Decisions requested

1. Confirm which order statuses count as eligible customer spend, particularly whether `shipped` should be included.
2. Confirm the treatment of cancelled, refunded and zero-priced orders.
3. Approve investigation of negative stock and orphaned transaction records before historical corrections are applied.
4. Confirm opening inventory balances so reconciliation differences can be assessed accurately.
5. Consider adding a dedicated order reference column to the inventory log to strengthen audit traceability.

## Recommendation

Adopt the new order-processing, reporting and controlled inventory functions following deployment validation. Use the persistent exception register to prioritize data-cleanup investigations, and monitor concurrency and reporting performance as order volumes grow.

The solution provides practical operational improvements using the existing PostgreSQL environment while making unresolved data risks and business assumptions visible.
