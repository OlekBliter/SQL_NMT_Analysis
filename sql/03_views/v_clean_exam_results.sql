-- ============================================================================
-- View 1: clean_exam_results
-- Granularity: 1 row = 1 attended exam result
-- ============================================================================
SET search_path TO nmt_2025, public;

CREATE OR REPLACE VIEW clean_exam_results AS
SELECT
    er.result_id,
    er.out_id,
    er.test_date,
    er.subject_code,
    er.raw_score,
    er.scaled_score,
    
    p.participant_status,
    CASE
        WHEN p.ter_type = 'інша країна' THEN 'Закордон'
        WHEN p.ter_type = 'місто' THEN 'Місто'
        WHEN p.ter_type = 'селище, село' THEN 'Село'
        ELSE 'Не визначено'
    END AS macro_location,

    p.institution_id,
    i.institution_name,
    i.institution_type,
    i.reg_name,
    i.area_name,
    i.ter_name,
    CONCAT_WS(', ', i.reg_name, i.area_name, i.ter_name) AS full_institution_location

FROM exam_results er
JOIN participants p 
    ON er.out_id = p.out_id
LEFT JOIN institutions i 
    ON p.institution_id = i.institution_id
WHERE
    er.is_present = TRUE
    AND er.test_date IS NOT NULL
    AND er.scaled_score IS NOT NULL;