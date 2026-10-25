-- DATA 607 | PROJECT 3 | FINAL POSTGRESQL ANALYSIS
-- Database: data607_project3 | Schema: public | PostgreSQL 18 / pgAdmin 4

-- IMPORTANT: Run one numbered query at a time in pgAdmin to inspect results.

CREATE TABLE IF NOT EXISTS public.company (
    company_id BIGINT PRIMARY KEY,
    company_name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS public.job_posting (
    job_id TEXT PRIMARY KEY,
    company_id BIGINT NOT NULL REFERENCES public.company(company_id),
    title TEXT,
    department TEXT,
    location TEXT,
    city TEXT,
    region TEXT,
    country_code TEXT,
    workplace_type TEXT,
    employment_type TEXT,
    seniority TEXT,
    posted_at TIMESTAMP,
    first_seen_at TIMESTAMP,
    language TEXT,
    url TEXT,
    apply_url TEXT,
    description TEXT,
    is_data_science_related BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS public.salary (
    job_id TEXT PRIMARY KEY REFERENCES public.job_posting(job_id),
    salary_min NUMERIC,
    salary_max NUMERIC,
    salary_currency TEXT,
    salary_period TEXT,
    salary_text TEXT,
    salary_source TEXT,
    salary_min_annual NUMERIC,
    salary_max_annual NUMERIC,
    salary_complete BOOLEAN,
    salary_valid BOOLEAN,
    salary_outlier_flag BOOLEAN,
    salary_usd_eligible BOOLEAN,
    salary_midpoint_annual NUMERIC
);

CREATE TABLE IF NOT EXISTS public.skill (
    skill_id INTEGER PRIMARY KEY,
    source_column TEXT NOT NULL UNIQUE,
    skill_name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS public.job_skill (
    job_id TEXT NOT NULL REFERENCES public.job_posting(job_id),
    skill_id INTEGER NOT NULL REFERENCES public.skill(skill_id),
    PRIMARY KEY (job_id, skill_id)
);

CREATE TABLE IF NOT EXISTS public.data_science_classification (
    job_id TEXT PRIMARY KEY REFERENCES public.job_posting(job_id),
    job_category_updated TEXT,
    classification_updated TEXT,
    classification_basis TEXT
);


-- 1. Database connection
SELECT current_database() AS database_name, current_user AS connected_user;

-- 2. Row counts (only job postings and skills have known target counts)
SELECT 'company' AS table_name, COUNT(*) AS actual_records,
       NULL::BIGINT AS expected_records FROM public.company
UNION ALL
SELECT 'job_posting', COUNT(*), 9173 FROM public.job_posting
UNION ALL
SELECT 'salary', COUNT(*), 9173 FROM public.salary
UNION ALL
SELECT 'skill', COUNT(*), 30 FROM public.skill
UNION ALL
SELECT 'job_skill', COUNT(*), NULL::BIGINT FROM public.job_skill
UNION ALL
SELECT 'data_science_classification', COUNT(*), NULL::BIGINT
FROM public.data_science_classification
UNION ALL SELECT 'job_sector_classification', COUNT(*), 9173 FROM public.job_sector_classification
ORDER BY table_name;

-- 3. Uniqueness checks
SELECT 'company' AS table_name, COUNT(*) - COUNT(DISTINCT company_id) AS duplicate_ids
FROM public.company
UNION ALL
SELECT 'job_posting', COUNT(*) - COUNT(DISTINCT job_id) FROM public.job_posting
UNION ALL
SELECT 'salary', COUNT(*) - COUNT(DISTINCT job_id) FROM public.salary
UNION ALL
SELECT 'skill', COUNT(*) - COUNT(DISTINCT skill_id) FROM public.skill
UNION ALL
SELECT 'job_skill', COUNT(*) - COUNT(DISTINCT (job_id, skill_id)) FROM public.job_skill
UNION ALL
SELECT 'data_science_classification', COUNT(*) - COUNT(DISTINCT job_id)
FROM public.data_science_classification;

-- 4. Foreign-key and subgroup consistency checks
SELECT 'job_posting -> company' AS relationship, COUNT(*) AS unmatched_records
FROM public.job_posting jp LEFT JOIN public.company c USING (company_id)
WHERE c.company_id IS NULL
UNION ALL
SELECT 'salary -> job_posting', COUNT(*)
FROM public.salary sa LEFT JOIN public.job_posting jp USING (job_id)
WHERE jp.job_id IS NULL
UNION ALL
SELECT 'job_skill -> job_posting', COUNT(*)
FROM public.job_skill js LEFT JOIN public.job_posting jp USING (job_id)
WHERE jp.job_id IS NULL
UNION ALL
SELECT 'job_skill -> skill', COUNT(*)
FROM public.job_skill js LEFT JOIN public.skill sk USING (skill_id)
WHERE sk.skill_id IS NULL
UNION ALL
SELECT 'classification -> job_posting', COUNT(*)
FROM public.data_science_classification dc
LEFT JOIN public.job_posting jp USING (job_id)
WHERE jp.job_id IS NULL
UNION ALL
SELECT 'flag vs classification membership', COUNT(*)
FROM public.job_posting jp
WHERE jp.is_data_science_related IS DISTINCT FROM EXISTS (
    SELECT 1 FROM public.data_science_classification dc WHERE dc.job_id = jp.job_id
);

-- 5. Overall population and salary coverage
SELECT
    COUNT(*) AS all_job_postings,
    COUNT(*) FILTER (WHERE jp.is_data_science_related) AS data_science_related_jobs,
    COUNT(*) FILTER (WHERE sa.salary_usd_eligible IS TRUE
                     AND sa.salary_midpoint_annual IS NOT NULL) AS eligible_salary_jobs,
    COUNT(*) FILTER (WHERE jp.is_data_science_related
                     AND sa.salary_usd_eligible IS TRUE
                     AND sa.salary_midpoint_annual IS NOT NULL) AS eligible_ds_salary_jobs,
    COUNT(*) FILTER (WHERE jp.posted_at IS NULL) AS missing_posting_dates
FROM public.job_posting jp
LEFT JOIN public.salary sa USING (job_id);

-- 6. Technical skill demand across the full job market
SELECT sk.skill_name,
       COUNT(js.job_id) AS jobs_mentioning_skill,
       ROUND(100.0 * COUNT(js.job_id) / NULLIF(
           (SELECT COUNT(*) FROM public.job_posting), 0), 2) AS pct_of_all_jobs
FROM public.skill sk
LEFT JOIN public.job_skill js USING (skill_id)
GROUP BY sk.skill_id, sk.skill_name
ORDER BY jobs_mentioning_skill DESC, sk.skill_name;

-- 7. Full market vs Data Science-related skill demand
WITH populations AS (
    SELECT 'Full Job Market'::TEXT AS population, jp.job_id
    FROM public.job_posting jp
    UNION ALL
    SELECT 'Data Science-Related Jobs', jp.job_id
    FROM public.job_posting jp
    WHERE jp.is_data_science_related
)
SELECT p.population, sk.skill_name,
       COUNT(js.job_id) AS jobs_mentioning_skill,
       ROUND(100.0 * COUNT(js.job_id) /
         NULLIF((SELECT COUNT(*) FROM populations p2
                 WHERE p2.population = p.population), 0), 2) AS pct_of_population
FROM populations p
CROSS JOIN public.skill sk
LEFT JOIN public.job_skill js ON js.job_id = p.job_id AND js.skill_id = sk.skill_id
GROUP BY p.population, sk.skill_id, sk.skill_name
ORDER BY p.population, jobs_mentioning_skill DESC, sk.skill_name;

-- 8. Skill demand and salary midpoints (full market)
SELECT sk.skill_name,
       COUNT(js.job_id) AS jobs_mentioning_skill,
       COUNT(sa.job_id) FILTER (WHERE sa.salary_usd_eligible IS TRUE
                  AND sa.salary_midpoint_annual IS NOT NULL) AS jobs_with_eligible_salary,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (
           ORDER BY sa.salary_midpoint_annual
       ) FILTER (WHERE sa.salary_usd_eligible IS TRUE
                    AND sa.salary_midpoint_annual IS NOT NULL))::NUMERIC, 2)
           AS median_salary_midpoint_usd,
       ROUND(AVG(sa.salary_midpoint_annual) FILTER (
           WHERE sa.salary_usd_eligible IS TRUE
             AND sa.salary_midpoint_annual IS NOT NULL), 2)
           AS mean_salary_midpoint_usd
FROM public.skill sk
LEFT JOIN public.job_skill js USING (skill_id)
LEFT JOIN public.salary sa ON sa.job_id = js.job_id
GROUP BY sk.skill_id, sk.skill_name
ORDER BY jobs_mentioning_skill DESC;

-- 9. Overall salary comparison: subgroup overlaps with full market
WITH salary_populations AS (
    SELECT 'Full Job Market'::TEXT AS population, sa.salary_midpoint_annual
    FROM public.salary sa
    WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL
    UNION ALL
    SELECT 'Data Science-Related Jobs', sa.salary_midpoint_annual
    FROM public.salary sa
    JOIN public.job_posting jp USING (job_id)
    WHERE jp.is_data_science_related AND sa.salary_usd_eligible IS TRUE
      AND sa.salary_midpoint_annual IS NOT NULL
)
SELECT population, COUNT(*) AS eligible_jobs,
       ROUND(AVG(salary_midpoint_annual), 2) AS mean_salary_midpoint_usd,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (
           ORDER BY salary_midpoint_annual))::NUMERIC, 2) AS median_salary_midpoint_usd
