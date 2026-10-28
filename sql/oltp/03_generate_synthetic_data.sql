SET search_path TO oltp;

SELECT setseed(0.42);

BEGIN;

INSERT INTO specialties (specialty_id, specialty_name, specialty_code) VALUES
    (4,  'Pulmonology',        'PULM'),
    (5,  'Nephrology',         'NEPH'),
    (6,  'Neurology',          'NEUR'),
    (7,  'Orthopedics',        'ORTH'),
    (8,  'Pediatrics',         'PED'),
    (9,  'General Surgery',    'GSURG'),
    (10, 'Infectious Disease', 'ID');

INSERT INTO departments (department_id, department_name, floor, capacity) VALUES
    (4,  'Pulmonology Unit',        4, 25),
    (5,  'Nephrology Unit',         4, 20),
    (6,  'Neurology Unit',          5, 25),
    (7,  'Orthopedics Unit',        5, 30),
    (8,  'Pediatrics Unit',         2, 35),
    (9,  'Surgical Unit',           6, 40),
    (10, 'Infectious Disease Unit', 6, 20);

INSERT INTO diagnoses (diagnosis_id, icd10_code, icd10_description) VALUES
    (3004, 'J18.9',   'Pneumonia'),
    (3005, 'J44.9',   'COPD'),
    (3006, 'N18.9',   'Chronic Kidney Disease'),
    (3007, 'I48.91',  'Atrial Fibrillation'),
    (3008, 'I25.10',  'Coronary Artery Disease'),
    (3009, 'E78.5',   'Hyperlipidemia'),
    (3010, 'J45.909', 'Asthma'),
    (3011, 'K21.9',   'GERD'),
    (3012, 'M54.5',   'Low Back Pain'),
    (3013, 'R07.9',   'Chest Pain'),
    (3014, 'R51.9',   'Headache'),
    (3015, 'A09',     'Gastroenteritis'),
    (3016, 'N39.0',   'Urinary Tract Infection'),
    (3017, 'B54',     'Malaria'),
    (3018, 'E66.9',   'Obesity'),
    (3019, 'D64.9',   'Anemia'),
    (3020, 'S06.0',   'Concussion'),
    (3021, 'I63.9',   'Stroke'),
    (3022, 'K35.80',  'Appendicitis'),
    (3023, 'M17.9',   'Knee Osteoarthritis');

INSERT INTO procedures (procedure_id, cpt_code, cpt_description) VALUES
    (4004, '99214', 'Office Visit (Moderate)'),
    (4005, '99283', 'ER Visit (Moderate)'),
    (4006, '99285', 'ER Visit (High)'),
    (4007, '99223', 'Initial Hospital Care'),
    (4008, '80053', 'Comprehensive Metabolic Panel'),
    (4009, '85025', 'Complete Blood Count'),
    (4010, '81001', 'Urinalysis'),
    (4011, '93306', 'Echocardiogram'),
    (4012, '70450', 'CT Head'),
    (4013, '74177', 'CT Abdomen'),
    (4014, '36415', 'Blood Draw'),
    (4015, '93458', 'Cardiac Catheterization'),
    (4016, '45378', 'Colonoscopy'),
    (4017, '97110', 'Physical Therapy'),
    (4018, '87070', 'Bacterial Culture');

INSERT INTO providers (provider_id, first_name, last_name, credential, specialty_id, department_id)
SELECT
    103 + g,
    (ARRAY['Aline','Eric','Grace','Jean','Diane','Patrick','Claudine','Olivier','Sandrine','Emmanuel'])[1 + floor(random() * 10)::int],
    (ARRAY['Uwase','Mugisha','Niyonzima','Habimana','Ingabire','Nshimiyimana','Mukamana','Kagame','Iradukunda','Tuyishime'])[1 + floor(random() * 10)::int],
    (ARRAY['MD','MD','MD','DO','NP','PA'])[1 + floor(random() * 6)::int],
    1 + (g % 10),
    1 + (g % 10)
FROM generate_series(1, 200) AS g;

INSERT INTO patients (patient_id, first_name, last_name, date_of_birth, gender, mrn)
SELECT
    10000 + g,
    (ARRAY['Alice','Bosco','Chantal','David','Esther','Fabrice','Gisele','Herve','Ines','Kevin','Linda','Moses'])[1 + floor(random() * 12)::int],
    (ARRAY['Uwimana','Hakizimana','Mutoni','Ndayisaba','Umutoni','Bizimana','Nyirahabimana','Gatete','Kayitesi','Rukundo'])[1 + floor(random() * 10)::int],
    DATE '1940-01-01' + floor(random() * 29000)::int,
    CASE WHEN random() < 0.5 THEN 'M' ELSE 'F' END,
    'MRN' || lpad((10000 + g)::text, 6, '0')
FROM generate_series(1, 50000) AS g;

