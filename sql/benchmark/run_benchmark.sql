DROP TABLE IF EXISTS benchmark_queries;
DROP TABLE IF EXISTS benchmark_runs;

CREATE TEMP TABLE benchmark_queries (
    query_no  INT,
    label     TEXT,
    model     TEXT,
    sql_text  TEXT
);

CREATE TEMP TABLE benchmark_runs (
    query_no      INT,
    model         TEXT,
    run_no        INT,
    execution_ms  NUMERIC,
    disk_sort_kb  BIGINT
);

INSERT INTO benchmark_queries (query_no, label, model, sql_text) VALUES
    (1, 'Q1 Monthly encounters by specialty', 'oltp', $q$
SELECT
    DATE_TRUNC('month', e.encounter_date)::date AS encounter_month,
    s.specialty_name,
    e.encounter_type,
    COUNT(*)                     AS total_encounters,
    COUNT(DISTINCT e.patient_id) AS unique_patients
FROM oltp.encounters e
JOIN oltp.providers   p ON p.provider_id  = e.provider_id
JOIN oltp.specialties s ON s.specialty_id = p.specialty_id
GROUP BY
    DATE_TRUNC('month', e.encounter_date)::date,
    s.specialty_name,
    e.encounter_type
ORDER BY
    encounter_month,
    s.specialty_name,
    e.encounter_type
$q$),
    (1, 'Q1 Monthly encounters by specialty', 'star', $q$
WITH patient_level AS (
    SELECT
        d.month_start_date,
        f.specialty_key,
        f.encounter_type_key,
        f.patient_key,
        SUM(f.encounter_count) AS encounters
    FROM star.fact_encounters f
    JOIN star.dim_date d ON d.date_key = f.encounter_date_key
    GROUP BY
        d.month_start_date,
        f.specialty_key,
        f.encounter_type_key,
        f.patient_key
),
monthly AS (
    SELECT
        month_start_date,
        specialty_key,
        encounter_type_key,
        SUM(encounters) AS total_encounters,
        COUNT(*)        AS unique_patients
    FROM patient_level
    GROUP BY
        month_start_date,
        specialty_key,
        encounter_type_key
)
SELECT
    TO_CHAR(m.month_start_date, 'YYYY-MM') AS year_month,
    s.specialty_name,
    t.encounter_type_name,
    m.total_encounters,
    m.unique_patients
FROM monthly m
JOIN star.dim_specialty      s ON s.specialty_key      = m.specialty_key
JOIN star.dim_encounter_type t ON t.encounter_type_key = m.encounter_type_key
ORDER BY
    year_month,
    s.specialty_name,
    t.encounter_type_name
$q$),
    (2, 'Q2 Top diagnosis-procedure pairs', 'oltp', $q$
SELECT
    d.icd10_code,
    d.icd10_description,
    pr.cpt_code,
    pr.cpt_description,
    COUNT(DISTINCT ed.encounter_id) AS encounter_count
FROM oltp.encounter_diagnoses  ed
JOIN oltp.encounter_procedures ep ON ep.encounter_id = ed.encounter_id
JOIN oltp.diagnoses            d  ON d.diagnosis_id  = ed.diagnosis_id
JOIN oltp.procedures           pr ON pr.procedure_id = ep.procedure_id
GROUP BY
    d.icd10_code,
    d.icd10_description,
    pr.cpt_code,
    pr.cpt_description
ORDER BY encounter_count DESC
LIMIT 20
$q$),
    (2, 'Q2 Top diagnosis-procedure pairs', 'star', $q$
WITH pair_counts AS (
    SELECT
        bd.diagnosis_key,
        bp.procedure_key,
        COUNT(*) AS encounter_count
    FROM star.bridge_encounter_diagnoses  bd
    JOIN star.bridge_encounter_procedures bp ON bp.encounter_key = bd.encounter_key
    GROUP BY
        bd.diagnosis_key,
        bp.procedure_key
)
SELECT
    dg.icd10_code,
    dg.icd10_description,
    pr.cpt_code,
    pr.cpt_description,
    pc.encounter_count
FROM pair_counts pc
JOIN star.dim_diagnosis dg ON dg.diagnosis_key = pc.diagnosis_key
JOIN star.dim_procedure pr ON pr.procedure_key = pc.procedure_key
ORDER BY pc.encounter_count DESC
LIMIT 20
$q$),
    (3, 'Q3 30-day readmission rate', 'oltp', $q$
SELECT
    s.specialty_name,
    COUNT(DISTINCT i.encounter_id) AS inpatient_discharges,
    COUNT(DISTINCT CASE WHEN r.encounter_id IS NOT NULL THEN i.encounter_id END) AS readmissions_30d,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN r.encounter_id IS NOT NULL THEN i.encounter_id END)
              / COUNT(DISTINCT i.encounter_id),
        2
    ) AS readmission_rate_pct
FROM oltp.encounters i
JOIN oltp.providers   p ON p.provider_id  = i.provider_id
JOIN oltp.specialties s ON s.specialty_id = p.specialty_id
LEFT JOIN oltp.encounters r
       ON r.patient_id     =  i.patient_id
      AND r.encounter_id   <> i.encounter_id
      AND r.encounter_date >  i.discharge_date
      AND r.encounter_date <= i.discharge_date + INTERVAL '30 days'
