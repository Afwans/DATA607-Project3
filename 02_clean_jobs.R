
# ============================================================
# DATA 607 - PROJECT 3
# Dataset 1: Job Postings with Salaries
# Script: 02_clean_jobs.R
#
# Purpose:
# 1. Load and clean the original dataset
# 2. Check salary information
# 3. Identify Data Science-related jobs
# 4. Search job titles, departments, and descriptions
# 5. Export cleaned and filtered datasets
#
# The original CSV is never modified.
# ============================================================


# ------------------------------------------------------------
# STEP 1: LOAD REQUIRED PACKAGES
# ------------------------------------------------------------

library(readr)
library(dplyr)
library(stringr)


# ------------------------------------------------------------
# STEP 2: LOAD ORIGINAL DATASET
# ------------------------------------------------------------

jobs_raw <- read_csv(
  "data/job_postings_with_salaries.csv",
  show_col_types = FALSE
)

cat("Original dataset:", nrow(jobs_raw), "rows\n")
cat("Original columns:", ncol(jobs_raw), "\n")


# ------------------------------------------------------------
# STEP 3: CREATE CLEANED DATASET
# ------------------------------------------------------------

jobs_clean <- jobs_raw %>%
  distinct() %>%
  mutate(
    across(
      where(is.character),
      ~ str_trim(.x)
    )
  )

# Convert blank text values to NA
jobs_clean <- jobs_clean %>%
  mutate(
    across(
      where(is.character),
      ~ na_if(.x, "")
    )
  )

# Standardize selected missing categorical values
jobs_clean <- jobs_clean %>%
  mutate(
    seniority = coalesce(seniority, "Unknown"),
    workplace_type = coalesce(
      workplace_type, "Unknown"
    ),
    employment_type = coalesce(
      employment_type, "Unknown"
    )
  )

# ------------------------------------------------------------
# STEP 3A: VALIDATE JOB POSTING DATES
# ------------------------------------------------------------

# Confirm the posting date column is a date-time
cat("\n--- POSTING DATE VALIDATION ---\n")
print(class(jobs_clean$posted_at))

# Check posting date completeness and range
date_validation <- jobs_clean %>%
  summarise(
    total_jobs = n(),
    valid_posting_dates = sum(!is.na(posted_at)),
    missing_posting_dates = sum(is.na(posted_at)),
    earliest_posted_date = as.Date(min(posted_at, na.rm = TRUE)),
    latest_posted_date = as.Date(max(posted_at, na.rm = TRUE))
  )

print(date_validation)

# Check that cleaning did not change posting timestamps
date_changes <- jobs_clean %>%
  select(job_id, posted_at) %>%
  inner_join(
    jobs_raw %>% select(job_id, posted_at),
    by = "job_id",
    suffix = c("_clean", "_raw")
  ) %>%
  filter(
    posted_at_clean != posted_at_raw
  )

cat(
  "Posting timestamps changed during cleaning:",
  nrow(date_changes), "\n"
)

# ------------------------------------------------------------
# STEP 4: VALIDATE SALARY INFORMATION
# ------------------------------------------------------------

jobs_clean <- jobs_clean %>%
  mutate(
    salary_complete =
      !is.na(salary_min_annual) &
      !is.na(salary_max_annual),
    
    salary_valid =
      salary_complete &
      salary_min_annual >= 0 &
      salary_max_annual >= salary_min_annual,
    
    # Exploratory thresholds, not automatic exclusions
    salary_outlier_flag =
      salary_currency == "USD" &
      (
        (!is.na(salary_min_annual) &
           salary_min_annual < 30000) |
          (!is.na(salary_max_annual) &
             salary_max_annual > 400000)
      ),
    
    # USD records suitable for initial salary analysis
    salary_usd_eligible =
      salary_currency == "USD" &
      salary_valid &
      !salary_outlier_flag
  )

cat("\n--- SALARY VALIDATION ---\n")

jobs_clean %>%
  summarise(
    total_jobs = n(),
    complete_salaries = sum(salary_complete),
    valid_salaries = sum(salary_valid),
    flagged_salaries = sum(
      salary_outlier_flag, na.rm = TRUE
    ),
    usd_eligible = sum(
      salary_usd_eligible, na.rm = TRUE
    )
  ) %>%
  print()


