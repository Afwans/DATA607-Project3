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


CREATE TABLE IF NOT EXISTS public.job_sector_classification (
    job_id TEXT PRIMARY KEY REFERENCES public.job_posting(job_id),
    job_function_updated TEXT
);
