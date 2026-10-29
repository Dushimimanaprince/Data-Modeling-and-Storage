# Healthcare Analytics Lab: OLTP to Star Schema

Data Modeling and Storage — AmaliTech Data Engineering

## Overview

HealthTech Analytics runs a normalized (3NF) transactional database for clinical operations, and analytical queries against it are slow. This project:

1. Measures four business queries on the OLTP schema and identifies the bottlenecks.
2. Designs and builds a star schema (Kimball dimensional model).
3. Loads it with a SQL-based ETL and validates it against the source.
4. Compares performance and reflects on the trade-offs.

## Tech stack

- PostgreSQL 18, pgAdmin 4
- The lab's original DDL was MySQL syntax and was adapted to PostgreSQL (inline `INDEX` → `CREATE INDEX`, `DATETIME` → `TIMESTAMP`).

## Database layout

One database, `healthcare_analytics`, with two schemas:

| Schema | Contents |
|---|---|
| `oltp` | Normalized 3NF source: 10 tables |
| `star` | Star schema: 8 dimensions, `fact_encounters`, 2 bridge tables |

**Star schema**

- Fact: `fact_encounters`, grain = one row per encounter, with pre-aggregated billing totals, diagnosis/procedure counts, length of stay and a 30-day readmission flag
- Dimensions: `dim_date`, `dim_patient` (SCD1), `dim_provider` (SCD2), `dim_specialty`, `dim_department`, `dim_encounter_type`, `dim_diagnosis`, `dim_procedure`
- Bridges: `bridge_encounter_diagnoses`, `bridge_encounter_procedures`

## Data volume

Lab sample data plus a reproducible synthetic dataset (`setseed(0.42)`):

| Table | Rows |
|---|---|
| patients | 50,003 |
| providers | 203 |
| encounters | 500,004 |
| encounter_diagnoses | 1,249,110 |
| encounter_procedures | 749,536 |
| billing | 424,535 |

## Project structure

```
.
├── README.md
├── docs/
│   ├── query_analysis.txt          # Part 2: OLTP query performance analysis
│   ├── design_decisions.txt        # Part 3.1: grain, dimensions, metrics, bridges
│   ├── star_schema_queries.txt     # Part 3.3: optimized queries + comparison
│   ├── etl_design.txt              # Part 3.4: ETL logic and refresh strategy
│   └── reflection.md               # Part 4: analysis and reflection
└── sql/
    ├── oltp/
    │   ├── 01_create_oltp_schema.sql
    │   ├── 02_load_sample_data.sql
    │   └── 03_generate_synthetic_data.sql
    ├── oltp_queries/                # Part 2: the 4 business queries on OLTP
    │   ├── q1_monthly_encounters_by_specialty.sql
    │   ├── q2_top_diagnosis_procedure_pairs.sql
    │   ├── q3_readmission_rate_by_specialty.sql
    │   └── q4_revenue_by_specialty_month.sql
    ├── star/
    │   └── star_schema.sql          # Part 3.2: star schema DDL
    ├── etl/
    │   ├── 01_load_dimensions.sql
    │   ├── 02_load_fact_encounters.sql
    │   ├── 03_load_bridges.sql
    │   └── 04_validate_load.sql
    └── star_queries/                # Part 3.3: the 4 queries on the star schema
        ├── q1_monthly_encounters_by_specialty.sql
        ├── q2_top_diagnosis_procedure_pairs.sql
        ├── q3_readmission_rate_by_specialty.sql
        └── q4_revenue_by_specialty_month.sql
```

## How to run

1. In pgAdmin, create the database `healthcare_analytics` and open a Query Tool on it.
2. Run the scripts in this order:

| Step | Script | Approx. time |
|---|---|---|
| 1 | `sql/oltp/01_create_oltp_schema.sql` | < 1 s |
| 2 | `sql/oltp/02_load_sample_data.sql` | < 1 s |
| 3 | `sql/oltp/03_generate_synthetic_data.sql` | 1–3 min |
| 4 | `sql/oltp_queries/q1` … `q4` | seconds each |
| 5 | `sql/star/star_schema.sql` | < 1 s |
| 6 | `sql/etl/01_load_dimensions.sql` | seconds |
| 7 | `sql/etl/02_load_fact_encounters.sql` | 1–2 min |
| 8 | `sql/etl/03_load_bridges.sql` | 1–2 min |
| 9 | `sql/etl/04_validate_load.sql` | all 14 checks should be PASS |
| 10 | `sql/star_queries/q1` … `q4` | sub-second |

All scripts are re-runnable. Steps 1 and 5 drop and recreate their schema.

To measure a query, prefix it with `EXPLAIN (ANALYZE, BUFFERS)` and take the median `Execution Time` of three runs.

## Results

| Query | OLTP | Star | Improvement |
|---|---|---|---|
| Q1 Monthly encounters by specialty | [Q1] ms | [S1] ms | [x]× |
| Q2 Top diagnosis–procedure pairs | [Q2] ms | [S2] ms | [x]× |
| Q3 30-day readmission rate | [Q3] ms | [S3] ms | [x]× |
| Q4 Revenue by specialty and month | [Q4] ms | [S4] ms | [x]× |

Details in `docs/star_schema_queries.txt` and `docs/reflection.md`.

## Deliverables

| File | Description |
|---|---|
| `docs/query_analysis.txt` | 4 OLTP queries with performance analysis |
| `docs/design_decisions.txt` | Star schema design choices |
| `sql/star/star_schema.sql` | Complete star schema DDL |
| `docs/star_schema_queries.txt` | 4 optimized queries with performance comparison |
| `docs/etl_design.txt` | ETL logic and refresh strategy |
| `docs/reflection.md` | Analysis and reflection |