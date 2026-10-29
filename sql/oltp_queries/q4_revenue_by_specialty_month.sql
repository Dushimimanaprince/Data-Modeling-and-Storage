SELECT
    DATE_TRUNC('month', e.encounter_date)::date AS encounter_month,
    s.specialty_name,
    COUNT(DISTINCT b.encounter_id) AS billed_encounters,
    SUM(b.claim_amount)            AS total_claim_amount,
    SUM(b.allowed_amount)          AS total_allowed_amount
FROM oltp.billing     b
JOIN oltp.encounters  e ON e.encounter_id = b.encounter_id
JOIN oltp.providers   p ON p.provider_id  = e.provider_id
JOIN oltp.specialties s ON s.specialty_id = p.specialty_id
GROUP BY
    DATE_TRUNC('month', e.encounter_date)::date,
    s.specialty_name
ORDER BY
    encounter_month,
    total_allowed_amount DESC;