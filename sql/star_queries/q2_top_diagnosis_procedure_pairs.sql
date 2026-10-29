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
LIMIT 20;