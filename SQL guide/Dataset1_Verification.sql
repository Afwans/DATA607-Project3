-- DATA 607 | PROJECT 3 | FINAL POSTGRESQL ANALYSIS
-- Database: data607_project3 | Schema: public | PostgreSQL 18 / pgAdmin 4

-- IMPORTANT: Run one numbered query at a time in pgAdmin to inspect results.

SELECT current_database() AS database_name, current_user AS connected_user;

SELECT 'company' AS table_name, COUNT(*) AS records FROM public.company
UNION ALL SELECT 'job_posting', COUNT(*) FROM public.job_posting
UNION ALL SELECT 'salary', COUNT(*) FROM public.salary
UNION ALL SELECT 'skill', COUNT(*) FROM public.skill
UNION ALL SELECT 'job_skill', COUNT(*) FROM public.job_skill
UNION ALL SELECT 'data_science_classification', COUNT(*)
FROM public.data_science_classification
UNION ALL SELECT 'job_sector_classification', COUNT(*) FROM public.job_sector_classification
ORDER BY table_name;

SELECT
    (SELECT COUNT(*) FROM public.job_posting) AS total_job_postings,
    (SELECT COUNT(*) FROM public.job_posting WHERE is_data_science_related)
        AS data_science_related_jobs,
    (SELECT COUNT(*) FROM public.data_science_classification)
        AS classified_jobs,
    (SELECT COUNT(*) FROM public.salary WHERE salary_usd_eligible IS TRUE)
        AS eligible_usd_salary_records,
    (SELECT COUNT(*) FROM public.skill) AS tracked_skills,
    (SELECT COUNT(*) FROM public.job_skill) AS job_skill_links,
    (SELECT COUNT(*) FROM public.job_posting WHERE posted_at IS NULL)
        AS missing_posting_dates;

SELECT 'company -> posting' AS relationship, COUNT(*) AS unmatched
FROM public.job_posting jp LEFT JOIN public.company c USING (company_id)
WHERE c.company_id IS NULL
UNION ALL
SELECT 'salary -> posting', COUNT(*)
FROM public.salary sa LEFT JOIN public.job_posting jp USING (job_id)
WHERE jp.job_id IS NULL
UNION ALL
SELECT 'job_skill -> posting', COUNT(*)
FROM public.job_skill js LEFT JOIN public.job_posting jp USING (job_id)
WHERE jp.job_id IS NULL
UNION ALL
SELECT 'job_skill -> skill', COUNT(*)
FROM public.job_skill js LEFT JOIN public.skill sk USING (skill_id)
WHERE sk.skill_id IS NULL
UNION ALL
SELECT 'classification -> posting', COUNT(*)
FROM public.data_science_classification dc
LEFT JOIN public.job_posting jp USING (job_id)
WHERE jp.job_id IS NULL
UNION ALL
SELECT 'flag vs classification', COUNT(*)
FROM public.job_posting jp
WHERE jp.is_data_science_related IS DISTINCT FROM EXISTS (
    SELECT 1 FROM public.data_science_classification dc
    WHERE dc.job_id = jp.job_id
);


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

WITH actual AS (
 SELECT 'company' AS table_name,COUNT(*) AS actual_count,3969::BIGINT AS expected_count FROM public.company
 UNION ALL SELECT 'job_posting',COUNT(*),9173 FROM public.job_posting
 UNION ALL SELECT 'salary',COUNT(*),9173 FROM public.salary
 UNION ALL SELECT 'skill',COUNT(*),30 FROM public.skill
 UNION ALL SELECT 'job_skill',COUNT(*),7140 FROM public.job_skill
 UNION ALL SELECT 'data_science_classification',COUNT(*),229 FROM public.data_science_classification
 UNION ALL SELECT 'job_sector_classification',COUNT(*),9173 FROM public.job_sector_classification
)
SELECT *,CASE WHEN actual_count=expected_count THEN 'PASS' ELSE 'REVIEW' END AS status
FROM actual ORDER BY table_name;

SELECT COUNT(*) FILTER (WHERE sa.salary_usd_eligible IS TRUE
                         AND sa.salary_midpoint_annual IS NOT NULL) AS eligible_market,
       COUNT(*) FILTER (WHERE jp.is_data_science_related IS TRUE
                         AND sa.salary_usd_eligible IS TRUE
                         AND sa.salary_midpoint_annual IS NOT NULL) AS eligible_data_science
FROM public.job_posting jp LEFT JOIN public.salary sa USING (job_id);
