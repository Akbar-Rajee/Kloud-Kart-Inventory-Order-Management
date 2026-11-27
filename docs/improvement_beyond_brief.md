# Improvement Beyond the Brief: Persistent Data Quality Exception Register

## What I added

Beyond the four core business requirements, I implemented a **persistent
Data Quality Exception Register** in:

`sql/04_diagnostics/02_scan_data_quality.sql`

The register turns data-quality checks into an ongoing operational
control. Instead of producing a one-off list of suspicious records that
can be lost or forgotten, it stores detected exceptions so the team can
investigate them, track repeat occurrences, and record their resolution.

## How it works

The scanner checks the source data for a range of integrity and
consistency problems. Detected exceptions are written to the
`data_quality_exceptions` table and retained between scans.

The register supports:

-   **Persistent tracking:** exceptions remain available after a scan
    finishes.
-   **Repeat-detection counts:** repeated findings update the existing
    exception rather than creating an identical duplicate on every run.
-   **First- and last-detected timestamps:** the team can see when an
    issue first appeared and when it was most recently observed.
-   **Investigation workflow:** exception status and resolution details
    can be maintained as issues are reviewed.
-   **Structured evidence:** issue details are retained in structured
    data, making it easier to inspect and report on findings.

The scanner uses a bulk insert/upsert approach to process findings
efficiently. This avoids a slow row-by-row write pattern and makes
repeat scans more practical.

## Evidence from this project

The completed scan recorded:

-   **377,647** exception records.
-   **15** issue types with findings.
-   **1,130,662** cumulative detections.
-   **Zero duplicate exception records** after the scan.

The optimized scan completed in approximately **13 seconds** in the
recorded test environment. Runtime will vary with hardware, database
load, and data volume.

These figures describe the supplied project dataset and test
environment; they are not a guarantee of production performance.

## Why this matters to Kloud Kart

Without a persistent register, data problems can be rediscovered
repeatedly without anyone knowing whether they are new, recurring, or
already being investigated. This creates avoidable work and makes it
harder to establish whether data quality is improving.

The register gives the data and operations teams a shared record of what
was found and what still needs attention. It helps them:

1.  Prioritize serious issues instead of repeatedly inspecting the same
    raw records.
2.  Identify recurring problems and distinguish them from newly detected
    ones.
3.  Track investigation and resolution rather than losing findings
    between runs.
4.  Build a more defensible audit trail of data-quality checks and
    follow-up.

For Nana, this means better visibility of risks that can affect stock,
orders, customer reporting, and operational decisions. For the analyst,
it means less repeated manual investigation and a clearer queue of
exceptions to review.

## Limitations and recommended next step

The register records and organizes findings; it does **not**
automatically correct the underlying source data. An exception should be
reviewed before any correction is applied, especially where historical
records or financial totals may be affected.

The next step I recommend is to assign an owner and target resolution
date to high-risk exception types, then review unresolved counts and
recurring detections on a regular schedule. This turns the register into
a practical data-quality management process rather than just a technical
log.

## Why this qualifies as an improvement beyond the brief

The assignment asks for diagnosis and documentation of data problems.
This implementation goes further by adding a reusable, persistent
mechanism for tracking those problems across repeated scans and
supporting investigation through to resolution. It provides ongoing
operational value after the initial project handover.
