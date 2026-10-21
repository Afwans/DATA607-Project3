-- DATA 607 PROJECT 3 — DATASET 1: VERIFICATION AND ANALYSIS
-- Connect to data607_project3. These are read-only SELECT queries.


-- ============================================================
-- DATA 607 - PROJECT 3
-- DATASET 1: DATABASE VERIFICATION
-- ============================================================


-- ============================================================
-- 1. Verify Database Connection
-- ============================================================

SELECT
    current_database() AS database_name,
    current_user AS connected_user;


-- ============================================================
-- 2. Verify Record Counts for All Five Tables
-- ============================================================

SELECT 'company' AS table_name,
       COUNT(*) AS total_records,
       210 AS expected_records
FROM company

UNION ALL

SELECT 'job_posting', COUNT(*), 226
FROM job_posting

UNION ALL

SELECT 'salary', COUNT(*), 226
FROM salary

UNION ALL

SELECT 'skill', COUNT(*), 30
FROM skill

UNION ALL

SELECT 'job_skill', COUNT(*), 1142
FROM job_skill

ORDER BY table_name;


-- ============================================================
-- 3. Verify Primary Key Uniqueness
-- ============================================================

SELECT
    'company' AS table_name,
    COUNT(*) - COUNT(DISTINCT company_id) AS duplicate_ids
FROM company

UNION ALL

SELECT
    'job_posting',
    COUNT(*) - COUNT(DISTINCT job_id)
FROM job_posting

UNION ALL

SELECT
    'salary',
    COUNT(*) - COUNT(DISTINCT job_id)
FROM salary

UNION ALL

SELECT
    'skill',
    COUNT(*) - COUNT(DISTINCT skill_id)
FROM skill

UNION ALL

SELECT
    'job_skill',
    COUNT(*) - COUNT(DISTINCT (job_id, skill_id))
FROM job_skill;


-- ============================================================
-- 4. Verify Foreign Key Relationships
-- ============================================================

SELECT
    'job_posting -> company' AS relationship,
    COUNT(*) AS unmatched_records
FROM job_posting jp
LEFT JOIN company c
    ON jp.company_id = c.company_id
WHERE c.company_id IS NULL

UNION ALL

SELECT
    'salary -> job_posting',
    COUNT(*)
FROM salary s
LEFT JOIN job_posting jp
    ON s.job_id = jp.job_id
WHERE jp.job_id IS NULL

UNION ALL

SELECT
    'job_skill -> job_posting',
    COUNT(*)
FROM job_skill js
LEFT JOIN job_posting jp
    ON js.job_id = jp.job_id
WHERE jp.job_id IS NULL

UNION ALL

SELECT
    'job_skill -> skill',
    COUNT(*)
FROM job_skill js
LEFT JOIN skill sk
    ON js.skill_id = sk.skill_id
WHERE sk.skill_id IS NULL;


-- ============================================================
-- 5. Verify Salary Data
-- ============================================================

SELECT
    COUNT(*) AS total_salary_records,

    COUNT(*) FILTER (
        WHERE salary_usd_eligible = TRUE
    ) AS eligible_usd_salaries,

    COUNT(*) FILTER (
        WHERE salary_midpoint_annual IS NULL
    ) AS missing_midpoints,

    ROUND(
        AVG(salary_midpoint_annual) FILTER (
            WHERE salary_usd_eligible = TRUE
        ), 2
    ) AS average_eligible_salary

FROM salary;


-- ============================================================
-- 6. Verify Job-Skill Relationships
-- ============================================================

SELECT
    COUNT(*) AS total_job_skill_relationships,
    COUNT(DISTINCT job_id) AS jobs_with_skills,
    COUNT(DISTINCT skill_id) AS skills_used
FROM job_skill;


-- ============================================================
-- 7. Verify All Five Tables Can Be Joined
-- ============================================================

SELECT
    jp.job_id,
    jp.title AS job_title,
    c.company_name,
    jp.job_category_updated AS job_category,
    s.salary_midpoint_annual,
    STRING_AGG(
        sk.skill_name,
        ', ' ORDER BY sk.skill_name
    ) AS required_skills

FROM job_posting jp

LEFT JOIN company c
    ON jp.company_id = c.company_id

LEFT JOIN salary s
    ON jp.job_id = s.job_id

LEFT JOIN job_skill js
    ON jp.job_id = js.job_id

LEFT JOIN skill sk
    ON js.skill_id = sk.skill_id

GROUP BY
    jp.job_id,
    jp.title,
    c.company_name,
    jp.job_category_updated,
    s.salary_midpoint_annual

ORDER BY jp.job_id

LIMIT 10;




-- =====================================================
-- FINAL DATABASE VERIFICATION
-- =====================================================

