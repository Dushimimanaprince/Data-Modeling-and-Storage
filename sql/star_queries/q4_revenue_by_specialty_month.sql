WITH monthly AS (
    SELECT
        d.month_start_date,
        f.specialty_key,
        COUNT(*) FILTER (WHERE f.claim_count > 0) AS billed_encounters,
        SUM(f.total_claim_amount)                 AS total_claim_amount,
        SUM(f.total_allowed_amount)               AS total_allowed_amount
    FROM star.fact_encounters f
    JOIN star.dim_date d ON d.date_key = f.encounter_date_key
    GROUP BY
        d.month_start_date,
        f.specialty_key
)
SELECT
    TO_CHAR(m.month_start_date, 'YYYY-MM') AS year_month,
    s.specialty_name,
    m.billed_encounters,
    m.total_claim_amount,
    m.total_allowed_amount
FROM monthly m
JOIN star.dim_specialty s ON s.specialty_key = m.specialty_key
WHERE m.billed_encounters > 0
ORDER BY
    year_month,
    m.total_allowed_amount DESC;