FROM salary_populations
GROUP BY population
ORDER BY population;

-- 10. Median salary by Data Science job category
SELECT dc.job_category_updated AS job_category,
       COUNT(*) AS total_jobs,
       COUNT(sa.job_id) FILTER (WHERE sa.salary_usd_eligible IS TRUE
             AND sa.salary_midpoint_annual IS NOT NULL) AS jobs_with_eligible_salary,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (
           ORDER BY sa.salary_midpoint_annual
       ) FILTER (WHERE sa.salary_usd_eligible IS TRUE
                   AND sa.salary_midpoint_annual IS NOT NULL))::NUMERIC, 2)
           AS median_salary_midpoint_usd
FROM public.data_science_classification dc
LEFT JOIN public.salary sa USING (job_id)
GROUP BY dc.job_category_updated
ORDER BY median_salary_midpoint_usd DESC NULLS LAST;

-- 11. AI skill demand by Data Science job category
WITH ai_status AS (
    SELECT dc.job_id, dc.job_category_updated,
           EXISTS (
             SELECT 1 FROM public.job_skill js
             JOIN public.skill sk USING (skill_id)
             WHERE js.job_id = dc.job_id
               AND sk.skill_name IN (
                 'Machine Learning', 'LLM', 'Generative AI',
                 'Deep Learning', 'PyTorch', 'TensorFlow'
               )
           ) AS mentions_ai_skill
    FROM public.data_science_classification dc
)
SELECT job_category_updated AS job_category, COUNT(*) AS total_jobs,
       COUNT(*) FILTER (WHERE mentions_ai_skill) AS jobs_mentioning_ai_skill,
       ROUND(100.0 * COUNT(*) FILTER (WHERE mentions_ai_skill) /
             NULLIF(COUNT(*), 0), 2) AS ai_skill_percentage
