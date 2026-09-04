SET search_path TO nmt_2025, public;


SELECT
    macro_location,
    COUNT(*) AS total_students,
    ROUND(
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY mandatory_avg_score)::numeric, 
        2
    ) AS mandatory_q1_score,
    ROUND(
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY mandatory_avg_score)::numeric, 
        2
    ) AS mandatory_median_score,
    ROUND(
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY mandatory_avg_score)::numeric, 
        2
    ) AS mandatory_q3_score,
    ROUND(
        (PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY mandatory_avg_score) - 
         PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY mandatory_avg_score))::numeric, 
        2
    ) AS iqr,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE mandatory_avg_score >= 180) 
        / NULLIF(COUNT(*), 0), 
        2
    ) AS high_achievers_percentage,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE score_ukr = 0.0 OR score_math = 0.0 OR score_hist = 0.0
        ) / NULLIF(COUNT(*), 0), 
        2
    ) AS failed_percentage
FROM student_academic_profiles
WHERE macro_location IN ('Місто', 'Село', 'Закордон')
GROUP BY macro_location
ORDER BY mandatory_median_score DESC;


SELECT
    institution_type,
    COUNT(*) AS total_students,
    ROUND(
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY mandatory_avg_score)::numeric, 
        2
    ) AS q1,
    ROUND(
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY mandatory_avg_score)::numeric, 
        2
    ) AS median,
    ROUND(
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY mandatory_avg_score)::numeric, 
        2
    ) AS q3,
    ROUND(
        (PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY mandatory_avg_score) - 
         PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY mandatory_avg_score))::numeric, 
        2
    ) AS iqr,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE mandatory_avg_score >= 180) 
        / NULLIF(COUNT(*), 0), 
        2
    ) AS high_achievers_percentage,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE score_ukr = 0.0 OR score_math = 0.0 OR score_hist = 0.0
        ) / NULLIF(COUNT(*), 0), 
        2
    ) AS failed_percentage,
    ROUND(
        (STDDEV(mandatory_avg_score) / NULLIF(AVG(mandatory_avg_score), 0))::numeric, 
        2
    ) AS coefficient_of_variation
FROM student_academic_profiles
WHERE 
    macro_location = 'Село'
    AND institution_type IS NOT NULL
GROUP BY institution_type
HAVING COUNT(*) >= 50
ORDER BY median DESC;


WITH macro_benchmarks AS (
    SELECT
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY mandatory_avg_score) 
            FILTER (WHERE macro_location = 'Село') AS national_rural_median,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY mandatory_avg_score) 
            FILTER (WHERE macro_location = 'Місто') AS national_urban_median
    FROM student_academic_profiles
)

SELECT
    sap.institution_id,
    sap.institution_name,
    sap.reg_name,
    sap.institution_type,
    COUNT(*) AS total_students,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sap.mandatory_avg_score)::numeric, 
        2
    ) AS mandatory_median_score,
    ROUND(
        (PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY sap.mandatory_avg_score) - 
         PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY sap.mandatory_avg_score))::numeric, 
        2
    ) AS iqr,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE sap.mandatory_avg_score >= 180) 
        / NULLIF(COUNT(*), 0), 
        2
    ) AS high_achievers_percentage,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE sap.score_ukr = 0.0 OR sap.score_math = 0.0 OR sap.score_hist = 0.0
        ) / NULLIF(COUNT(*), 0), 
        2
    ) AS failed_percentage,

    CASE
        WHEN BOOL_OR(sap.mandatory_avg_score >= 180) 
             AND PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sap.mandatory_avg_score) < mb.national_rural_median
            THEN 'Поляризована школа'
        WHEN PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sap.mandatory_avg_score) > mb.national_urban_median
            THEN 'Флагманська школа'
        ELSE 'Типова сільська школа'
    END AS school_rank

FROM student_academic_profiles sap
CROSS JOIN macro_benchmarks mb
WHERE 
    sap.macro_location = 'Село'
    AND sap.institution_id IS NOT NULL
GROUP BY 
    sap.institution_id,
    sap.institution_name,
    sap.reg_name,
    sap.institution_type,
    mb.national_rural_median,
    mb.national_urban_median
HAVING COUNT(*) >= 10
ORDER BY 
    mandatory_median_score DESC, 
    total_students DESC;


WITH macro_benchmarks AS (
    SELECT
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY mandatory_avg_score) 
            FILTER (WHERE macro_location = 'Село') AS national_rural_median,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY mandatory_avg_score) 
            FILTER (WHERE macro_location = 'Місто') AS national_urban_median
    FROM student_academic_profiles
),

classified_rural_schools AS (
    SELECT
        sap.institution_id,
        COUNT(*) AS total_students,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sap.mandatory_avg_score) AS school_median,
        BOOL_OR(sap.mandatory_avg_score >= 180) AS has_high_achiever,
        mb.national_rural_median,
        mb.national_urban_median
    FROM student_academic_profiles sap
    CROSS JOIN macro_benchmarks mb
    WHERE 
        sap.macro_location = 'Село'
        AND sap.institution_id IS NOT NULL
    GROUP BY 
        sap.institution_id,
        mb.national_rural_median,
        mb.national_urban_median
    HAVING COUNT(*) >= 10
)

SELECT
    CASE
        WHEN has_high_achiever AND school_median < national_rural_median 
            THEN 'Поляризована школа'
        WHEN school_median > national_urban_median 
            THEN 'Флагманська школа'
        ELSE 'Типова сільська школа'
    END AS school_cluster,
    COUNT(*) AS institutions_count,
    SUM(total_students) AS total_graduates_covered,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 
        2
    ) AS cluster_share_pct,
    ROUND(AVG(school_median)::numeric, 2) AS cluster_avg_median_score
FROM classified_rural_schools
GROUP BY 1
ORDER BY institutions_count DESC;