SET search_path TO nmt_2025, public;

WITH participant_individual_metrics AS (
    SELECT
        out_id,
        CASE 
            WHEN reg_name = 'м.Київ' THEN 'Київська область' 
            ELSE reg_name 
        END AS reg_name,
        is_regional_center,
        AVG(scaled_score) AS rating_score,
        BOOL_OR(scaled_score = 0.0) AS failed
    FROM clean_exam_results
    WHERE reg_name IS NOT NULL
    GROUP BY
        out_id,
        CASE 
            WHEN reg_name = 'м.Київ' THEN 'Київська область' 
            ELSE reg_name 
        END,
        is_regional_center
),

region_aggregations AS (
    SELECT
        reg_name,

        COUNT(*) AS total_participants,
        COUNT(*) FILTER (WHERE is_regional_center) AS center_participants,
        COUNT(*) FILTER (WHERE NOT is_regional_center) AS periphery_participants,
        ROUND(100.0 * AVG(is_regional_center::INT), 1) AS center_participants_percentage,

        ROUND(
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rating_score) 
            FILTER (WHERE is_regional_center)::NUMERIC, 
            2
        ) AS median_center_score,
        ROUND(
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rating_score) 
            FILTER (WHERE NOT is_regional_center)::NUMERIC, 
            2
        ) AS median_periphery_score,

        COUNT(*) FILTER (WHERE rating_score >= 180) AS total_high_achievers,
        COUNT(*) FILTER (WHERE rating_score >= 180 AND is_regional_center) AS center_high_achievers,
        COUNT(*) FILTER (WHERE rating_score >= 180 AND NOT is_regional_center) AS periphery_high_achievers,

        COUNT(*) FILTER (WHERE failed AND is_regional_center) AS center_failed_participants,
        COUNT(*) FILTER (WHERE failed AND NOT is_regional_center) AS periphery_failed_participants

    FROM participant_individual_metrics
    GROUP BY reg_name
),

regional_indicators AS (
    SELECT
        reg_name,
        total_participants,
        center_participants,
        periphery_participants,
        center_participants_percentage,

        median_center_score,
        median_periphery_score,
        median_center_score - median_periphery_score AS delta_median,

        ROUND(
            100.0 * center_high_achievers::NUMERIC / NULLIF(center_participants, 0), 
            2
        ) AS center_high_achievers_percentage,
        ROUND(
            100.0 * periphery_high_achievers::NUMERIC / NULLIF(periphery_participants, 0), 
            2
        ) AS periphery_high_achievers_percentage,

        ROUND(
            (center_high_achievers::NUMERIC * total_participants) 
            / NULLIF(total_high_achievers::NUMERIC * center_participants, 0),
            2
        ) AS monopoly_lq_index,

        ROUND(
            100.0 * center_failed_participants::NUMERIC / NULLIF(center_participants, 0), 
            2
        ) AS center_failed_percentage,
        ROUND(
            100.0 * periphery_failed_participants::NUMERIC / NULLIF(periphery_participants, 0), 
            2
        ) AS periphery_failed_percentage,

        ROUND(
            (periphery_failed_participants::NUMERIC / NULLIF(periphery_participants, 0))
            / NULLIF(center_failed_participants::NUMERIC / NULLIF(center_participants, 0), 0),
            2
        ) AS fail_rate_ratio
    FROM region_aggregations
)

SELECT
    *,
    CASE
        WHEN monopoly_lq_index >= 1.8 THEN 'Гіпермоноцентрична'
        WHEN monopoly_lq_index >= 1.4 THEN 'Високоцентралізована'
        WHEN monopoly_lq_index >= 1.0 THEN 'Помірно централізована'
        WHEN monopoly_lq_index IS NOT NULL THEN 'Поліцентрична / Збалансована'
        ELSE 'Не визначено'
    END AS region_classification
FROM regional_indicators
ORDER BY monopoly_lq_index DESC NULLS LAST;