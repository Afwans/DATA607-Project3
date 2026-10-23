-- DATA 607 | PROJECT 3 | FINAL POSTGRESQL ANALYSIS
-- Database: data607_project3 | Schema: public | PostgreSQL 18 / pgAdmin 4

-- IMPORTANT: Run one numbered query at a time in pgAdmin to inspect results.

-- 00. DATASET COUNTS AND INTEGRITY
SELECT 'company' AS table_name, COUNT(*) AS row_count FROM public.company
UNION ALL SELECT 'job_posting', COUNT(*) FROM public.job_posting
UNION ALL SELECT 'salary', COUNT(*) FROM public.salary
UNION ALL SELECT 'skill', COUNT(*) FROM public.skill
UNION ALL SELECT 'job_skill', COUNT(*) FROM public.job_skill
UNION ALL SELECT 'data_science_classification', COUNT(*) FROM public.data_science_classification
UNION ALL SELECT 'job_sector_classification', COUNT(*) FROM public.job_sector_classification;

-- 00B. FOREIGN-KEY ORPHAN COUNTS (expected: 0 for each relationship)
SELECT 'job_posting -> company' AS relationship, COUNT(*) AS unmatched_rows
FROM public.job_posting jp LEFT JOIN public.company c ON jp.company_id=c.company_id
WHERE jp.company_id IS NOT NULL AND c.company_id IS NULL
UNION ALL
SELECT 'salary -> job_posting', COUNT(*) FROM public.salary s LEFT JOIN public.job_posting jp ON s.job_id=jp.job_id WHERE jp.job_id IS NULL
UNION ALL
SELECT 'job_skill -> job_posting', COUNT(*) FROM public.job_skill js LEFT JOIN public.job_posting jp ON js.job_id=jp.job_id WHERE jp.job_id IS NULL
UNION ALL
SELECT 'job_skill -> skill', COUNT(*) FROM public.job_skill js LEFT JOIN public.skill sk ON js.skill_id=sk.skill_id WHERE sk.skill_id IS NULL
UNION ALL
SELECT 'classification -> job_posting', COUNT(*) FROM public.data_science_classification dc LEFT JOIN public.job_posting jp ON dc.job_id=jp.job_id WHERE jp.job_id IS NULL;

-- 01. TECHNICAL SKILL DEMAND: ALL JOB POSTINGS
SELECT sk.skill_name, COUNT(DISTINCT js.job_id) AS jobs_mentioning_skill,
 ROUND(100.0*COUNT(DISTINCT js.job_id)/(SELECT COUNT(*) FROM public.job_posting),2) AS percentage_of_jobs
FROM public.skill sk LEFT JOIN public.job_skill js ON sk.skill_id=js.skill_id
GROUP BY sk.skill_id,sk.skill_name ORDER BY jobs_mentioning_skill DESC,sk.skill_name;

-- 02. TECHNICAL SKILL DEMAND: FULL MARKET VS DATA SCIENCE SUBGROUP
WITH denominators AS (
 SELECT COUNT(*) AS all_jobs, COUNT(*) FILTER (WHERE is_data_science_related IS TRUE) AS ds_jobs
 FROM public.job_posting
)
SELECT sk.skill_name,COUNT(DISTINCT js.job_id) AS full_market_jobs,
 ROUND(100.0*COUNT(DISTINCT js.job_id)/NULLIF(d.all_jobs,0),2) AS full_market_pct,
 COUNT(DISTINCT js.job_id) FILTER (WHERE jp.is_data_science_related IS TRUE) AS data_science_jobs,
 ROUND(100.0*COUNT(DISTINCT js.job_id) FILTER (WHERE jp.is_data_science_related IS TRUE)/NULLIF(d.ds_jobs,0),2) AS data_science_pct
FROM public.skill sk LEFT JOIN public.job_skill js ON sk.skill_id=js.skill_id
LEFT JOIN public.job_posting jp ON js.job_id=jp.job_id CROSS JOIN denominators d
GROUP BY sk.skill_id,sk.skill_name,d.all_jobs,d.ds_jobs
ORDER BY data_science_jobs DESC,sk.skill_name;

-- 03. SALARY OVERVIEW: FULL MARKET VS DATA SCIENCE SUBGROUP
SELECT 'Full Job Market' AS population,COUNT(*) AS eligible_jobs,
 ROUND(AVG(s.salary_midpoint_annual),2) AS average_salary,
 ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY s.salary_midpoint_annual)::NUMERIC,2) AS median_salary
