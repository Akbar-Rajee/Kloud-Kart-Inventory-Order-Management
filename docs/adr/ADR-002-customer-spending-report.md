# ADR-002: Build the customer-spending report as a windowed SQL view

- **Status:** Accepted
- **Date:** 2026-11-27
- **Decision owner:** Kloud Kart Data Engineering Project Team

## Context

The assignment describes a weekly customer-spending report that takes about 40 minutes and requires customer totals, order counts, monthly spend for the trailing year, a per-customer running total, and a top-100 ranking. The report must run in seconds on the existing database.

## Decision

Create `customer_spending_report` using SQL aggregation, a generated month series, customer-month rows, and window functions for running totals and ranking. Retain customers with no eligible orders.

## Alternatives considered

### Alternative A: Calculate the report in application code

- **How it would work:** Fetch source rows and calculate customer totals, months, running totals, and ranks outside the database.
- **Why it is attractive:** Logic could be implemented in a general-purpose programming language.
- **Why rejected:** It moves large data volumes out of PostgreSQL and duplicates business logic outside the system of record.

### Alternative B: Maintain a summary table or materialized view immediately

- **How it would work:** Precompute customer/month aggregates and refresh or update them as source data changes.
- **Why it is attractive:** Repeated report reads could be faster.
- **Why rejected:** It adds refresh scheduling, freshness, and maintenance decisions. The measured view execution was already about 1.90 seconds in the test environment.

## Consequences

- **What this buys:** The required totals, counts, monthly spend, running totals, and ranking are calculated close to the source data. The report returned 525,460 rows for 40,420 customers across 13 month labels in approximately 1.90 seconds in the recorded execution plan.
- **What this costs:** Each query computes results from source data; repeated runs still consume database resources. The current output includes 13 labels with partial boundary months.
- **What it costs the client if I am wrong:** Incorrect status or date-window assumptions could misstate customer spend and ranking; a view may become too slow as data grows.
- **What would make me revisit this:** Confirmed business definitions, materially larger data volumes, or production measurements showing repeated report execution is too costly.

## What this survives

The recorded test-environment execution plan completed in approximately 1.90 seconds. Top-100 validation returned 100 distinct customers and 1,300 customer-month rows. The result is not a production SLA or a controlled same-hardware before/after benchmark.
