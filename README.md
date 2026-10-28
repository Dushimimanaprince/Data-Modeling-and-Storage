# Healthcare Analytics Lab: OLTP to Star Schema

Data Modeling and Storage — AmaliTech Data Engineering

## Overview

HealthTech Analytics runs a normalized (3NF) transactional database for clinical operations.
Analytical queries against it are slow. This project:

1. Analyzes the OLTP schema and measures the performance of four business queries.
2. Designs and builds an optimized star schema.
3. Defines the ETL process from OLTP to the star schema.
4. Compares performance and reflects on the trade-offs.

## Tech stack

- PostgreSQL 18 (pgAdmin 4)
- The original lab DDL was written in MySQL syntax; it has been adapted to PostgreSQL
  (inline `INDEX` → `CREATE INDEX`, `DATETIME` → `TIMESTAMP`).

## Database layout

One database, `healthcare_analytics`, with two schemas:

| Schema | Purpose |
|---|---|
| `oltp` | Normalized 3NF source system (10 tables) |
| `star` | Dimensional model for analytics (added later) |

## Project structure

```
.
├── README.md
├── sql/
│   └── oltp/      # OLTP schema and data scripts
└── docs/          # Lab deliverables
```

## Deliverables

| File | Status |
|---|---|
| `query_analysis.txt` | Pending |
| `design_decisions.txt` | Pending |
| `star_schema.sql` | Pending |
| `star_schema_queries.txt` | Pending |
| `etl_design.txt` | Pending |
| `reflection.md` | Pending |