FROM public.salary s WHERE s.salary_usd_eligible IS TRUE AND s.salary_midpoint_annual IS NOT NULL
UNION ALL
SELECT 'Data Science-Related Jobs',COUNT(*),ROUND(AVG(s.salary_midpoint_annual),2),
 ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY s.salary_midpoint_annual)::NUMERIC,2)
FROM public.salary s JOIN public.job_posting jp ON s.job_id=jp.job_id
WHERE s.salary_usd_eligible IS TRUE AND s.salary_midpoint_annual IS NOT NULL AND jp.is_data_science_related IS TRUE;

-- 04. MEDIAN SALARY BY SKILL: FULL MARKET
SELECT sk.skill_name,COUNT(DISTINCT js.job_id) AS jobs_with_skill,
 COUNT(DISTINCT js.job_id) FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL) AS salary_eligible_jobs,
 ROUND(AVG(sa.salary_midpoint_annual) FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL),2) AS average_salary,
 ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sa.salary_midpoint_annual)
 FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL))::NUMERIC,2) AS median_salary
FROM public.skill sk LEFT JOIN public.job_skill js ON sk.skill_id=js.skill_id
LEFT JOIN public.salary sa ON js.job_id=sa.job_id
GROUP BY sk.skill_id,sk.skill_name ORDER BY median_salary DESC NULLS LAST;

-- 05. MEDIAN SALARY BY SKILL: DATA SCIENCE SUBGROUP
SELECT sk.skill_name,COUNT(DISTINCT js.job_id) AS jobs_with_skill,
 COUNT(DISTINCT js.job_id) FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL) AS salary_eligible_jobs,
 ROUND(AVG(sa.salary_midpoint_annual) FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL),2) AS average_salary,
 ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sa.salary_midpoint_annual)
 FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL))::NUMERIC,2) AS median_salary
FROM public.skill sk JOIN public.job_skill js ON sk.skill_id=js.skill_id
JOIN public.job_posting jp ON js.job_id=jp.job_id LEFT JOIN public.salary sa ON js.job_id=sa.job_id
WHERE jp.is_data_science_related IS TRUE
GROUP BY sk.skill_id,sk.skill_name ORDER BY median_salary DESC NULLS LAST;

-- 06. SALARY BY DATA SCIENCE JOB CATEGORY
SELECT dc.job_category_updated AS job_category,COUNT(*) AS total_jobs,
 COUNT(*) FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL) AS salary_eligible_jobs,
 ROUND(AVG(sa.salary_midpoint_annual) FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL),2) AS average_salary,
 ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sa.salary_midpoint_annual)
 FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL))::NUMERIC,2) AS median_salary
FROM public.data_science_classification dc LEFT JOIN public.salary sa ON dc.job_id=sa.job_id
GROUP BY dc.job_category_updated ORDER BY median_salary DESC NULLS LAST;

-- 07. AI SKILL MENTIONS BY DATA SCIENCE JOB CATEGORY
SELECT dc.job_category_updated AS job_category,COUNT(DISTINCT dc.job_id) AS total_jobs,
 COUNT(DISTINCT dc.job_id) FILTER (WHERE sk.skill_name IN ('Machine Learning','LLM','Generative Ai','Deep Learning','PyTorch','TensorFlow')) AS jobs_mentioning_ai_skills,
 ROUND(100.0*COUNT(DISTINCT dc.job_id) FILTER (WHERE sk.skill_name IN ('Machine Learning','LLM','Generative Ai','Deep Learning','PyTorch','TensorFlow'))
 /NULLIF(COUNT(DISTINCT dc.job_id),0),2) AS ai_skill_percentage
FROM public.data_science_classification dc LEFT JOIN public.job_skill js ON dc.job_id=js.job_id
LEFT JOIN public.skill sk ON js.skill_id=sk.skill_id
GROUP BY dc.job_category_updated ORDER BY ai_skill_percentage DESC;

-- 08. AI VS NON-AI SALARY COMPARISON WITHIN DATA SCIENCE JOB CATEGORIES
WITH ai_job_flags AS (
 SELECT dc.job_id,dc.job_category_updated AS job_category,
 EXISTS (SELECT 1 FROM public.job_skill js JOIN public.skill sk ON js.skill_id=sk.skill_id
 WHERE js.job_id=dc.job_id AND sk.skill_name IN ('Machine Learning','LLM','Generative Ai','Deep Learning','PyTorch','TensorFlow')) AS mentions_ai_skill
 FROM public.data_science_classification dc
)
SELECT aj.job_category,CASE WHEN aj.mentions_ai_skill THEN 'Mentions AI Skills' ELSE 'Does Not Mention AI Skills' END AS ai_skill_group,
 COUNT(*) AS total_jobs,COUNT(*) FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL) AS salary_eligible_jobs,
 ROUND(AVG(sa.salary_midpoint_annual) FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL),2) AS average_salary,
 ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sa.salary_midpoint_annual)
 FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL))::NUMERIC,2) AS median_salary
