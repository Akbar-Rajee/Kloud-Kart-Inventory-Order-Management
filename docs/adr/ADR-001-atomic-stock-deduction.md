# ADR-001: Use an atomic conditional update to prevent overselling

- **Status:** Accepted
- **Date:** 2026-11-27
- **Decision owner:** Kloud Kart Data Engineering Project Team

## Context

Two customers can attempt to buy the final unit at nearly the same time. A read-then-update sequence can allow both sessions to see the same available stock before either writes the deduction. The brief also expects flash-sale bursts of approximately 400 orders in ten seconds for one product.

## Decision

Use a conditional `UPDATE` inside `place_order()` that deducts stock only when the requested quantity is available. Create the order, order item, and sale movement in the same transaction.

## Alternatives considered

### Alternative A: Read stock, then update it

- **How it would work:** Read the current quantity into the application or function, check it, then issue a separate update.
- **Why it is attractive:** Easy to understand and implement.
- **Why rejected:** Concurrent sessions can both read the same last unit before either update commits, creating an oversell race.

### Alternative B: Trigger-only stock validation

- **How it would work:** Add a trigger to check stock during order-item insertion.
- **Why it is attractive:** Centralizes a rule in the database and can protect multiple callers.
- **Why rejected:** A trigger does not automatically make an unsafe read-then-update sequence concurrency-safe. Correct atomic update or locking logic is still required.

## Consequences

- **What this buys:** The product row is locked during the update. A waiting transaction rechecks the condition; if stock is exhausted, it updates no row and receives an out-of-stock result. Related order and movement writes roll back with the transaction if a later step fails.
- **What this costs:** Concurrent orders for the same product may wait on the same row. The function and its transaction boundaries must be used consistently by callers.
- **What it costs the client if I am wrong:** Kloud Kart could still oversell, creating refunds, customer complaints, and inventory discrepancies.
- **What would make me revisit this:** Production lock-wait or latency measurements, changes to isolation level, or a materially different order-write path.

## What this survives

The unmodified supplied race test passed 25/25 last-unit rounds. In the recorded flash-sale scenario, 400 buyers competed for 50 units: 50 succeeded, 350 were refused, no overselling or unexpected errors occurred, and the test completed in approximately 4.72 seconds. This is evidence for the supplied test scenario, not a guarantee for every production workload.
