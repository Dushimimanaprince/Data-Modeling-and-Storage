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
LIMIT 20;