# ------------------------------------------------------------
# STEP 5: DEFINE DATA-RELATED JOB TITLES
# ------------------------------------------------------------

title_keywords <- c(
  
  # Data Science
  "data scientist",
  "data science",
  "applied scientist",
  "research scientist",
  "decision scientist",
  
  # Data Analytics
  "data analyst",
  "data analytics",
  "data analysis",
  "analytics specialist",
  "analytics consultant",
  "analytics manager",
  "analytics engineer",
  "analytics engineering",
  "advanced analytics",
  "business analytics",
  "marketing analytics",
  "product analytics",
  "customer analytics",
  "performance analytics",
  "data insights",
  "insights analyst",
  "data visualization",
  
  # Data Engineering
  "data engineer",
  "data engineering",
  "data pipeline",
  "data operations",
  "etl developer",
  "etl engineer",
  "big data",
  "hadoop developer",
  "spark developer",
  "cloud data engineer",
  
  # AI and Machine Learning
  "machine learning",
  "ml engineer",
  "ml platform",
  "mlops",
  "ai engineer",
  "ai/ml",
  "ai architect",
  "ai specialist",
  "ai research",
  "ai developer",
  "ai scientist",
  "artificial intelligence",
  "generative ai",
  "llm engineer",
  "deep learning",
  "nlp engineer",
  "nlp scientist",
  "computer vision",
  "recommendation systems",
  
  # Business Intelligence
  "business intelligence",
  "bi analyst",
  "bi developer",
  "bi engineer",
  "bi architect",
  "reporting analyst",
  "reporting engineer",
  "cloud analytics",
  
  # Statistics and Research
  "statistician",
  "statistical analyst",
  "statistical programmer",
  "biostatistician",
  "quantitative analyst",
  "quantitative researcher",
  "research analyst",
  
  # Database and Architecture
  "data architect",
  "database architect",
  "data warehouse",
  "database administrator",
  "database developer",
  "database engineer",
  "sql developer",
  "sql analyst",
  "data solutions",
  
  # Business and Specialized Analytics
  "business analyst",
  "operations analyst",
  "product analyst",
  "marketing analyst",
  "financial data analyst",
  "finance data analyst",
  "risk analyst",
  "fraud analyst",
  "credit risk",
  "healthcare data analyst",
  "clinical data analyst",
  "bioinformatics",
  "people analytics",
  
  # Data Management and Governance
  "data quality",
  "data governance",
  "data steward",
  "data management",
  "data integrity"
)


# ------------------------------------------------------------
# STEP 6: DEFINE TECHNICAL SKILLS
# ------------------------------------------------------------

skill_keywords <- c(
  
  # Programming
  "python",
  "sql",
  "r programming",
  "r language",
  "pandas",
  "numpy",
  
  # Data Science
  "data science",
  "data analytics",
  "data analysis",
  "statistical analysis",
  "statistics",
  "predictive modeling",
  "predictive analytics",
  "regression analysis",
  "hypothesis testing",
  "a/b testing",
  "time series",
  "forecasting",
  
  # Artificial Intelligence
  "machine learning",
  "deep learning",
  "artificial intelligence",
  "generative ai",
  "large language model",
  "llm",
  "natural language processing",
  "nlp",
  "computer vision",
  "neural network",
  "tensorflow",
  "pytorch",
  "scikit-learn",
  "feature engineering",
  "mlops",
  
  # Big Data and Cloud
  "spark",
  "pyspark",
  "hadoop",
  "databricks",
  "snowflake",
  "bigquery",
  "redshift",
  
  # Business Intelligence
  "tableau",
  "power bi",
  "data visualization",
  "business intelligence",
  
  # Data Engineering
  "data engineering",
  "data pipeline",
  "etl",
  "elt",
  "data warehouse",
  "data modeling",
  "data mining",
  "data governance"
)


# ------------------------------------------------------------
# STEP 7: CREATE MATCHING FUNCTIONS
# ------------------------------------------------------------

# Match phrases regardless of capitalization
match_keywords <- function(text, keywords) {
  
  if (is.na(text)) {
    return(FALSE)
  }
  
  any(vapply(
    keywords,
    function(keyword) {
      str_detect(
        text,
        fixed(keyword, ignore_case = TRUE)
      )
    },
    logical(1)
  ))
}

