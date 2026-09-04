SET search_path TO nmt_2025, public;

WITH participant_individual_metrics AS (
    SELECT
        out_id,
        test_date,
        participant_status,
        AVG(scaled_score) FILTER (
            WHERE subject_code IN ('Math', 'Ukr', 'Hist')
        ) AS mandatory_rating_score,
        BOOL_OR(
            scaled_score = 0.0 
            AND subject_code IN ('Math', 'Ukr', 'Hist')
        ) AS failed_mandatory
    FROM clean_exam_results
    GROUP BY
        out_id,
        test_date,
        participant_status
),

daily_sessions AS (
    SELECT 
        test_date,
        CASE
            WHEN EXTRACT(MONTH FROM test_date) = 5 THEN 'Травневі суботні сесії'
            WHEN EXTRACT(MONTH FROM test_date) = 6 THEN 'Червнева основна сесія'
            WHEN EXTRACT(MONTH FROM test_date) = 7 THEN 'Липнева додаткова сесія'
        END AS session_phase,
        CASE EXTRACT(ISODOW FROM test_date)
            WHEN 1 THEN 'Понеділок'
            WHEN 2 THEN 'Вівторок'
            WHEN 3 THEN 'Середа'
            WHEN 4 THEN 'Четвер'
            WHEN 5 THEN 'П''ятниця'
            WHEN 6 THEN 'Субота'
            WHEN 7 THEN 'Неділя'
        END AS day_of_week,

        COUNT(out_id) AS total_participants,
        ROUND(
            100.0 * COUNT(out_id) FILTER (WHERE participant_status = 'Випускник поточного року')
            / NULLIF(COUNT(out_id), 0),
            1
        ) AS current_year_graduates_pct,
        ROUND(
            100.0 * COUNT(out_id) FILTER (WHERE participant_status = 'Випускник минулих років')
            / NULLIF(COUNT(out_id), 0),
            1
        ) AS previous_year_graduates_pct,
        ROUND(
            100.0 * COUNT(out_id) FILTER (WHERE participant_status = 'Установа виконання покарань')
            / NULLIF(COUNT(out_id), 0),
            1
        ) AS penitentiary_graduates_pct,

        ROUND(AVG(mandatory_rating_score)::NUMERIC, 2) AS avg_scaled_score_overall,
        ROUND(
            AVG(mandatory_rating_score) FILTER (
                WHERE participant_status = 'Випускник поточного року'
            )::NUMERIC, 
            2
        ) AS avg_score_current_year,
        ROUND(
            (PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY mandatory_rating_score))::NUMERIC, 
            2
        ) AS median_scaled_score_overall,
        ROUND(
            (PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY mandatory_rating_score) FILTER(
                WHERE participant_status = 'Випускник поточного року'
            ))::NUMERIC, 
            2
        ) AS median_score_current_year,
        ROUND(
            100.0 * COUNT(out_id) FILTER (WHERE failed_mandatory = TRUE)
            / NULLIF(COUNT(out_id), 0),
            2
        ) AS fail_rate_mandatory
    FROM participant_individual_metrics
    GROUP BY test_date
)

SELECT
    test_date,
    ROW_NUMBER() OVER w AS seq_session_number,
    session_phase,
    day_of_week,

    total_participants,
    current_year_graduates_pct,
    previous_year_graduates_pct,
    penitentiary_graduates_pct,

    avg_scaled_score_overall,
    avg_score_current_year,
    median_scaled_score_overall,
    median_score_current_year,
    fail_rate_mandatory,

    ROUND(
        avg_score_current_year - LAG(avg_score_current_year) OVER w,
        2
    ) AS day_over_day_delta_current_year,

    ROUND(
        AVG(avg_score_current_year) OVER (
            w ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
        ),
        2
    ) AS smoothed_avg_current_year,

    ROUND(
        100.0 * SUM(total_participants) OVER w 
        / NULLIF(SUM(total_participants) OVER (), 0), 
        1
    ) AS cume_progress
FROM daily_sessions
WINDOW w AS (ORDER BY test_date);