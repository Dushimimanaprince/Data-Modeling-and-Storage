WITH checks AS (
    SELECT 1 AS check_no, 'Encounter rows: oltp.encounters vs fact_encounters' AS check_name,
           (SELECT COUNT(*) FROM oltp.encounters)::numeric      AS source_value,
           (SELECT COUNT(*) FROM star.fact_encounters)::numeric AS target_value

    UNION ALL
    SELECT 2, 'Total claim amount: oltp.billing vs fact',
           (SELECT COALESCE(SUM(claim_amount), 0) FROM oltp.billing),
           (SELECT SUM(total_claim_amount) FROM star.fact_encounters)

    UNION ALL
    SELECT 3, 'Total allowed amount: oltp.billing vs fact',
           (SELECT COALESCE(SUM(allowed_amount), 0) FROM oltp.billing),
           (SELECT SUM(total_allowed_amount) FROM star.fact_encounters)

    UNION ALL
    SELECT 4, 'Billing rows: oltp.billing vs SUM(fact.claim_count)',
           (SELECT COUNT(*) FROM oltp.billing),
           (SELECT SUM(claim_count) FROM star.fact_encounters)

    UNION ALL
    SELECT 5, 'Diagnosis links: oltp.encounter_diagnoses vs bridge',
           (SELECT COUNT(*) FROM oltp.encounter_diagnoses),
           (SELECT COUNT(*) FROM star.bridge_encounter_diagnoses)

    UNION ALL
    SELECT 6, 'Procedure links: oltp.encounter_procedures vs bridge',
           (SELECT COUNT(*) FROM oltp.encounter_procedures),
           (SELECT COUNT(*) FROM star.bridge_encounter_procedures)

    UNION ALL
    SELECT 7, 'SUM(fact.diagnosis_count) vs diagnosis bridge rows',
           (SELECT SUM(diagnosis_count) FROM star.fact_encounters),
           (SELECT COUNT(*) FROM star.bridge_encounter_diagnoses)

    UNION ALL
    SELECT 8, 'SUM(fact.procedure_count) vs procedure bridge rows',
           (SELECT SUM(procedure_count) FROM star.fact_encounters),
           (SELECT COUNT(*) FROM star.bridge_encounter_procedures)

    UNION ALL
    SELECT 9, 'Patients: oltp.patients vs dim_patient (excluding Unknown)',
           (SELECT COUNT(*) FROM oltp.patients),
           (SELECT COUNT(*) FROM star.dim_patient WHERE patient_key <> -1)

    UNION ALL
    SELECT 10, 'Providers: oltp.providers vs current dim_provider rows',
           (SELECT COUNT(*) FROM oltp.providers),
           (SELECT COUNT(*) FROM star.dim_provider WHERE is_current AND provider_key <> -1)

    UNION ALL
    SELECT 11, 'Inpatient encounters: oltp vs fact',
           (SELECT COUNT(*) FROM oltp.encounters WHERE encounter_type = 'Inpatient'),
           (SELECT COUNT(*)
              FROM star.fact_encounters f
              JOIN star.dim_encounter_type t ON t.encounter_type_key = f.encounter_type_key
             WHERE t.encounter_type_name = 'Inpatient')

    UNION ALL
    SELECT 12, 'Fact rows with Unknown dimension keys (expected 0)',
           0,
           (SELECT COUNT(*) FROM star.fact_encounters
             WHERE encounter_date_key = 0 OR patient_key = -1 OR provider_key = -1
                OR specialty_key = -1 OR department_key = -1 OR encounter_type_key = -1)

    UNION ALL
    SELECT 13, 'Readmission flags only on inpatient rows (non-inpatient flagged, expected 0)',
           0,
           (SELECT COUNT(*)
              FROM star.fact_encounters f
              JOIN star.dim_encounter_type t ON t.encounter_type_key = f.encounter_type_key
             WHERE f.is_readmission_30d = 1 AND NOT t.is_inpatient)

    UNION ALL
    SELECT 14, 'Negative length of stay (expected 0)',
           0,
           (SELECT COUNT(*) FROM star.fact_encounters WHERE length_of_stay_hours < 0)
)
SELECT
    check_no,
    check_name,
    source_value,
    target_value,
    CASE WHEN source_value = target_value THEN 'PASS' ELSE 'FAIL' END AS status
FROM checks
ORDER BY check_no;