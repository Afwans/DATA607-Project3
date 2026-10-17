-- DATA 607 PROJECT 3 — DATASET 1
-- PostgreSQL 18; connect to database data607_project3 before running.
-- Safe for existing tables: CREATE TABLE IF NOT EXISTS does not delete data.
-- Run statements in the order shown because of foreign keys.

CREATE TABLE IF NOT EXISTS public.company (
    company_id VARCHAR(255) PRIMARY KEY,
    company_name TEXT
);

CREATE TABLE IF NOT EXISTS public.job_posting (
    job_id VARCHAR(50) PRIMARY KEY,
    company_id VARCHAR(255),
    title TEXT,
    department TEXT,
    location TEXT,
    city TEXT,
    region TEXT,
    country_code VARCHAR(10),
    workplace_type VARCHAR(100),
    employment_type VARCHAR(100),
    seniority VARCHAR(100),
    posted_at TIMESTAMP,
    first_seen_at TIMESTAMP,
    language VARCHAR(50),
    url TEXT,
    apply_url TEXT,
    description TEXT,
    job_category_updated VARCHAR(100),
    classification_updated VARCHAR(100),
    CONSTRAINT fk_job_company FOREIGN KEY (company_id)
        REFERENCES public.company(company_id)
);

CREATE TABLE IF NOT EXISTS public.salary (
    job_id VARCHAR(50) PRIMARY KEY,
    salary_min NUMERIC(15,2),
    salary_max NUMERIC(15,2),
    salary_currency VARCHAR(10),
    salary_period VARCHAR(50),
    salary_text TEXT,
    salary_source VARCHAR(100),
    salary_min_annual NUMERIC(15,2),
    salary_max_annual NUMERIC(15,2),
    salary_midpoint_annual NUMERIC(15,2),
    salary_complete BOOLEAN,
    salary_valid BOOLEAN,
    salary_outlier_flag BOOLEAN,
    salary_usd_eligible BOOLEAN,
    CONSTRAINT fk_salary_job FOREIGN KEY (job_id)
        REFERENCES public.job_posting(job_id)
);

CREATE TABLE IF NOT EXISTS public.skill (
    skill_id INTEGER PRIMARY KEY,
    skill_name VARCHAR(100) NOT NULL,
    source_column VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS public.job_skill (
    job_id VARCHAR(50) NOT NULL,
    skill_id INTEGER NOT NULL,
    CONSTRAINT pk_job_skill PRIMARY KEY (job_id, skill_id),
    CONSTRAINT fk_job_skill_job FOREIGN KEY (job_id)
        REFERENCES public.job_posting(job_id),
    CONSTRAINT fk_job_skill_skill FOREIGN KEY (skill_id)
        REFERENCES public.skill(skill_id)
);

-- CSV import order in pgAdmin (Import/Export Data):
-- 1. COMPANY.csv      -> public.company
-- 2. JOB_POSTING.csv  -> public.job_posting
-- 3. SALARY.csv       -> public.salary (set NULL String = NA)
-- 4. SKILL.csv        -> public.skill
-- 5. JOB_SKILL.csv    -> public.job_skill
-- Format CSV, Header Yes, delimiter comma, encoding UTF8.
-- Do NOT re-import into already populated tables: primary key conflicts may occur.