FROM ai_status
GROUP BY job_category_updated
ORDER BY ai_skill_percentage DESC;

-- 12. AI skills vs salary within Data Science categories
WITH ai_status AS (
    SELECT dc.job_id, dc.job_category_updated,
           sa.salary_midpoint_annual,
           EXISTS (
             SELECT 1 FROM public.job_skill js
             JOIN public.skill sk USING (skill_id)
             WHERE js.job_id = dc.job_id
               AND sk.skill_name IN (
                 'Machine Learning', 'LLM', 'Generative AI',
                 'Deep Learning', 'PyTorch', 'TensorFlow'
               )
           ) AS mentions_ai_skill
    FROM public.data_science_classification dc
    JOIN public.salary sa USING (job_id)
    WHERE sa.salary_usd_eligible IS TRUE
      AND sa.salary_midpoint_annual IS NOT NULL
)
SELECT job_category_updated AS job_category,
       CASE WHEN mentions_ai_skill THEN 'AI Skills Mentioned'
            ELSE 'No Tracked AI Skills Mentioned' END AS skill_group,
       COUNT(*) AS eligible_jobs,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (
         ORDER BY salary_midpoint_annual))::NUMERIC, 2) AS median_salary_midpoint_usd
FROM ai_status
GROUP BY job_category_updated, mentions_ai_skill
ORDER BY job_category_updated, mentions_ai_skill DESC;

-- 13. Full-market daily posting counts
SELECT posted_at::DATE AS posting_date, COUNT(*) AS total_jobs
FROM public.job_posting
WHERE posted_at IS NOT NULL
GROUP BY posted_at::DATE
ORDER BY posting_date;

-- 14. Daily posting counts by population (subgroup is part of full market)
SELECT posted_at::DATE AS posting_date,
       COUNT(*) AS all_jobs,
       COUNT(*) FILTER (WHERE is_data_science_related) AS data_science_related_jobs
FROM public.job_posting
WHERE posted_at IS NOT NULL
GROUP BY posted_at::DATE
ORDER BY posting_date;

-- 15. Daily Data Science category counts
SELECT jp.posted_at::DATE AS posting_date,
       dc.job_category_updated AS job_category,
       COUNT(*) AS total_jobs
FROM public.data_science_classification dc
JOIN public.job_posting jp USING (job_id)
WHERE jp.posted_at IS NOT NULL
GROUP BY jp.posted_at::DATE, dc.job_category_updated
ORDER BY posting_date, job_category;

-- 16. Posting-date quality and coverage
SELECT COUNT(*) AS total_jobs, COUNT(posted_at) AS valid_posting_dates,
       COUNT(*) FILTER (WHERE posted_at IS NULL) AS missing_posting_dates,
       MIN(posted_at)::DATE AS earliest_date,
       MAX(posted_at)::DATE AS latest_date,
       COUNT(DISTINCT posted_at::DATE) AS distinct_posting_days