SELECT
    'company' AS table_name,
    COUNT(*) AS actual_records,
    210 AS expected_records
FROM company

UNION ALL

SELECT 'job_posting', COUNT(*), 226
FROM job_posting

UNION ALL

SELECT 'salary', COUNT(*), 226
FROM salary

UNION ALL

SELECT 'skill', COUNT(*), 30
FROM skill

UNION ALL

SELECT 'job_skill', COUNT(*), 1142
FROM job_skill

ORDER BY table_name;


-- =====================================================
-- Step 12.1: Most In-Demand Data Science Skills
-- =====================================================

SELECT
    s.skill_name,
    COUNT(DISTINCT js.job_id) AS jobs_requiring_skill,
    ROUND(
        COUNT(DISTINCT js.job_id) * 100.0 /
        (SELECT COUNT(*) FROM job_posting),
        2
    ) AS percentage_of_jobs

FROM skill s

LEFT JOIN job_skill js
    ON s.skill_id = js.skill_id

GROUP BY
    s.skill_id,
    s.skill_name

ORDER BY
    jobs_requiring_skill DESC,
    s.skill_name;




-- =====================================================
-- Step 12.2: Median Salary by Technical Skill
-- =====================================================

SELECT
    sk.skill_name,

    COUNT(DISTINCT js.job_id) AS total_jobs_requiring_skill,

    COUNT(DISTINCT js.job_id) FILTER (
        WHERE sa.salary_usd_eligible = TRUE
          AND sa.salary_midpoint_annual IS NOT NULL
    ) AS jobs_with_valid_salary,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY sa.salary_midpoint_annual
        ) FILTER (
            WHERE sa.salary_usd_eligible = TRUE
              AND sa.salary_midpoint_annual IS NOT NULL
        )::NUMERIC,
        2
    ) AS median_annual_salary,

    ROUND(
        AVG(sa.salary_midpoint_annual) FILTER (
            WHERE sa.salary_usd_eligible = TRUE
              AND sa.salary_midpoint_annual IS NOT NULL
        ),
        2
    ) AS average_annual_salary

FROM skill sk

LEFT JOIN job_skill js
    ON sk.skill_id = js.skill_id

LEFT JOIN salary sa
    ON js.job_id = sa.job_id

GROUP BY
    sk.skill_id,
    sk.skill_name

ORDER BY
    median_annual_salary DESC NULLS LAST;


-- =====================================================
-- Step 12.3: Skill Demand vs. Median Salary
-- =====================================================

SELECT
    sk.skill_name,

    COUNT(DISTINCT js.job_id) AS jobs_requiring_skill,

    ROUND(
        COUNT(DISTINCT js.job_id) * 100.0 /
        (SELECT COUNT(*) FROM job_posting),
        2
    ) AS demand_percentage,

    COUNT(sa.salary_midpoint_annual) FILTER (
        WHERE sa.salary_usd_eligible = TRUE
    ) AS valid_salary_count,

    ROUND(
        (
            PERCENTILE_CONT(0.5) WITHIN GROUP (
                ORDER BY sa.salary_midpoint_annual
            ) FILTER (
                WHERE sa.salary_usd_eligible = TRUE
            )
        )::NUMERIC,
        2
    ) AS median_annual_salary

FROM skill sk

LEFT JOIN job_skill js
    ON sk.skill_id = js.skill_id

LEFT JOIN salary sa
    ON js.job_id = sa.job_id

GROUP BY
    sk.skill_id,
    sk.skill_name

ORDER BY
    jobs_requiring_skill DESC;


-- Step 12.4: Median Annual Salary by Job Category

SELECT
    jp.job_category_updated AS job_category,

    COUNT(*) AS total_job_postings,

    COUNT(*) FILTER (
        WHERE sa.salary_usd_eligible = TRUE
          AND sa.salary_midpoint_annual IS NOT NULL
    ) AS jobs_with_valid_salary,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY sa.salary_midpoint_annual
        ) FILTER (
            WHERE sa.salary_usd_eligible = TRUE
              AND sa.salary_midpoint_annual IS NOT NULL
        )::NUMERIC,
        2
    ) AS median_annual_salary,

    ROUND(
        AVG(sa.salary_midpoint_annual) FILTER (
            WHERE sa.salary_usd_eligible = TRUE
              AND sa.salary_midpoint_annual IS NOT NULL
        ),
        2
    ) AS average_annual_salary

FROM job_posting jp

LEFT JOIN salary sa
    ON jp.job_id = sa.job_id

GROUP BY jp.job_category_updated

ORDER BY median_annual_salary DESC NULLS LAST;



-- Step 12.5: AI Skill Demand by Job Category

