# Concurrency Test Results — Kloud Kart

## Objective

Verify that the `place_order()` PostgreSQL function prevents overselling under concurrent purchase attempts and maintains an auditable inventory movement trail.

## Test environment

- Database: PostgreSQL 18
- Application language: Python
- Database driver: psycopg2 2.9.13
- Test script: Original instructor-provided `race_test.py`
- Test modifications: None

## Results

| Test | Result |
|---|---|
| Two buyers competing for one unit, repeated 25 times | Passed: exactly one winner in every round |
| 400 buyers competing for 50 units | Passed: 50 sold, 350 refused, 0 errors |
| Request exceeding available stock | Passed: request refused and stock unchanged |
| Inventory movement after successful purchases | Passed: 5 successful sales and 5 movements recorded |

## Performance observation

The 400-buyer flash-sale test completed in 3.16 seconds during the full test-suite run.

A separate execution completed in 3.65 seconds. The README and ADR also record another execution at 4.72 seconds. These are three distinct observed runs, not conflicting measurements.

## Conclusion

The `place_order()` function passed all four instructor-provided tests without modifying the test script.

The conditional stock update prevents concurrent transactions from selling more units than are available. The function also records the order, order item, and inventory movement as part of the same transaction.

These results demonstrate correctness under the supplied concurrency workload. They are not a guarantee of identical performance under every production workload.