FROM ai_job_flags aj LEFT JOIN public.salary sa ON aj.job_id=sa.job_id
GROUP BY aj.job_category,aj.mentions_ai_skill ORDER BY aj.job_category,aj.mentions_ai_skill DESC;

-- 09. MONTHLY POSTING COUNTS (only one observed month; NOT a time trend)
SELECT DATE_TRUNC('month',posted_at)::DATE AS posting_month,COUNT(*) AS total_job_postings,
 COUNT(*) FILTER (WHERE is_data_science_related IS TRUE) AS data_science_postings,
 ROUND(100.0*COUNT(*) FILTER (WHERE is_data_science_related IS TRUE)/NULLIF(COUNT(*),0),2) AS data_science_percentage
FROM public.job_posting WHERE posted_at IS NOT NULL
GROUP BY DATE_TRUNC('month',posted_at)::DATE ORDER BY posting_month;

-- 10. POSTING DATE COVERAGE AND FIRST-SEEN DATE COVERAGE
SELECT MIN(posted_at) AS earliest_posted_at,MAX(posted_at) AS latest_posted_at,
 COUNT(DISTINCT posted_at::DATE) AS distinct_posting_days,COUNT(*) AS total_jobs,
 COUNT(*) FILTER (WHERE posted_at IS NULL) AS missing_posted_dates,
 MIN(first_seen_at) AS earliest_first_seen,MAX(first_seen_at) AS latest_first_seen
FROM public.job_posting;

-- 11. DAILY POSTING COUNTS
SELECT posted_at::DATE AS posting_date,COUNT(*) AS total_job_postings,
 COUNT(*) FILTER (WHERE is_data_science_related IS TRUE) AS data_science_postings,
 ROUND(100.0*COUNT(*) FILTER (WHERE is_data_science_related IS TRUE)/NULLIF(COUNT(*),0),2) AS data_science_percentage
FROM public.job_posting WHERE posted_at IS NOT NULL
GROUP BY posted_at::DATE ORDER BY posting_date;

-- 12. WEEKDAY POSTING COUNTS (Monday occurs twice in the 8-day window)
SELECT TO_CHAR(posted_at,'FMDay') AS day_of_week,EXTRACT(DOW FROM posted_at)::INT AS day_number,
 COUNT(*) AS total_job_postings,COUNT(*) FILTER (WHERE is_data_science_related IS TRUE) AS data_science_postings
FROM public.job_posting WHERE posted_at IS NOT NULL
GROUP BY EXTRACT(DOW FROM posted_at),TO_CHAR(posted_at,'FMDay') ORDER BY day_number;

-- 13. COUNTRY DISTRIBUTION; UNKNOWN INCLUDES MISSING CODES
SELECT COALESCE(NULLIF(TRIM(country_code),''),'Unknown') AS country,
 COUNT(*) AS total_job_postings,COUNT(*) FILTER (WHERE is_data_science_related IS TRUE) AS data_science_postings,
 ROUND(100.0*COUNT(*) FILTER (WHERE is_data_science_related IS TRUE)/NULLIF(COUNT(*),0),2) AS data_science_percentage
FROM public.job_posting GROUP BY COALESCE(NULLIF(TRIM(country_code),''),'Unknown')
ORDER BY total_job_postings DESC;

-- 14. WORKPLACE TYPE DISTRIBUTION; UNKNOWN MAY INCLUDE ANY WORK ARRANGEMENT
SELECT COALESCE(NULLIF(TRIM(workplace_type),''),'Unknown') AS workplace_type,
 COUNT(*) AS total_job_postings,COUNT(*) FILTER (WHERE is_data_science_related IS TRUE) AS data_science_postings,
 ROUND(100.0*COUNT(*) FILTER (WHERE is_data_science_related IS TRUE)/NULLIF(COUNT(*),0),2) AS data_science_percentage
FROM public.job_posting GROUP BY COALESCE(NULLIF(TRIM(workplace_type),''),'Unknown')
ORDER BY total_job_postings DESC;

-- 15. DATA SCIENCE SALARIES BY WORKPLACE TYPE
SELECT COALESCE(NULLIF(TRIM(jp.workplace_type),''),'Unknown') AS workplace_type,COUNT(*) AS total_jobs,
 COUNT(*) FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL) AS salary_eligible_jobs,
 ROUND(AVG(sa.salary_midpoint_annual) FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL),2) AS average_salary,
 ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sa.salary_midpoint_annual)
 FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL))::NUMERIC,2) AS median_salary
