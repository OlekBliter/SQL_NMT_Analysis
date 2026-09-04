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

    i.institution_id,
    i.institution_name,
    i.institution_type,
    i.reg_name,
    i.area_name,
    i.ter_name,
    CONCAT_WS(', ', i.reg_name, i.area_name, i.ter_name) AS full_institution_location,
    CASE
        WHEN i.institution_id IS NULL THEN FALSE

        WHEN i.reg_name IN ('м.Київ', 'м. Київ')
             OR TRIM(REGEXP_REPLACE(i.area_name, '^м\.\s*', '')) IN (
                 'Київ', 'Дніпро', 'Житомир', 'Запоріжжя', 'Кропивницький',
                 'Львів', 'Миколаїв', 'Одеса', 'Полтава', 'Суми',
                 'Харків', 'Херсон', 'Черкаси', 'Чернігів',
                 'Донецьк', 'Луганськ'
             ) THEN TRUE

        WHEN i.ter_name ~* '^м\.\s*' AND (
            TRIM(REGEXP_REPLACE(i.ter_name, '^м\.\s*', '')) IN (
                'Вінниця', 'Луцьк', 'Ужгород', 'Івано-Франківськ',
                'Рівне', 'Тернопіль', 'Хмельницький', 'Чернівці',
                'Донецьк', 'Луганськ'
            )
            OR (
                TRIM(REGEXP_REPLACE(i.ter_name, '^м\.\s*', '')) = 'Миколаїв' 
                AND i.reg_name = 'Миколаївська область'
            )
        ) THEN TRUE

        ELSE FALSE
    END AS is_regional_center
FROM exam_results er
JOIN participants p 
    ON er.out_id = p.out_id
LEFT JOIN institutions i 
    ON p.institution_id = i.institution_id
WHERE
    er.is_present = TRUE
    AND er.test_date IS NOT NULL
    AND er.scaled_score IS NOT NULL;