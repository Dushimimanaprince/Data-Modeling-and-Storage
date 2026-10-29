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
    e.encounter_type;