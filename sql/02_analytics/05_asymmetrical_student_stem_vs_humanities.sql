SET search_path TO nmt_2025, public;

WITH individual_profile_metrics AS (
    SELECT
        gender,
        macro_location,
        score_math,
        score_ukr,
        score_hist,
        (score_ukr + score_hist) / 2.0 AS humanities_score,
        score_math AS stem_score
    FROM student_academic_profiles
    WHERE score_math IS NOT NULL 
      AND score_ukr IS NOT NULL 
      AND score_hist IS NOT NULL
),

student_archetypes AS (
    SELECT
        gender,
        macro_location,
        humanities_score,
        stem_score,
        stem_score - humanities_score AS asymmetry_delta,
        CASE
            WHEN stem_score = 0.0 OR score_ukr = 0.0 OR score_hist = 0.0 OR (stem_score < 130 AND humanities_score < 130)
                THEN 'Академічна група ризику'

            WHEN stem_score >= 160 AND humanities_score >= 160
                THEN 'Академічний універсал'

            WHEN (stem_score - humanities_score) >= 15 AND stem_score >= 140
                THEN 'STEM-спеціаліст'

            WHEN (stem_score - humanities_score) <= -15 AND humanities_score >= 140
                THEN 'Гуманітарний профіль'

            ELSE 'Збалансований базовий рівень'
        END AS archetype
    FROM individual_profile_metrics
)

SELECT
    archetype,
    COUNT(*) AS total_students,
    ROUND(
        100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0),
        1
    ) AS archetype_share,

    ROUND(AVG(stem_score)::numeric, 1) AS avg_stem_score,
    ROUND(AVG(humanities_score)::numeric, 1) AS avg_humanities_score,
    ROUND(AVG(asymmetry_delta)::numeric, 1) AS avg_asymmetry_delta,

    ROUND(
        100.0 * COUNT(*) FILTER (WHERE gender = 'жіноча') / NULLIF(COUNT(*), 0),
        1
    ) AS women_pct,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE gender = 'чоловіча') / NULLIF(COUNT(*), 0),
        1
    ) AS men_pct,

    ROUND(
        100.0 * COUNT(*) FILTER (WHERE macro_location = 'Село') / NULLIF(COUNT(*), 0),
        1
    ) AS rural_pct,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE macro_location = 'Місто') / NULLIF(COUNT(*), 0),
        1
    ) AS city_pct,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE macro_location = 'Закордон') / NULLIF(COUNT(*), 0),
        1
    ) AS abroad_pct

FROM student_archetypes
GROUP BY archetype
ORDER BY total_students DESC;



WITH individual_profile_metrics AS (
    SELECT
        score_math,
        score_ukr,
        score_hist,
        elective_subject,
        elective_score,
        (score_ukr + score_hist) / 2.0 AS humanities_score,
        score_math AS stem_score
    FROM student_academic_profiles
    WHERE score_math IS NOT NULL 
      AND score_ukr IS NOT NULL 
      AND score_hist IS NOT NULL
      AND elective_subject IS NOT NULL
),

student_archetypes AS (
    SELECT
        elective_subject,
        elective_score,
        CASE
            WHEN stem_score = 0.0 OR score_ukr = 0.0 OR score_hist = 0.0 OR (stem_score < 130 AND humanities_score < 130)
                THEN 'Академічна група ризику'

            WHEN stem_score >= 160 AND humanities_score >= 160
                THEN 'Академічний універсал'

            WHEN (stem_score - humanities_score) >= 15 AND stem_score >= 140
                THEN 'STEM-спеціаліст'

            WHEN (stem_score - humanities_score) <= -15 AND humanities_score >= 140
                THEN 'Гуманітарний профіль'

            ELSE 'Збалансований базовий рівень'
        END AS archetype
    FROM individual_profile_metrics
)

SELECT
    archetype,
    elective_subject,
    COUNT(*) AS students_count,
    
    ROUND(
        100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (PARTITION BY archetype), 0),
        2
    ) AS pct_within_archetype,

    DENSE_RANK() OVER (
        PARTITION BY archetype 
        ORDER BY COUNT(*) DESC
    ) AS subject_rank_in_archetype,

    ROUND(AVG(elective_score)::numeric, 1) AS avg_elective_score

FROM student_archetypes
GROUP BY
    archetype,
    elective_subject
ORDER BY
    archetype,
    students_count DESC;