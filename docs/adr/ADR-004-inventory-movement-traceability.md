# ADR-004: Record stock movements in the order and adjustment transactions

- **Status:** Accepted
- **Date:** 2026-11-27
- **Decision owner:** Kloud Kart Data Engineering Project Team

## Context

The business needs an auditable trail of sales, restocks, and corrections. The supplied inventory log is incomplete: 281,927 of 282,352 rows have no note, and the source schema has no dedicated order reference in the movement table.

## Decision

Write each successful sale movement in the same transaction as its order and order item. Provide a controlled inventory adjustment function for restocks and corrections, and expose a reconciliation review rather than automatically rewriting historical stock.

## Alternatives considered

### Alternative A: Update stock without writing a movement

- **How it would work:** Change the product quantity and rely on the current stock value.
- **Why it is attractive:** Fewer writes and less code.
- **Why rejected:** It loses the history needed to explain why stock changed.

### Alternative B: Repair all historical movements automatically

- **How it would work:** Infer missing notes and movements from current balances and available rows.
- **Why it is attractive:** Could make historical records appear more complete.
- **Why rejected:** The opening stock balance and missing business context are unknown. Invented movements could create a false audit trail.

## Consequences

- **What this buys:** New sales and controlled adjustments create movement records with reasons and notes. A failed order transaction rolls back its corresponding movement.
- **What this costs:** Each stock change adds a write. The existing log lacks a dedicated `order_id`, so the generated order ID is stored in the note.
- **What it costs the client if I am wrong:** Missing or incorrect movement records can make stock reconciliation and audit investigations unreliable.
- **What would make me revisit this:** A schema migration adding a proper order/transaction reference, or evidence that movement writes materially affect order latency.

## What this survives

The supplied concurrency test verified movement records after contention. Historical reconciliation identifies 144 products for review under a zero-opening-balance assumption. Because true opening balances are unknown, these mismatches are not treated as confirmed errors.