FROM public.job_posting;

-- 17. Example join across all seven tables
SELECT jp.job_id, jp.title AS job_title, c.company_name,
       dc.job_category_updated AS data_science_category,
       sa.salary_midpoint_annual,
       STRING_AGG(DISTINCT sk.skill_name, ', ' ORDER BY sk.skill_name) AS mentioned_skills
FROM public.job_posting jp
JOIN public.company c USING (company_id)
LEFT JOIN public.salary sa USING (job_id)
LEFT JOIN public.data_science_classification dc USING (job_id)
LEFT JOIN public.job_skill js USING (job_id)
LEFT JOIN public.skill sk USING (skill_id)
GROUP BY jp.job_id, jp.title, c.company_name,
         dc.job_category_updated, sa.salary_midpoint_annual
ORDER BY jp.job_id
LIMIT 10;


SELECT COALESCE(NULLIF(to_jsonb(jsc)->>'job_function_updated',''),NULLIF(to_jsonb(jsc)->>'job_sector_updated',''),NULLIF(to_jsonb(jsc)->>'job_function',''),NULLIF(to_jsonb(jsc)->>'job_sector',''),NULLIF(to_jsonb(jsc)->>'job_category',''),NULLIF(to_jsonb(jsc)->>'sector','')) AS job_function_v3,
       COUNT(*) AS total_postings,
       ROUND(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM public.job_posting),0),2)
           AS pct_of_all_postings
FROM public.job_sector_classification jsc
GROUP BY 1 ORDER BY total_postings DESC, job_function_v3;

SELECT COUNT(*) AS classification_rows,
       COUNT(DISTINCT job_id) AS distinct_classified_jobs,
       COUNT(*) FILTER (WHERE COALESCE(NULLIF(to_jsonb(jsc)->>'job_function_updated',''),NULLIF(to_jsonb(jsc)->>'job_sector_updated',''),NULLIF(to_jsonb(jsc)->>'job_function',''),NULLIF(to_jsonb(jsc)->>'job_sector',''),NULLIF(to_jsonb(jsc)->>'job_category',''),NULLIF(to_jsonb(jsc)->>'sector','')) IS NULL) AS missing_category_labels,
       (SELECT COUNT(*) FROM public.job_posting jp
        WHERE NOT EXISTS (SELECT 1 FROM public.job_sector_classification jsc
                          WHERE jsc.job_id = jp.job_id)) AS postings_without_classification
FROM public.job_sector_classification jsc;

SELECT COALESCE(NULLIF(to_jsonb(jsc)->>'job_function_updated',''),NULLIF(to_jsonb(jsc)->>'job_sector_updated',''),NULLIF(to_jsonb(jsc)->>'job_function',''),NULLIF(to_jsonb(jsc)->>'job_sector',''),NULLIF(to_jsonb(jsc)->>'job_category',''),NULLIF(to_jsonb(jsc)->>'sector','')) AS job_function_v3,
       COUNT(*) AS total_postings,
       COUNT(*) FILTER (WHERE sa.salary_usd_eligible IS TRUE
                       AND sa.salary_midpoint_annual IS NOT NULL) AS salary_eligible_jobs,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sa.salary_midpoint_annual)
              FILTER (WHERE sa.salary_usd_eligible IS TRUE
                      AND sa.salary_midpoint_annual IS NOT NULL))::NUMERIC,2)
           AS median_salary_midpoint_usd
FROM public.job_sector_classification jsc
JOIN public.job_posting jp ON jp.job_id = jsc.job_id
LEFT JOIN public.salary sa ON sa.job_id = jp.job_id
GROUP BY 1 ORDER BY total_postings DESC;

SELECT COALESCE(NULLIF(to_jsonb(jsc)->>'job_function_updated',''),NULLIF(to_jsonb(jsc)->>'job_sector_updated',''),NULLIF(to_jsonb(jsc)->>'job_function',''),NULLIF(to_jsonb(jsc)->>'job_sector',''),NULLIF(to_jsonb(jsc)->>'job_category',''),NULLIF(to_jsonb(jsc)->>'sector','')) AS job_function_v3,
       COUNT(*) AS all_postings,
       COUNT(*) FILTER (WHERE jp.is_data_science_related IS TRUE) AS data_science_postings
FROM public.job_sector_classification jsc
JOIN public.job_posting jp ON jp.job_id = jsc.job_id
GROUP BY 1 ORDER BY all_postings DESC;

SELECT COUNT(*) AS orphaned_job_function_rows
FROM public.job_sector_classification jsc
LEFT JOIN public.job_posting jp ON jp.job_id = jsc.job_id
WHERE jp.job_id IS NULL;
