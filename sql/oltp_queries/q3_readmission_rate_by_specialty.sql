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
ORDER BY readmission_rate_pct DESC;