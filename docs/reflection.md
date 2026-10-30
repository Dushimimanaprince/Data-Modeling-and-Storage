# Reflection: OLTP vs Star Schema for Healthcare Analytics

## 1. Why is the star schema faster?

**Joins.** In the normalized schema, the attributes analysts group by live far from the events they measure. Revenue by specialty needed `billing → encounters → providers → specialties` (3 joins across two large tables), and the readmission question needed a self-join of the 500K-row `encounters` table. In the star schema every join goes from the fact table straight to a small dimension (10 to ~4,000 rows) on an integer key. The number of joins is not always lower (star Q1 still uses three), but they are short, cheap joins instead of long chains through large tables.

**Pre-computed data.** The biggest gains came from work moved out of the query and into the ETL:

- Billing totals (`total_claim_amount`, `total_allowed_amount`, `claim_count`) are summed once per encounter, so Q4 never touches the 425K-row `billing` table.
- The 30-day readmission relationship is evaluated once and stored as `is_readmission_30d`, so Q3 becomes `SUM / COUNT` instead of a range self-join over ~1.1M same-patient pairs.
- Diagnosis and procedure counts, length of stay and age at encounter are stored on the fact.
- `dim_date` stores the month, quarter and year, replacing `DATE_TRUNC` on every row.

**Why denormalization helps analytics.** Analytical queries read many rows and few columns, then aggregate. Copying specialty onto the fact (`specialty_key`) and specialty/department names into `dim_provider` removes lookups that would otherwise repeat for every row on every run. Because the encounter grain is clearly defined, most `COUNT(DISTINCT)` operations disappear too: one row is one encounter, so `COUNT(*)` is already correct. Those distinct sorts were among the most expensive steps in the OLTP plans, and they spilled to disk.

## 2. Trade-offs: what did I gain, what did I lose?

**Lost / gave up:**

- **Duplication.** Specialty and department names are stored in several places, billing totals exist both in `oltp.billing` and on the fact, and the extra indexes add more. In a test with the same data, the star schema took about 370 MB (tables + indexes) versus about 230 MB for the OLTP source, so total storage more than doubled.
- **ETL complexity.** I had to write and maintain four load scripts, SCD Type 2 logic for providers, unknown members, upserts and 14 validation checks. The OLTP schema needs none of this.
- **Freshness.** The star schema is only as current as the last load (daily in my design). Late-arriving claims and return visits require reprocessing a rolling window.
- **Flexibility for new questions.** Pre-computed metrics answer known questions. A new definition of readmission (e.g. inpatient-only returns) means changing the ETL and reloading, not just editing a query.

**Gained:**

- Faster queries: about 5–16× for Q2–Q4 (see section 4).
- Simpler SQL: Q3 went from a self-join with three `COUNT(DISTINCT CASE ...)` expressions to a plain `SUM / COUNT`.
- Consistency: the readmission rule and revenue totals are defined once in the ETL, so every report uses the same logic. Validation proved the star totals match the source to the cent.
- History: SCD Type 2 keeps an encounter attributed to the specialty its provider had at the time, which the OLTP schema (current state only) cannot do.
- The OLTP system is no longer burdened by heavy reporting queries.

**Was it worth it?** Yes, for queries that are run repeatedly by many users, which is the normal case for hospital reporting. The ETL cost is paid once per night; the query savings are earned on every run. The exception is Q1: "unique patients" is non-additive and cannot be pre-computed at encounter grain, so it improved only about 2.7×. A naive star version of Q1 was even slower than OLTP in an earlier test, because the fact table is wider than `encounters` and the distinct sort remained. The schema alone does not guarantee speed; query shape (aggregate on integer keys first, attach names last) matters too.

## 3. Bridge tables: worth it?

**Why keep diagnoses and procedures in bridges instead of the fact?** An encounter has a variable number of diagnoses (1–4 here) and procedures (0–3). Putting them on the fact would either break the grain (one row per diagnosis, which duplicates billing amounts and inflates revenue sums) or break 1NF (`diagnosis_1`, `diagnosis_2`, … columns with a fixed limit). Bridges keep the fact at a clean encounter grain while preserving full clinical detail. Q1, Q3 and Q4 never touch them.

**The trade-off.** Questions that need the detail still pay for it. Q2 joins two bridges, and the per-encounter explosion (N diagnoses × M procedures → 1.87M rows) still happens. It got ~11.5× faster because the bridge keys are narrow integers and their primary keys make `COUNT(DISTINCT)` unnecessary, but the explosion itself is inherent to the question. Bridges also add a correctness risk: summing fact measures after joining a bridge double-counts money, so users must aggregate first.

**In production I would** keep the bridges, keep the hybrid `primary_diagnosis_key` on the fact for the most common filter, and add a small aggregate table (diagnosis × procedure × month with encounter counts) refreshed by the ETL if Q2-style questions were frequent. I would also load bridges incrementally per encounter batch instead of truncating them nightly.

## 4. Performance quantification

Measured with `sql/benchmark/run_benchmark.sql` (`EXPLAIN ANALYZE`, 1 warm-up + 3 runs, median), 500K encounters, PostgreSQL 18.

| Query | Original (OLTP) | Optimized (star) | Improvement | Main reason for the speedup |
|---|---|---|---|---|
| Q4 Revenue by specialty & month | 3,504 ms | 219 ms | 16.0× | Billing pre-aggregated on the fact; 3-hop chain replaced by two one-hop joins; no distinct sort |
| Q3 Readmission rate | 716 ms | 141 ms | 5.1× | Self-join replaced by a pre-computed flag |
| Q2 Diagnosis–procedure pairs | 12,687 ms | 1,102 ms | 11.5× | No `COUNT(DISTINCT)`; grouping on narrow integer bridge keys |
| Q1 Monthly encounters | 4,273 ms | 1,600 ms | 2.7× | Integer grouping and date dimension; limited by non-additive unique patients |

Worked example (Q4): 3,504 ms / 219 ms = 16.0× faster. Worked example (Q2): 12,687 ms / 1,102 ms = 11.5× faster.

The OLTP plans for Q1, Q2 and Q4 spilled sorts to disk (~21 MB, ~102 MB and ~19 MB); none of the star queries did.

**Conclusion.** The star schema is fastest where expensive logic could be moved into the ETL (Q3, Q4) and where a clear grain removes `COUNT(DISTINCT)` (Q2). It helps least for inherently non-additive measures (Q1). This matches the core lesson of the lab: normalized models are designed for safe writes, dimensional models for fast and simple reads, and the cost of the second is paid in duplication and ETL work.