SET search_path TO nmt_2025, public;

BEGIN;

-- Step 1: Populate Educational Institutions with Strict Deduplication
INSERT INTO institutions (
    edebo_id, 
    edrpou, 
    institution_name, 
    institution_type, 
    reg_name, 
    area_name, 
    ter_name, 
    parent_governance
)
SELECT DISTINCT ON (
    COALESCE(
        NULLIF(eo_edeboid, 'null'), 
        NULLIF(eo_edrpou, 'null'), 
        CONCAT_WS('||', eo_name, eo_reg_name, eo_area_name, eo_ter_name)
    )
)
    NULLIF(eo_edeboid, 'null'),
    NULLIF(eo_edrpou, 'null'),
    eo_name,
    NULLIF(eo_type_name, 'null'),
    NULLIF(eo_reg_name, 'null'),
    NULLIF(eo_area_name, 'null'),
    NULLIF(eo_ter_name, 'null'),
    NULLIF(eo_parent, 'null')
FROM staging_nmt_raw
WHERE eo_name IS NOT NULL AND eo_name <> 'null'
ORDER BY 
    COALESCE(
        NULLIF(eo_edeboid, 'null'), 
        NULLIF(eo_edrpou, 'null'), 
        CONCAT_WS('||', eo_name, eo_reg_name, eo_area_name, eo_ter_name)
    ),
    (eo_parent IS NOT NULL AND eo_parent <> 'null') DESC,
    (eo_edrpou IS NOT NULL AND eo_edrpou <> 'null') DESC;

-- Step 2: Populate Participants using LATERAL Resolution (Guaranteed 1:1)
INSERT INTO participants (
    out_id, 
    birth_year, 
    gender, 
    participant_status, 
    ter_type, 
    reg_name, 
    area_name, 
    ter_name, 
    institution_id
)
SELECT DISTINCT ON (s.outid)
    TRIM(s.outid)::UUID,
    NULLIF(s.birth, 'null')::SMALLINT,
    NULLIF(s.sex_type_name, 'null'),
    NULLIF(s.reg_type_name, 'null'),
    NULLIF(s.ter_type_name, 'null'),
    NULLIF(s.reg_name, 'null'),
    NULLIF(s.area_name, 'null'),
    NULLIF(s.ter_name, 'null'),
    i.institution_id
FROM staging_nmt_raw s
LEFT JOIN LATERAL (
    SELECT inst.institution_id
    FROM institutions inst
    WHERE 
        -- Priority 1: Match by unique EDEBO ID
        (NULLIF(s.eo_edeboid, 'null') IS NOT NULL AND inst.edebo_id = s.eo_edeboid)
        OR 
        -- Priority 2: Match by EDRPOU and school name
        (NULLIF(s.eo_edeboid, 'null') IS NULL AND NULLIF(s.eo_edrpou, 'null') IS NOT NULL 
         AND inst.edrpou = s.eo_edrpou AND inst.institution_name = s.eo_name)
        OR
        -- Priority 3: Match by Name and geographic hierarchy
        (NULLIF(s.eo_edeboid, 'null') IS NULL AND NULLIF(s.eo_edrpou, 'null') IS NULL 
         AND inst.institution_name = s.eo_name 
         AND inst.reg_name = s.eo_reg_name
         AND (s.eo_area_name = 'null' OR inst.area_name = s.eo_area_name)
         AND (s.eo_ter_name = 'null' OR inst.ter_name = s.eo_ter_name))
    ORDER BY 
        (inst.edebo_id = NULLIF(s.eo_edeboid, 'null')) DESC NULLS LAST,
        (inst.edrpou = NULLIF(s.eo_edrpou, 'null')) DESC NULLS LAST,
        (inst.ter_name = NULLIF(s.eo_ter_name, 'null')) DESC NULLS LAST,
        (inst.area_name = NULLIF(s.eo_area_name, 'null')) DESC NULLS LAST,
        inst.institution_id ASC
    LIMIT 1
) i ON (s.eo_name IS NOT NULL AND s.eo_name <> 'null')
WHERE s.outid IS NOT NULL AND s.outid <> 'null';

-- Step 3: Unpivot and Populate Exam Results Fact Table
INSERT INTO exam_results (
    out_id, 
    subject_code, 
    test_date, 
    exam_lang, 
    status, 
    raw_score, 
    scaled_score, 
    pt_reg_name, 
    pt_area_name, 
    pt_ter_name
)
SELECT 
    TRIM(s.outid)::UUID,
    u.subject_code,
    TO_DATE(NULLIF(s.test_date, 'null'), 'DD.MM.YYYY'),
    NULLIF(u.lang, 'null'),
    NULLIF(u.status, 'null'),
    TRIM(REPLACE(NULLIF(u.raw_score, 'null'), ',', '.'))::NUMERIC(5, 2),
    TRIM(REPLACE(NULLIF(u.scaled_score, 'null'), ',', '.'))::NUMERIC(5, 2),
    NULLIF(s.pt_reg_name, 'null'),
    NULLIF(s.pt_area_name, 'null'),
    NULLIF(s.pt_ter_name, 'null')
FROM staging_nmt_raw s
CROSS JOIN LATERAL (
    VALUES 
        ('Ukr',    'українська', s.ukr_status,    s.ukr_ball,    s.ukr_ball100),
        ('Hist',   s.hist_lang,  s.hist_status,   s.hist_ball,   s.hist_ball100),
        ('Math',   s.math_lang,  s.math_status,   s.math_ball,   s.math_ball100),
        ('Phys',   s.phys_lang,  s.phys_status,   s.phys_ball,   s.phys_ball100),
        ('Chem',   s.chem_lang,  s.chem_status,   s.chem_ball,   s.chem_ball100),
        ('Bio',    s.bio_lang,   s.bio_status,    s.bio_ball,    s.bio_ball100),
        ('Geo',    s.geo_lang,   s.geo_status,    s.geo_ball,    s.geo_ball100),
        ('Eng',    'англійська', s.eng_status,    s.eng_ball,    s.eng_ball100),
        ('Fra',    'французька', s.fra_status,    s.fra_ball,    s.fra_ball100),
        ('Deu',    'німецька',   s.deu_status,    s.deu_ball,    s.deu_ball100),
        ('Spa',    'іспанська',  s.spa_status,    s.spa_ball,    s.spa_ball100),
        ('UkrLit', 'українська', s.ukrlit_status, s.ukrlit_ball, s.ukrlit_ball100)
) AS u(subject_code, lang, status, raw_score, scaled_score)
WHERE NULLIF(u.status, 'null') IS NOT NULL 
   OR NULLIF(u.scaled_score, 'null') IS NOT NULL;

-- Optionally, to save storage
TRUNCATE TABLE staging_nmt_raw;

COMMIT;

-- Optionally, can drop the table if do not need it
DROP TABLE IF EXISTS nmt_2025.staging_nmt_raw;