FROM public.job_posting jp LEFT JOIN public.salary sa ON jp.job_id=sa.job_id
WHERE jp.is_data_science_related IS TRUE
GROUP BY COALESCE(NULLIF(TRIM(jp.workplace_type),''),'Unknown') ORDER BY median_salary DESC NULLS LAST;

-- 16. EMPLOYMENT TYPE DISTRIBUTION
SELECT COALESCE(NULLIF(TRIM(employment_type),''),'Unknown') AS employment_type,
 COUNT(*) AS total_job_postings,COUNT(*) FILTER (WHERE is_data_science_related IS TRUE) AS data_science_postings,
 ROUND(100.0*COUNT(*) FILTER (WHERE is_data_science_related IS TRUE)/NULLIF(COUNT(*),0),2) AS data_science_percentage
FROM public.job_posting GROUP BY COALESCE(NULLIF(TRIM(employment_type),''),'Unknown')
ORDER BY total_job_postings DESC;

-- 17. DATA SCIENCE SALARIES BY EMPLOYMENT TYPE
SELECT COALESCE(NULLIF(TRIM(jp.employment_type),''),'Unknown') AS employment_type,COUNT(*) AS total_jobs,
 COUNT(*) FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL) AS salary_eligible_jobs,
 ROUND(AVG(sa.salary_midpoint_annual) FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL),2) AS average_salary,
 ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sa.salary_midpoint_annual)
 FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL))::NUMERIC,2) AS median_salary
FROM public.job_posting jp LEFT JOIN public.salary sa ON jp.job_id=sa.job_id
WHERE jp.is_data_science_related IS TRUE
GROUP BY COALESCE(NULLIF(TRIM(jp.employment_type),''),'Unknown') ORDER BY median_salary DESC NULLS LAST;

-- 18. ORIGINAL SENIORITY DISTRIBUTION
SELECT COALESCE(NULLIF(TRIM(seniority),''),'Unknown') AS seniority_level,
 COUNT(*) AS total_job_postings,COUNT(*) FILTER (WHERE is_data_science_related IS TRUE) AS data_science_postings,
 ROUND(100.0*COUNT(*) FILTER (WHERE is_data_science_related IS TRUE)/NULLIF(COUNT(*),0),2) AS data_science_percentage
FROM public.job_posting GROUP BY COALESCE(NULLIF(TRIM(seniority),''),'Unknown')
ORDER BY total_job_postings DESC;

-- 19. ORIGINAL-UNKNOWN SENIORITY: TITLE INDICATOR COUNTS
SELECT CASE
 WHEN title ~* '\m(senior|sr\.?|lead|principal|staff)\M' THEN 'Senior / Lead'
 WHEN title ~* '\m(junior|jr\.?|entry.level|graduate)\M' THEN 'Junior / Entry'
 WHEN title ~* '\m(intern|internship)\M' THEN 'Internship'
 WHEN title ~* '\m(mid.level|intermediate)\M' THEN 'Mid-Level'
 ELSE 'Not Identified' END AS title_seniority_indicator,COUNT(*) AS total_jobs
FROM public.job_posting
WHERE is_data_science_related IS TRUE AND LOWER(TRIM(COALESCE(seniority,''))) IN ('','unknown')
GROUP BY 1 ORDER BY total_jobs DESC;

-- 20. REVIEW FIRST 30 TITLES MATCHED AS SENIOR / LEAD
SELECT job_id,title,seniority,CASE
 WHEN title ~* '\m(senior|sr\.?|lead|principal|staff)\M' THEN 'Senior / Lead'
 WHEN title ~* '\m(junior|jr\.?|entry.level|graduate)\M' THEN 'Junior / Entry'
 WHEN title ~* '\m(intern|internship)\M' THEN 'Internship'
 WHEN title ~* '\m(mid.level|intermediate)\M' THEN 'Mid-Level'
 ELSE 'Not Identified' END AS inferred_seniority
FROM public.job_posting WHERE is_data_science_related IS TRUE
AND LOWER(TRIM(COALESCE(seniority,''))) IN ('','unknown')
AND title ~* '\m(senior|sr\.?|lead|principal|staff)\M'
ORDER BY title LIMIT 30;

