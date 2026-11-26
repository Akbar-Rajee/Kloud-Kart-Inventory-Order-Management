# Business Memo

**To:** Nana Adjei, Operations Manager  
**From:** Kloud Kart Data Engineering Project Team  
**Date:** 25 November 2026  
**Subject:** Improving Order Reliability, Inventory Visibility and
Customer Reporting

## Executive summary

Kloud Kart’s PostgreSQL database can support safer order processing,
faster customer-spending reports, improved stock visibility and a more
traceable inventory process without purchasing new infrastructure or
replacing the existing database.

The implemented solution addresses the key operational requirements and
has passed the supplied concurrency test.

## What has improved

### 1. Safer flash-sale orders

The new order-processing function prevents two buyers from successfully
purchasing the same final unit. In the supplied test, 400 buyers
competed for 50 units: exactly 50 orders succeeded, 350 were refused,
and no overselling occurred. The test completed in approximately 4.72
seconds.

### 2. Faster customer-spending reporting

The customer-spending report completed in approximately 1.90 seconds on
the test environment, returning 525,460 customer-month rows. It includes
total spend, eligible order count, monthly spend, cumulative spend,
spending rank and a top-100 flag.

### 3. Better low-stock visibility

A recursive category report rolls low-stock products up through parent
categories. It does not depend on a fixed hierarchy depth, so additional
category levels can be accommodated.

### 4. Improved inventory traceability

Successful sales create inventory movement records within the same
transaction as the order. Additional exception views highlight category
and stock-reconciliation issues that need investigation.

## Risks requiring management attention

The original data contains negative stock balances, missing customer and
order references, missing prices, inconsistent order statuses and
category hierarchy defects.

These historical issues have been identified and exposed for review, but
they have not all been automatically corrected. Incorrect automatic
corrections could damage valid business records.

## Decisions requested

1.  Confirm which order statuses count as eligible customer spend,
    particularly whether `shipped` should be included.
2.  Confirm the intended treatment of cancelled, refunded and
    zero-priced orders.
3.  Approve an investigation of negative stock and orphaned transaction
    records before historical corrections are applied.
4.  Consider adding a dedicated order reference to the inventory log to
    strengthen audit traceability.

## Recommendation

Adopt the new order-processing function and reporting views after
deployment validation. Use the exception reports to guide a controlled
data-cleanup exercise, and monitor concurrency and reporting performance
as order volumes grow.

The solution provides a practical improvement using the existing
PostgreSQL environment while making remaining data risks and business
assumptions visible.