# Count distinct skill keywords in each description
count_skills <- function(text) {
  
  if (is.na(text)) {
    return(0L)
  }
  
  sum(vapply(
    skill_keywords,
    function(skill) {
      str_detect(
        text,
        fixed(skill, ignore_case = TRUE)
      )
    },
    logical(1)
  ))
}


# ------------------------------------------------------------
# STEP 8: MATCH JOB TITLES, DEPARTMENTS, DESCRIPTIONS
# ------------------------------------------------------------

jobs_scored <- jobs_clean %>%
  mutate(
    
    # Relevant job title
    title_match = vapply(
      title,
      match_keywords,
      logical(1),
      keywords = title_keywords
    ),
    
    # Relevant department
    department_match = vapply(
      department,
      match_keywords,
      logical(1),
      keywords = title_keywords
    ),
    
    # Number of different technical skills
    skill_count = vapply(
      description,
      count_skills,
      integer(1)
    ),
    
    # Description contains at least 3 skills
    description_match = skill_count >= 3,
    
    # Main selection reason
    match_reason = case_when(
      
      title_match ~
        "Relevant Job Title",
      
      department_match & skill_count >= 2 ~
        "Relevant Department and Skills",
      
      description_match ~
        "Multiple Technical Skills",
      
      TRUE ~
        "Not Selected"
    )
  )


# ------------------------------------------------------------
# STEP 9: FILTER DATA SCIENCE-RELATED JOBS
# ------------------------------------------------------------

jobs_data_science <- jobs_scored %>%
  filter(
    title_match |
      (department_match & skill_count >= 2) |
      description_match
  )

cat("\n--- JOB FILTERING RESULTS ---\n")

cat(
  "Original cleaned jobs:",
  nrow(jobs_clean), "\n"
)

cat(
  "Selected data-related jobs:",
  nrow(jobs_data_science), "\n"
)

cat(
  "Percentage selected:",
  round(
    100 * nrow(jobs_data_science) /
      nrow(jobs_clean),
    2
  ),
  "%\n"
)

jobs_data_science %>%
  count(match_reason, sort = TRUE) %>%
  print()


# ------------------------------------------------------------
# STEP 10: REVIEW FILTERED JOB TITLES
# ------------------------------------------------------------

title_summary <- jobs_data_science %>%
  count(title, sort = TRUE)

print(title_summary, n = 50)


# ------------------------------------------------------------
# STEP 11: REVIEW DESCRIPTION-ONLY MATCHES
# ------------------------------------------------------------

# These jobs need additional review because
# their titles and departments did not match.

jobs_review <- jobs_data_science %>%
  filter(
    !title_match,
    !department_match
  ) %>%
  arrange(desc(skill_count))

cat(
  "\nJobs requiring description review:",
  nrow(jobs_review), "\n"
)

jobs_review %>%
  select(
    title,
    company,
    skill_count,
    match_reason
  ) %>%
  print(n = 50)


# ------------------------------------------------------------
# STEP 12: SUMMARIZE SALARY CURRENCIES
# ------------------------------------------------------------

cat("\n--- CURRENCIES IN FILTERED DATA ---\n")

jobs_data_science %>%
  count(salary_currency, sort = TRUE) %>%
  print()


# ------------------------------------------------------------
# STEP 13: EXPORT DATASETS
# ------------------------------------------------------------

# All cleaned jobs
write_csv(
  jobs_clean,
  "data/job_postings_cleaned.csv"
)

# All candidate data-related jobs
write_csv(
  jobs_data_science,
  "data/job_postings_data_science.csv"
)

# Jobs requiring further relevance review
write_csv(
  jobs_review,
  "data/job_postings_review.csv"
)

# Summary of selected job titles
write_csv(
  title_summary,
  "data/job_titles_summary.csv"
)


# ------------------------------------------------------------
# STEP 14: FINAL VALIDATION
# ------------------------------------------------------------

cat("\n=================================\n")
cat("DATA CLEANING COMPLETED\n")
cat("=================================\n")

cat("Original jobs:", nrow(jobs_raw), "\n")
cat("Cleaned jobs:", nrow(jobs_clean), "\n")
cat("Data-related candidates:",
    nrow(jobs_data_science), "\n")
cat("Description-only review jobs:",
    nrow(jobs_review), "\n")

cat("\nFiles exported successfully.\n")