WITH base AS (
    SELECT
        100000 + g                                        AS encounter_id,
        10001 + floor(random() * 50000)::int              AS patient_id,
        104 + floor(random() * 200)::int                  AS provider_id,
        TIMESTAMP '2023-01-01 07:00:00'
            + floor(random() * 730) * INTERVAL '1 day'
            + floor(random() * 600) * INTERVAL '1 minute' AS encounter_date,
        random()                                          AS r_type,
        random()                                          AS r_len
    FROM generate_series(1, 500000) AS g
),
typed AS (
    SELECT
        b.*,
        p.department_id,
        CASE
            WHEN p.specialty_id = 3 THEN 'ER'
            WHEN b.r_type < 0.75     THEN 'Outpatient'
            ELSE 'Inpatient'
        END AS encounter_type
    FROM base b
    JOIN providers p ON p.provider_id = b.provider_id
)
INSERT INTO encounters (encounter_id, patient_id, provider_id, encounter_type,
                        encounter_date, discharge_date, department_id)
SELECT
    encounter_id,
    patient_id,
    provider_id,
    encounter_type,
    encounter_date,
    encounter_date + CASE encounter_type
        WHEN 'Outpatient' THEN (30 + floor(r_len * 150)) * INTERVAL '1 minute'
        WHEN 'ER'         THEN (2  + floor(r_len * 10))  * INTERVAL '1 hour'
        ELSE                   (1  + floor(r_len * 10))  * INTERVAL '1 day'
    END,
    department_id
FROM typed;

WITH dx_plan AS (
    SELECT
        encounter_id,
        1 + floor(random() * 4)::int  AS n_dx,
        floor(random() * 23)::int     AS start_idx
    FROM encounters
    WHERE encounter_id > 100000
)
INSERT INTO encounter_diagnoses (encounter_diagnosis_id, encounter_id, diagnosis_id, diagnosis_sequence)
SELECT
    1000000 + row_number() OVER (ORDER BY d.encounter_id, s.seq),
    d.encounter_id,
    3001 + ((d.start_idx + (s.seq - 1) * 7) % 23),
    s.seq
FROM dx_plan d
CROSS JOIN LATERAL generate_series(1, d.n_dx) AS s(seq);

WITH px_plan AS (
    SELECT
        e.encounter_id,
        e.encounter_date::date        AS procedure_date,
        floor(random() * 4)::int      AS n_px,
        floor(random() * 18)::int     AS start_idx
    FROM encounters e
    WHERE e.encounter_id > 100000
)
INSERT INTO encounter_procedures (encounter_procedure_id, encounter_id, procedure_id, procedure_date)
SELECT
    2000000 + row_number() OVER (ORDER BY p.encounter_id, s.seq),
    p.encounter_id,
    4001 + ((p.start_idx + (s.seq - 1) * 5) % 18),
    p.procedure_date
FROM px_plan p
CROSS JOIN LATERAL generate_series(1, p.n_px) AS s(seq);

WITH claims AS (
    SELECT
        e.encounter_id,
        e.discharge_date,
        CASE e.encounter_type
            WHEN 'Outpatient' THEN 100  + random() * 500
            WHEN 'ER'         THEN 500  + random() * 2500
            ELSE                   5000 + random() * 35000
        END              AS claim_amount,
        0.6 + random() * 0.3 AS allowed_ratio,
        random()         AS r_bill,
        random()         AS r_status
    FROM encounters e
    WHERE e.encounter_id > 100000
)
INSERT INTO billing (billing_id, encounter_id, claim_amount, allowed_amount, claim_date, claim_status)
SELECT
    3000000 + row_number() OVER (ORDER BY encounter_id),
    encounter_id,
    round(claim_amount::numeric, 2),
    round((claim_amount * allowed_ratio)::numeric, 2),
    discharge_date::date + (1 + floor(r_status * 30)::int),
    CASE
        WHEN r_status < 0.80 THEN 'Paid'
        WHEN r_status < 0.93 THEN 'Pending'
        ELSE 'Denied'
    END
FROM claims
WHERE r_bill < 0.85;

COMMIT;

ANALYZE;

SELECT 'specialties' AS table_name, COUNT(*) AS row_count FROM specialties
UNION ALL SELECT 'departments',          COUNT(*) FROM departments
UNION ALL SELECT 'providers',            COUNT(*) FROM providers
UNION ALL SELECT 'patients',             COUNT(*) FROM patients
UNION ALL SELECT 'diagnoses',            COUNT(*) FROM diagnoses
UNION ALL SELECT 'procedures',           COUNT(*) FROM procedures
UNION ALL SELECT 'encounters',           COUNT(*) FROM encounters
UNION ALL SELECT 'billing',              COUNT(*) FROM billing
UNION ALL SELECT 'encounter_diagnoses',  COUNT(*) FROM encounter_diagnoses
UNION ALL SELECT 'encounter_procedures', COUNT(*) FROM encounter_procedures;