-- 21. REVIEW ALL TITLES MATCHED AS SENIOR / LEAD WITH KEYWORD GROUP
SELECT title,CASE
 WHEN title ~* '\m(senior|sr\.?)\M' THEN 'Senior'
 WHEN title ~* '\mprincipal\M' THEN 'Principal'
 WHEN title ~* '\mlead\M' THEN 'Lead'
 WHEN title ~* '\mstaff\M' THEN 'Staff'
 ELSE 'Other' END AS matched_keyword
FROM public.job_posting WHERE is_data_science_related IS TRUE
AND LOWER(TRIM(COALESCE(seniority,''))) IN ('','unknown')
AND title ~* '\m(senior|sr\.?|lead|principal|staff)\M'
ORDER BY matched_keyword,title;

-- 22. REFINED SENIORITY DISTRIBUTION: PREVIEW ONLY, NO DATA MODIFICATION
WITH classified_jobs AS (
 SELECT job_id,title,seniority,CASE
 WHEN LOWER(TRIM(COALESCE(seniority,''))) NOT IN ('','unknown') THEN INITCAP(TRIM(seniority))
 WHEN title ~* '\m(mid/senior|senior/staff|staff or senior)\M' THEN 'Multiple Levels'
 WHEN title ~* '\m(senior|sr\.?|principal|lead)\M' THEN 'Senior / Lead'
 WHEN title ~* '\mstaff\M' AND title !~* '\mmember of .* staff\M' THEN 'Senior / Lead'
 WHEN title ~* '\m(intern|internship)\M' THEN 'Internship'
 WHEN title ~* '\m(junior|jr\.?|entry.level|graduate)\M' THEN 'Junior / Entry'
 WHEN title ~* '\m(mid.level|intermediate)\M' THEN 'Mid-Level'
 ELSE 'Unknown' END AS inferred_seniority
 FROM public.job_posting WHERE is_data_science_related IS TRUE
)
SELECT inferred_seniority,COUNT(*) AS total_jobs,
 ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM classified_jobs),2) AS percentage
FROM classified_jobs GROUP BY inferred_seniority ORDER BY total_jobs DESC;

-- 23. DATA SCIENCE SALARIES BY REFINED SENIORITY
WITH classified_jobs AS (
 SELECT job_id,CASE
 WHEN LOWER(TRIM(COALESCE(seniority,''))) NOT IN ('','unknown') THEN CASE
  WHEN LOWER(TRIM(seniority))='senior' THEN 'Senior / Lead'
  WHEN LOWER(TRIM(seniority))='mid' THEN 'Mid-Level'
  WHEN LOWER(TRIM(seniority))='internship' THEN 'Internship'
  ELSE INITCAP(TRIM(seniority)) END
 WHEN title ~* '\m(mid/senior|senior/staff|staff or senior)\M' THEN 'Multiple Levels'
 WHEN title ~* '\m(senior|sr\.?|principal|lead)\M' THEN 'Senior / Lead'
 WHEN title ~* '\mstaff\M' AND title !~* '\mmember of .* staff\M' THEN 'Senior / Lead'
 WHEN title ~* '\m(intern|internship)\M' THEN 'Internship'
 WHEN title ~* '\m(junior|jr\.?|entry.level|graduate)\M' THEN 'Junior / Entry'
 WHEN title ~* '\m(mid.level|intermediate)\M' THEN 'Mid-Level'
 ELSE 'Unknown' END AS refined_seniority
 FROM public.job_posting WHERE is_data_science_related IS TRUE
)
SELECT cj.refined_seniority,COUNT(*) AS total_jobs,
 COUNT(*) FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL) AS salary_eligible_jobs,
 ROUND(AVG(sa.salary_midpoint_annual) FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL),2) AS average_salary,
 ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sa.salary_midpoint_annual)
 FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL))::NUMERIC,2) AS median_salary
FROM classified_jobs cj LEFT JOIN public.salary sa ON cj.job_id=sa.job_id
GROUP BY cj.refined_seniority ORDER BY median_salary DESC NULLS LAST;

-- 24. FINAL SALARY ELIGIBILITY VALIDATION (expected: 229, 180, 49)
SELECT COUNT(*) AS total_data_science_jobs,
 COUNT(*) FILTER (WHERE sa.salary_usd_eligible IS TRUE AND sa.salary_midpoint_annual IS NOT NULL) AS salary_eligible_jobs,
 COUNT(*) FILTER (WHERE sa.salary_usd_eligible IS DISTINCT FROM TRUE OR sa.salary_midpoint_annual IS NULL) AS salary_not_eligible
FROM public.job_posting jp LEFT JOIN public.salary sa ON jp.job_id=sa.job_id
WHERE jp.is_data_science_related IS TRUE;


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