SELECT
    jp.job_category_updated AS job_category,

    COUNT(DISTINCT jp.job_id) AS total_jobs,

    COUNT(DISTINCT jp.job_id) FILTER (
        WHERE sk.skill_name IN (
            'Machine Learning',
            'LLM',
            'Generative AI',
            'Deep Learning',
            'PyTorch',
            'TensorFlow'
        )
    ) AS jobs_requesting_ai_skills,

    ROUND(
        100.0 * COUNT(DISTINCT jp.job_id) FILTER (
            WHERE sk.skill_name IN (
                'Machine Learning',
                'LLM',
                'Generative AI',
                'Deep Learning',
                'PyTorch',
                'TensorFlow'
            )
        ) / NULLIF(COUNT(DISTINCT jp.job_id), 0),
        2
    ) AS ai_skill_percentage

FROM job_posting jp

LEFT JOIN job_skill js
    ON jp.job_id = js.job_id

LEFT JOIN skill sk
    ON js.skill_id = sk.skill_id

GROUP BY jp.job_category_updated

ORDER BY ai_skill_percentage DESC;

-- Step 12.6: AI Skills vs. Salary Within Job Categories

WITH job_ai_status AS (
    SELECT
        jp.job_id,
        jp.job_category_updated AS job_category,
        sa.salary_midpoint_annual,

        EXISTS (
            SELECT 1
            FROM job_skill js
            JOIN skill sk
                ON js.skill_id = sk.skill_id
            WHERE js.job_id = jp.job_id
              AND sk.skill_name IN (
                  'Machine Learning',
                  'LLM',
                  'Generative AI',
                  'Deep Learning',
                  'PyTorch',
                  'TensorFlow'
              )
        ) AS has_ai_skill

    FROM job_posting jp
    JOIN salary sa
        ON jp.job_id = sa.job_id

    WHERE sa.salary_usd_eligible = TRUE
      AND sa.salary_midpoint_annual IS NOT NULL
)

SELECT
    job_category,

    CASE
        WHEN has_ai_skill
            THEN 'AI Skills Requested'
        ELSE 'No AI Skills Requested'
    END AS ai_skill_group,

    COUNT(*) AS jobs_with_valid_salary,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY salary_midpoint_annual
        )::NUMERIC,
        2
    ) AS median_annual_salary,

    ROUND(
        AVG(salary_midpoint_annual),
        2
    ) AS average_annual_salary

FROM job_ai_status

GROUP BY
    job_category,
    has_ai_skill

ORDER BY
    job_category,
    has_ai_skill DESC;


-- DATA 607 Project 3 - Final Quality Checks

SELECT
    (SELECT COUNT(*) FROM job_posting)
        AS total_jobs,

    (SELECT COUNT(*) FROM salary
     WHERE salary_usd_eligible = TRUE)
        AS eligible_salary_records,

    (SELECT COUNT(*) FROM salary
     WHERE salary_usd_eligible = TRUE
       AND salary_midpoint_annual IS NULL)
        AS eligible_salaries_missing_midpoint,

    (SELECT COUNT(*) FROM (
        SELECT job_id, skill_id
        FROM job_skill
        GROUP BY job_id, skill_id
        HAVING COUNT(*) > 1
    ) duplicates)
        AS duplicate_job_skill_pairs,

    (SELECT COUNT(*)
     FROM job_posting jp
     WHERE NOT EXISTS (
         SELECT 1
         FROM job_skill js
         WHERE js.job_id = jp.job_id
     ))
        AS jobs_without_tracked_skills;

-- ============================================================
-- Step 12.7: Date Posted - Daily Job Posting Counts
-- ============================================================
-- Read-only. Each posting is counted on its calendar date.
SELECT
    posted_at::date AS posting_date,
    COUNT(*) AS total_jobs
FROM public.job_posting
WHERE posted_at IS NOT NULL
GROUP BY posted_at::date
ORDER BY posting_date;

-- ============================================================
-- Step 12.8: Date Posted - Daily Counts by Job Category
-- ============================================================
SELECT
    posted_at::date AS posting_date,
    job_category_updated AS job_category,
    COUNT(*) AS total_jobs
FROM public.job_posting
WHERE posted_at IS NOT NULL
GROUP BY posted_at::date, job_category_updated
ORDER BY posting_date, job_category;

-- ============================================================
-- Step 12.9: Date Posted - Quality and Coverage Check
-- ============================================================
SELECT
    COUNT(*) AS total_jobs,
    COUNT(posted_at) AS valid_posting_dates,
    COUNT(*) FILTER (WHERE posted_at IS NULL) AS missing_posting_dates,
    MIN(posted_at)::date AS earliest_date,
    MAX(posted_at)::date AS latest_date,
    COUNT(DISTINCT posted_at::date) AS distinct_posting_days
FROM public.job_posting;
