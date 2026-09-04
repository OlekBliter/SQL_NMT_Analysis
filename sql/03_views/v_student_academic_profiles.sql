-- ============================================================================
-- View 2: student_academic_profiles
-- Granularity: 1 row = 1 student
-- ============================================================================
SET search_path TO nmt_2025, public;

CREATE OR REPLACE VIEW student_academic_profiles AS
SELECT
    cer.out_id,
    cer.participant_status,
    cer.macro_location,
    cer.gender,
    cer.institution_id,
    cer.institution_name,
    cer.institution_type,
    cer.reg_name,
    cer.area_name,
    cer.ter_name,
    cer.full_institution_location,
    
    MAX(CASE WHEN cer.subject_code = 'Ukr' THEN cer.scaled_score END) AS score_ukr,
    MAX(CASE WHEN cer.subject_code = 'Math' THEN cer.scaled_score END) AS score_math,
    MAX(CASE WHEN cer.subject_code = 'Hist' THEN cer.scaled_score END) AS score_hist,
    
    ROUND(
        AVG(CASE WHEN cer.subject_code IN ('Ukr', 'Math', 'Hist') THEN cer.scaled_score END),
        2
    ) AS mandatory_avg_score,

    MAX(CASE WHEN cer.subject_code NOT IN ('Ukr', 'Math', 'Hist') THEN cer.subject_code END) AS elective_subject,
    MAX(CASE WHEN cer.subject_code NOT IN ('Ukr', 'Math', 'Hist') THEN cer.scaled_score END) AS elective_score,

    ROUND(
        AVG(cer.scaled_score),
        2
    ) AS overall_avg_score,

    MAX(cer.test_date) AS test_date,
    COUNT(cer.subject_code) AS total_subjects_completed,

    BOOL_OR(scaled_score = 0.0) AS failed,
    BOOL_OR(scaled_score = 0.0 AND subject_code IN ('Math', 'Ukr', 'Hist')) AS failed_mandatory

FROM clean_exam_results cer
GROUP BY
    cer.out_id,
    cer.participant_status,
    cer.macro_location,
    cer.gender,
    cer.institution_id,
    cer.institution_name,
    cer.institution_type,
    cer.reg_name,
    cer.area_name,
    cer.ter_name,
    cer.full_institution_location;