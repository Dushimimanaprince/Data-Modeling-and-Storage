BEGIN;

INSERT INTO star.dim_date (date_key, calendar_date, year, quarter, month, month_name, year_month,
                           month_start_date, day_of_month, day_of_week, day_name, week_of_year, is_weekend)
VALUES (0, NULL, NULL, NULL, NULL, 'Unknown', 'Unknown', NULL, NULL, NULL, 'Unknown', NULL, NULL)
ON CONFLICT (date_key) DO NOTHING;

INSERT INTO star.dim_date (date_key, calendar_date, year, quarter, month, month_name, year_month,
                           month_start_date, day_of_month, day_of_week, day_name, week_of_year, is_weekend)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::int,
    d::date,
    EXTRACT(YEAR    FROM d)::smallint,
    EXTRACT(QUARTER FROM d)::smallint,
    EXTRACT(MONTH   FROM d)::smallint,
    TRIM(TO_CHAR(d, 'Month')),
    TO_CHAR(d, 'YYYY-MM'),
    DATE_TRUNC('month', d)::date,
    EXTRACT(DAY     FROM d)::smallint,
    EXTRACT(ISODOW  FROM d)::smallint,
    TRIM(TO_CHAR(d, 'Day')),
    EXTRACT(WEEK    FROM d)::smallint,
    EXTRACT(ISODOW  FROM d) IN (6, 7)
FROM generate_series(DATE '2020-01-01', DATE '2030-12-31', INTERVAL '1 day') AS d
ON CONFLICT (date_key) DO NOTHING;

INSERT INTO star.dim_specialty   (specialty_key, specialty_id, specialty_name, specialty_code)
VALUES (-1, NULL, 'Unknown', 'UNK') ON CONFLICT (specialty_key) DO NOTHING;

INSERT INTO star.dim_department  (department_key, department_id, department_name, floor, capacity)
VALUES (-1, NULL, 'Unknown', NULL, NULL) ON CONFLICT (department_key) DO NOTHING;

INSERT INTO star.dim_encounter_type (encounter_type_key, encounter_type_name, is_inpatient, is_emergency)
VALUES (-1, 'Unknown', NULL, NULL) ON CONFLICT (encounter_type_key) DO NOTHING;

INSERT INTO star.dim_diagnosis   (diagnosis_key, diagnosis_id, icd10_code, icd10_description)
VALUES (-1, NULL, 'UNK', 'Unknown / none recorded') ON CONFLICT (diagnosis_key) DO NOTHING;

INSERT INTO star.dim_procedure   (procedure_key, procedure_id, cpt_code, cpt_description)
VALUES (-1, NULL, 'UNK', 'Unknown') ON CONFLICT (procedure_key) DO NOTHING;

INSERT INTO star.dim_patient     (patient_key, patient_id, mrn, first_name, last_name, full_name,
                                  gender, date_of_birth, age_group)
VALUES (-1, NULL, NULL, 'Unknown', 'Unknown', 'Unknown', 'Unknown', NULL, 'Unknown')
ON CONFLICT (patient_key) DO NOTHING;

INSERT INTO star.dim_provider    (provider_key, provider_id, first_name, last_name, full_name, credential,
                                  specialty_id, specialty_name, department_id, department_name,
                                  effective_date, end_date, is_current)
VALUES (-1, NULL, 'Unknown', 'Unknown', 'Unknown', NULL, NULL, 'Unknown', NULL, 'Unknown',
        DATE '1900-01-01', DATE '9999-12-31', TRUE)
ON CONFLICT (provider_key) DO NOTHING;

INSERT INTO star.dim_specialty (specialty_id, specialty_name, specialty_code)
SELECT specialty_id, specialty_name, specialty_code
FROM oltp.specialties
ON CONFLICT (specialty_id) DO UPDATE
SET specialty_name = EXCLUDED.specialty_name,
    specialty_code = EXCLUDED.specialty_code;

INSERT INTO star.dim_department (department_id, department_name, floor, capacity)
SELECT department_id, department_name, floor, capacity
FROM oltp.departments
ON CONFLICT (department_id) DO UPDATE
SET department_name = EXCLUDED.department_name,
    floor           = EXCLUDED.floor,
    capacity        = EXCLUDED.capacity;

INSERT INTO star.dim_encounter_type (encounter_type_name, is_inpatient, is_emergency)
SELECT DISTINCT
    encounter_type,
    encounter_type = 'Inpatient',
    encounter_type = 'ER'
FROM oltp.encounters
WHERE encounter_type IS NOT NULL
ON CONFLICT (encounter_type_name) DO NOTHING;

INSERT INTO star.dim_diagnosis (diagnosis_id, icd10_code, icd10_description)
SELECT diagnosis_id, icd10_code, icd10_description
FROM oltp.diagnoses
ON CONFLICT (diagnosis_id) DO UPDATE
SET icd10_code        = EXCLUDED.icd10_code,
    icd10_description = EXCLUDED.icd10_description;

