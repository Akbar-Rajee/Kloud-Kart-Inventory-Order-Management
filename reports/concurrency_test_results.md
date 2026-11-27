# Concurrency Test Results — Kloud Kart

## Objective

Verify that the `place_order()` PostgreSQL function prevents overselling under concurrent purchase attempts and maintains an auditable inventory movement trail.

## Test environment

- Host snapshot: Windows 11 Business 10.0.26300, Intel Core i7-10510U, 31.3 GiB RAM
- Docker Engine: 29.9.3
- Database image: `postgres:18@sha256:eece53c7c4410fb9c6556a19b8e0f2d61708a5893e2aa0a1e3c716661374ab18`
- Test-runner image: `python:3.12-slim@sha256:191083cdf6c7bda8c76158983163ead5d5cf7b77cf3033e805bb0f5296f51b4b`
- Dependency pin for reruns: `psycopg2-binary==2.9.13` in `requirements.txt`
- Test script: Original instructor-provided `race_test.py`
- Test modifications: None

## Results

| Test | Result |
|---|---|
| Two buyers competing for one unit, repeated 25 times | Passed: exactly one winner in every round |
| 400 buyers competing for 50 units | Passed: 50 sold, 350 refused, 0 errors |
| Request exceeding available stock | Passed: request refused and stock unchanged |
| Inventory movement after successful purchases | Passed: 5 successful sales and 5 movements recorded |

## Canonical performance observation

The latest full-suite run, recorded on 2026-11-27, completed the 400-buyer flash-sale test in **3.53 seconds**.

Earlier runs measured 3.16, 3.65 and 4.72 seconds. Their detailed environment and driver versions were not captured, so 3.53 seconds is the sole canonical figure and the earlier values are historical observations only. The 3.53-second run installed `psycopg2-binary` without a version pin; the requirements file now pins the driver for future reruns.

## Conclusion

The `place_order()` function passed all four instructor-provided tests without modifying the test script.

The conditional stock update prevents concurrent transactions from selling more units than are available. The function also records the order, order item, and inventory movement as part of the same transaction.

These results demonstrate correctness under the supplied concurrency workload. They are not a guarantee of identical performance under every production workload.
