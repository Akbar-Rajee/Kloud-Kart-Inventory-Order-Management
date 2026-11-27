# ADR-003: Use recursive SQL for arbitrary-depth category rollups

- **Status:** Accepted
- **Date:** 2026-11-27
- **Decision owner:** Kloud Kart Data Engineering Project Team

## Context

Categories are nested three or four levels deep today, and new subcategories may be added. The low-stock report must roll up through the hierarchy without hardcoding its depth. The source hierarchy also contains missing-parent and cyclic references.

## Decision

Use a recursive CTE to traverse category parent-child relationships and carry a visited-path value to prevent revisiting a category in a cycle. Roll low-stock products up to their ancestors and expose broken hierarchy branches separately.

## Alternatives considered

### Alternative A: Hardcode the current category levels

- **How it would work:** Join category, parent, grandparent, and great-grandparent columns explicitly.
- **Why it is attractive:** Straightforward for a small, stable hierarchy.
- **Why rejected:** It fails when marketing adds a deeper level and does not meet the arbitrary-depth requirement.

### Alternative B: Maintain a closure table

- **How it would work:** Store all ancestor-descendant relationships and update them when categories change.
- **Why it is attractive:** Can make repeated hierarchy queries efficient.
- **Why rejected:** It adds write and maintenance complexity that is not justified by the supplied 94-category dataset.

## Consequences

- **What this buys:** New category depths can be handled without rewriting the query. Path tracking prevents infinite traversal through cycles.
- **What this costs:** The hierarchy is traversed when the report runs; malformed branches still require business review.
- **What it costs the client if I am wrong:** Low-stock products may be omitted or attributed to the wrong category, affecting replenishment decisions.
- **What would make me revisit this:** A much larger hierarchy, measured slow rollup performance, or frequent hierarchy changes that justify a maintained closure table.

## What this survives

The recursive design is depth-independent and includes cycle protection. The supplied dataset has 94 categories, with one missing parent reference and a two-category cycle. A timed low-stock rollup result was not retained, so the couple-of-seconds target remains unverified.