INSERT INTO star.dim_procedure (procedure_id, cpt_code, cpt_description)
SELECT procedure_id, cpt_code, cpt_description
FROM oltp.procedures
ON CONFLICT (procedure_id) DO UPDATE
SET cpt_code        = EXCLUDED.cpt_code,
    cpt_description = EXCLUDED.cpt_description;

INSERT INTO star.dim_patient (patient_id, mrn, first_name, last_name, full_name,
                              gender, date_of_birth, age_group)
SELECT
    p.patient_id,
    p.mrn,
    p.first_name,
    p.last_name,
    CONCAT_WS(' ', p.first_name, p.last_name),
    CASE UPPER(p.gender)
        WHEN 'M' THEN 'Male'
        WHEN 'F' THEN 'Female'
        ELSE 'Unknown'
    END,
    p.date_of_birth,
    CASE
        WHEN p.date_of_birth IS NULL                          THEN 'Unknown'
        WHEN EXTRACT(YEAR FROM AGE(p.date_of_birth)) < 18     THEN '0-17'
        WHEN EXTRACT(YEAR FROM AGE(p.date_of_birth)) < 35     THEN '18-34'
        WHEN EXTRACT(YEAR FROM AGE(p.date_of_birth)) < 50     THEN '35-49'
        WHEN EXTRACT(YEAR FROM AGE(p.date_of_birth)) < 65     THEN '50-64'
        ELSE '65+'
    END
FROM oltp.patients p
ON CONFLICT (patient_id) DO UPDATE
SET mrn        = EXCLUDED.mrn,
    first_name = EXCLUDED.first_name,
    last_name  = EXCLUDED.last_name,
    full_name  = EXCLUDED.full_name,
    gender     = EXCLUDED.gender,
    age_group  = EXCLUDED.age_group,
    updated_at = now()
WHERE (star.dim_patient.mrn, star.dim_patient.first_name, star.dim_patient.last_name,
       star.dim_patient.gender, star.dim_patient.age_group)
      IS DISTINCT FROM
      (EXCLUDED.mrn, EXCLUDED.first_name, EXCLUDED.last_name,
       EXCLUDED.gender, EXCLUDED.age_group);

UPDATE star.dim_provider d
SET end_date   = CURRENT_DATE - 1,
    is_current = FALSE
FROM oltp.providers p
WHERE d.provider_id = p.provider_id
  AND d.is_current
  AND (d.specialty_id, d.department_id) IS DISTINCT FROM (p.specialty_id, p.department_id);

INSERT INTO star.dim_provider (provider_id, first_name, last_name, full_name, credential,
                               specialty_id, specialty_name, department_id, department_name,
                               effective_date, end_date, is_current)
SELECT
    p.provider_id,
    p.first_name,
    p.last_name,
    CONCAT_WS(' ', p.first_name, p.last_name),
    p.credential,
    p.specialty_id,
    COALESCE(s.specialty_name, 'Unknown'),
    p.department_id,
    COALESCE(dp.department_name, 'Unknown'),
    CASE
        WHEN EXISTS (SELECT 1 FROM star.dim_provider old WHERE old.provider_id = p.provider_id)
        THEN CURRENT_DATE
        ELSE DATE '1900-01-01'
    END,
    DATE '9999-12-31',
    TRUE
FROM oltp.providers p
LEFT JOIN oltp.specialties s  ON s.specialty_id   = p.specialty_id
LEFT JOIN oltp.departments dp ON dp.department_id = p.department_id
WHERE NOT EXISTS (
    SELECT 1
    FROM star.dim_provider cur
    WHERE cur.provider_id = p.provider_id
      AND cur.is_current
);

COMMIT;

ANALYZE star.dim_date, star.dim_patient, star.dim_specialty, star.dim_department,
        star.dim_provider, star.dim_encounter_type, star.dim_diagnosis, star.dim_procedure;

SELECT 'dim_date' AS dimension, COUNT(*) AS row_count FROM star.dim_date
UNION ALL SELECT 'dim_patient',        COUNT(*) FROM star.dim_patient
UNION ALL SELECT 'dim_specialty',      COUNT(*) FROM star.dim_specialty
UNION ALL SELECT 'dim_department',     COUNT(*) FROM star.dim_department
UNION ALL SELECT 'dim_provider',       COUNT(*) FROM star.dim_provider
UNION ALL SELECT 'dim_encounter_type', COUNT(*) FROM star.dim_encounter_type
UNION ALL SELECT 'dim_diagnosis',      COUNT(*) FROM star.dim_diagnosis
UNION ALL SELECT 'dim_procedure',      COUNT(*) FROM star.dim_procedure
ORDER BY 1;