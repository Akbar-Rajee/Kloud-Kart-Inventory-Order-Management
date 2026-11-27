# ADR-005: Enforce nonnegative stock for new changes without rejecting historical exceptions

- **Status:** Accepted
- **Date:** 2026-11-27
- **Decision owner:** Kloud Kart Data Engineering Project Team

## Context

The desired stock rule is that product stock must not become negative. However, the supplied source data already contains 14 negative stock balances. A normally validated constraint would fail while those historical rows remain.

## Decision

Add a `CHECK (stock_quantity >= 0) NOT VALID` constraint. Preserve existing negative balances for investigation while requiring new inserts and updates to satisfy the rule.

## Alternatives considered

### Alternative A: Correct or delete historical negative rows before adding the constraint

- **How it would work:** Change negative values to zero or another inferred quantity, then add a validated constraint.
- **Why it is attractive:** Produces a fully validated constraint immediately.
- **Why rejected:** The correct historical balances are unknown. Guessing would alter operational history and could make stock less accurate.

### Alternative B: Do not add a database constraint

- **How it would work:** Rely only on application logic and the order function.
- **Why it is attractive:** No schema change and no historical exception handling.
- **Why rejected:** Other write paths could still introduce negative stock.

## Consequences

- **What this buys:** PostgreSQL rejects new writes that violate the nonnegative rule while existing negative rows remain available for review.
- **What this costs:** The constraint remains unvalidated until the 14 historical exceptions are resolved. The team must track that outstanding validation step.
- **What it costs the client if I am wrong:** A faulty correction or overlooked write path could leave stock values inaccurate or permit invalid changes.
- **What would make me revisit this:** Completion of the historical stock investigation, after which the constraint should be validated; or a revised business rule for stock adjustments.

## What this survives

A test attempted to set stock to -999 and PostgreSQL rejected the update. The transaction was rolled back. Historical negative values remain and the constraint has not yet been validated.
