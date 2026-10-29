BEGIN;

WITH billing_agg AS (
    SELECT
        encounter_id,
        COUNT(*)            AS claim_count,
        SUM(claim_amount)   AS total_claim_amount,
        SUM(allowed_amount) AS total_allowed_amount
    FROM oltp.billing
    GROUP BY encounter_id
),
diagnosis_agg AS (
    SELECT
        encounter_id,
        COUNT(*)                                                    AS diagnosis_count,
        MIN(diagnosis_id) FILTER (WHERE diagnosis_sequence = 1)     AS primary_diagnosis_id
    FROM oltp.encounter_diagnoses
    GROUP BY encounter_id
),
procedure_agg AS (
    SELECT
        encounter_id,
        COUNT(*) AS procedure_count
    FROM oltp.encounter_procedures
    GROUP BY encounter_id
),
readmissions AS (
    SELECT i.encounter_id
    FROM oltp.encounters i
    WHERE i.encounter_type = 'Inpatient'
      AND i.discharge_date IS NOT NULL
      AND EXISTS (
          SELECT 1
          FROM oltp.encounters r
          WHERE r.patient_id     =  i.patient_id
            AND r.encounter_id   <> i.encounter_id
            AND r.encounter_date >  i.discharge_date
            AND r.encounter_date <= i.discharge_date + INTERVAL '30 days'
      )
)
INSERT INTO star.fact_encounters (
    encounter_id,
    encounter_date_key,
    discharge_date_key,
    patient_key,
    provider_key,
    specialty_key,
    department_key,
    encounter_type_key,
    primary_diagnosis_key,
    encounter_count,
    length_of_stay_hours,
    length_of_stay_days,
    patient_age_at_encounter,
    diagnosis_count,
    procedure_count,
    claim_count,
    total_claim_amount,
    total_allowed_amount,
    is_readmission_30d
)
SELECT
    e.encounter_id,
    COALESCE(d_enc.date_key, 0),
    COALESCE(d_dis.date_key, 0),
    COALESCE(dpat.patient_key, -1),
    COALESCE(dprov.provider_key, -1),
    COALESCE(dspec.specialty_key, -1),
    COALESCE(ddept.department_key, -1),
    COALESCE(dtype.encounter_type_key, -1),
    COALESCE(ddx.diagnosis_key, -1),
    1,
    ROUND((EXTRACT(EPOCH FROM (e.discharge_date - e.encounter_date)) / 3600)::numeric, 2),
    e.discharge_date::date - e.encounter_date::date,
    EXTRACT(YEAR FROM AGE(e.encounter_date::date, p.date_of_birth))::smallint,
    COALESCE(dx.diagnosis_count, 0),
    COALESCE(px.procedure_count, 0),
    COALESCE(b.claim_count, 0),
    COALESCE(b.total_claim_amount, 0),
    COALESCE(b.total_allowed_amount, 0),
    CASE WHEN ra.encounter_id IS NOT NULL THEN 1 ELSE 0 END
FROM oltp.encounters e
LEFT JOIN oltp.patients p               ON p.patient_id = e.patient_id
LEFT JOIN star.dim_date d_enc           ON d_enc.calendar_date = e.encounter_date::date
LEFT JOIN star.dim_date d_dis           ON d_dis.calendar_date = e.discharge_date::date
LEFT JOIN star.dim_patient dpat         ON dpat.patient_id = e.patient_id
LEFT JOIN star.dim_provider dprov       ON dprov.provider_id = e.provider_id
                                       AND e.encounter_date::date BETWEEN dprov.effective_date AND dprov.end_date
LEFT JOIN star.dim_specialty dspec      ON dspec.specialty_id = dprov.specialty_id
LEFT JOIN star.dim_department ddept     ON ddept.department_id = e.department_id
LEFT JOIN star.dim_encounter_type dtype ON dtype.encounter_type_name = e.encounter_type
LEFT JOIN billing_agg b                 ON b.encounter_id  = e.encounter_id
LEFT JOIN diagnosis_agg dx              ON dx.encounter_id = e.encounter_id
LEFT JOIN star.dim_diagnosis ddx        ON ddx.diagnosis_id = dx.primary_diagnosis_id
LEFT JOIN procedure_agg px              ON px.encounter_id = e.encounter_id
LEFT JOIN readmissions ra               ON ra.encounter_id = e.encounter_id
ON CONFLICT (encounter_id) DO UPDATE
SET encounter_date_key       = EXCLUDED.encounter_date_key,
    discharge_date_key       = EXCLUDED.discharge_date_key,
    patient_key              = EXCLUDED.patient_key,
    provider_key             = EXCLUDED.provider_key,
    specialty_key            = EXCLUDED.specialty_key,
    department_key           = EXCLUDED.department_key,
    encounter_type_key       = EXCLUDED.encounter_type_key,
    primary_diagnosis_key    = EXCLUDED.primary_diagnosis_key,
    length_of_stay_hours     = EXCLUDED.length_of_stay_hours,
    length_of_stay_days      = EXCLUDED.length_of_stay_days,
    patient_age_at_encounter = EXCLUDED.patient_age_at_encounter,
    diagnosis_count          = EXCLUDED.diagnosis_count,
    procedure_count          = EXCLUDED.procedure_count,
    claim_count              = EXCLUDED.claim_count,
    total_claim_amount       = EXCLUDED.total_claim_amount,
    total_allowed_amount     = EXCLUDED.total_allowed_amount,
    is_readmission_30d       = EXCLUDED.is_readmission_30d,
    loaded_at                = now();

COMMIT;

ANALYZE star.fact_encounters;

SELECT
    COUNT(*)                                        AS fact_rows,
    SUM(total_allowed_amount)                       AS total_allowed,
    SUM(is_readmission_30d)                         AS readmissions_30d,
    COUNT(*) FILTER (WHERE patient_key   = -1)      AS unknown_patients,
    COUNT(*) FILTER (WHERE provider_key  = -1)      AS unknown_providers,
    COUNT(*) FILTER (WHERE specialty_key = -1)      AS unknown_specialties,
    COUNT(*) FILTER (WHERE claim_count   = 0)       AS encounters_not_billed
FROM star.fact_encounters;