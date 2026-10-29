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
ORDER BY readmission_rate_pct DESC;