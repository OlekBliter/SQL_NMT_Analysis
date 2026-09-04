SET search_path TO nmt_2025, public;

WITH mandatory_avg_score_percentiles AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY mandatory_avg_score) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY mandatory_avg_score) AS q3
    FROM student_academic_profiles
)

SELECT
    sap.elective_subject,
    COUNT(*) AS total_candidates,
    ROUND(
        100.0 * COUNT(*)
        / NULLIF(SUM(COUNT(*)) OVER(), 0),
        2
    ) AS election_share,

    ROUND(AVG(sap.elective_score), 2) AS elective_avg,
    ROUND(AVG(sap.mandatory_avg_score), 2) AS mandatory_avg,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sap.elective_score)::numeric, 2) AS elective_median,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sap.mandatory_avg_score)::numeric, 2) AS mandatory_median,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sap.elective_score)::numeric, 2) - ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sap.mandatory_avg_score)::numeric, 2) AS median_delta,

    ROUND(
        100.0 * COUNT(*) FILTER (WHERE sap.mandatory_avg_score < mp.q1) 
        / NULLIF(SUM(COUNT(*) FILTER (WHERE sap.mandatory_avg_score < mp.q1)) OVER (), 0),
        2
    ) AS share_of_all_q1_students,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE sap.mandatory_avg_score BETWEEN mp.q1 AND mp.q3) 
        / NULLIF(SUM(COUNT(*) FILTER (WHERE sap.mandatory_avg_score BETWEEN mp.q1 AND mp.q3)) OVER (), 0),
        2
    ) AS share_of_all_q2_students,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE sap.mandatory_avg_score > mp.q3) 
        / NULLIF(SUM(COUNT(*) FILTER (WHERE sap.mandatory_avg_score > mp.q3)) OVER (), 0),
        2
    ) AS share_of_all_q3_students,

    ROUND(
        100.0 * COUNT(*) FILTER (WHERE sap.failed_mandatory)
        / NULLIF(COUNT(*), 0),
        1
    ) AS mandatory_failed_prc,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE sap.mandatory_avg_score >= 180)
        / NULLIF(COUNT(*), 0),
        1
    ) AS mandatory_high_achievers_prc,

    ROUND(
        100.0 * COUNT(*) FILTER (WHERE sap.elective_score = 0.0)
        / NULLIF(COUNT(*), 0),
        1
    ) AS elective_subject_failed_prc,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE sap.elective_score >= 180)
        / NULLIF(COUNT(*), 0),
        1
    ) AS elective_subject_high_achievers_prc

FROM student_academic_profiles sap
CROSS JOIN mandatory_avg_score_percentiles mp
WHERE elective_subject IS NOT NULL
GROUP BY 
    sap.elective_subject,
    mp.q1,
    mp.q3
ORDER BY mandatory_median DESC;