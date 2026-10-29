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
    t.encounter_type_name;