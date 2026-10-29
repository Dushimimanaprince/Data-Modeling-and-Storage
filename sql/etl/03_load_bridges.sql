BEGIN;

TRUNCATE star.bridge_encounter_diagnoses, star.bridge_encounter_procedures;

INSERT INTO star.bridge_encounter_diagnoses (encounter_key, diagnosis_key, diagnosis_sequence, is_primary)
SELECT
    f.encounter_key,
    COALESCE(dd.diagnosis_key, -1)  AS diagnosis_key,
    MIN(ed.diagnosis_sequence)      AS diagnosis_sequence,
    MIN(ed.diagnosis_sequence) = 1  AS is_primary
FROM oltp.encounter_diagnoses ed
JOIN star.fact_encounters f      ON f.encounter_id   = ed.encounter_id
LEFT JOIN star.dim_diagnosis dd  ON dd.diagnosis_id  = ed.diagnosis_id
GROUP BY f.encounter_key, COALESCE(dd.diagnosis_key, -1);

INSERT INTO star.bridge_encounter_procedures (encounter_key, procedure_key, procedure_date_key)
SELECT
    f.encounter_key,
    COALESCE(dp.procedure_key, -1)        AS procedure_key,
    COALESCE(MIN(dd.date_key), 0)         AS procedure_date_key
FROM oltp.encounter_procedures ep
JOIN star.fact_encounters f      ON f.encounter_id    = ep.encounter_id
LEFT JOIN star.dim_procedure dp  ON dp.procedure_id   = ep.procedure_id
LEFT JOIN star.dim_date dd       ON dd.calendar_date  = ep.procedure_date
GROUP BY f.encounter_key, COALESCE(dp.procedure_key, -1);

COMMIT;

ANALYZE star.bridge_encounter_diagnoses, star.bridge_encounter_procedures;

SELECT 'bridge_encounter_diagnoses' AS bridge, COUNT(*) AS row_count FROM star.bridge_encounter_diagnoses
UNION ALL
SELECT 'bridge_encounter_procedures', COUNT(*) FROM star.bridge_encounter_procedures;