WHERE i.encounter_type = 'Inpatient'
GROUP BY s.specialty_name
ORDER BY readmission_rate_pct DESC
$q$),
    (3, 'Q3 30-day readmission rate', 'star', $q$
SELECT
    s.specialty_name,
    COUNT(*)                  AS inpatient_discharges,
    SUM(f.is_readmission_30d) AS readmissions_30d,
    ROUND(100.0 * SUM(f.is_readmission_30d) / COUNT(*), 2) AS readmission_rate_pct
FROM star.fact_encounters    f
JOIN star.dim_encounter_type t ON t.encounter_type_key = f.encounter_type_key
JOIN star.dim_specialty      s ON s.specialty_key      = f.specialty_key
WHERE t.is_inpatient
GROUP BY s.specialty_name
ORDER BY readmission_rate_pct DESC
$q$),
    (4, 'Q4 Revenue by specialty and month', 'oltp', $q$
SELECT
    DATE_TRUNC('month', e.encounter_date)::date AS encounter_month,
    s.specialty_name,
    COUNT(DISTINCT b.encounter_id) AS billed_encounters,
    SUM(b.claim_amount)            AS total_claim_amount,
    SUM(b.allowed_amount)          AS total_allowed_amount
FROM oltp.billing     b
JOIN oltp.encounters  e ON e.encounter_id = b.encounter_id
JOIN oltp.providers   p ON p.provider_id  = e.provider_id
JOIN oltp.specialties s ON s.specialty_id = p.specialty_id
GROUP BY
    DATE_TRUNC('month', e.encounter_date)::date,
    s.specialty_name
ORDER BY
    encounter_month,
    total_allowed_amount DESC
$q$),
    (4, 'Q4 Revenue by specialty and month', 'star', $q$
WITH monthly AS (
    SELECT
        d.month_start_date,
        f.specialty_key,
        COUNT(*) FILTER (WHERE f.claim_count > 0) AS billed_encounters,
        SUM(f.total_claim_amount)                 AS total_claim_amount,
        SUM(f.total_allowed_amount)               AS total_allowed_amount
    FROM star.fact_encounters f
    JOIN star.dim_date d ON d.date_key = f.encounter_date_key
    GROUP BY
        d.month_start_date,
        f.specialty_key
)
SELECT
    TO_CHAR(m.month_start_date, 'YYYY-MM') AS year_month,
    s.specialty_name,
    m.billed_encounters,
    m.total_claim_amount,
    m.total_allowed_amount
FROM monthly m
JOIN star.dim_specialty s ON s.specialty_key = m.specialty_key
WHERE m.billed_encounters > 0
ORDER BY
    year_month,
    m.total_allowed_amount DESC
$q$);

DO $$
DECLARE
    q     RECORD;
    plan  JSON;
    i     INT;
BEGIN
    FOR q IN SELECT * FROM benchmark_queries ORDER BY query_no, model LOOP
        EXECUTE 'EXPLAIN (ANALYZE, FORMAT JSON) ' || q.sql_text INTO plan;

        FOR i IN 1..3 LOOP
            EXECUTE 'EXPLAIN (ANALYZE, FORMAT JSON) ' || q.sql_text INTO plan;

            INSERT INTO benchmark_runs (query_no, model, run_no, execution_ms, disk_sort_kb)
            VALUES (
                q.query_no,
                q.model,
                i,
                ROUND((plan -> 0 ->> 'Execution Time')::numeric, 1),
                COALESCE((
                    SELECT SUM(m[1]::bigint)
                    FROM regexp_matches(plan::text,
                         '"Sort Space Used": (\d+),\s*"Sort Space Type": "Disk"', 'g') AS m
                ), 0)
            );
        END LOOP;
    END LOOP;
END
$$;

WITH medians AS (
    SELECT
        query_no,
        model,
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY execution_ms)::numeric, 1) AS median_ms,
        MIN(execution_ms) AS min_ms,
        MAX(execution_ms) AS max_ms,
        MAX(disk_sort_kb) AS disk_sort_kb
    FROM benchmark_runs
    GROUP BY query_no, model
)
SELECT
    q.query_no,
    q.label,
    o.median_ms                                   AS oltp_median_ms,
    s.median_ms                                   AS star_median_ms,
    ROUND(o.median_ms / NULLIF(s.median_ms, 0), 1) AS improvement_x,
    o.min_ms || ' - ' || o.max_ms                 AS oltp_range_ms,
    s.min_ms || ' - ' || s.max_ms                 AS star_range_ms,
    o.disk_sort_kb                                AS oltp_disk_sort_kb,
    s.disk_sort_kb                                AS star_disk_sort_kb
FROM (SELECT DISTINCT query_no, label FROM benchmark_queries) q
JOIN medians o ON o.query_no = q.query_no AND o.model = 'oltp'
JOIN medians s ON s.query_no = q.query_no AND s.model = 'star'
ORDER BY q.query_no;