# DATA 607 - Project 3
# 02: Clean the full job-postings dataset

library(readr)
library(dplyr)
library(stringr)

# -----------------------------------------
# Step 1: Load original data
# -----------------------------------------

jobs_raw <- read_csv(
  file.path("Data", "job_postings_with_salaries.csv"),
  show_col_types = FALSE
)

dim(jobs_raw)
names(jobs_raw)

# -----------------------------------------
# Step 2: Clean all job postings
# -----------------------------------------

jobs_clean <- jobs_raw %>%
  mutate(across(where(is.character), ~ na_if(str_trim(.x), ""))) %>%
  distinct() %>%
  mutate(
    across(any_of(c("seniority", "workplace_type", "employment_type")),
           ~ coalesce(.x, "Unknown"))
  )

# Review duplicate job IDs separately; do not silently remove distinct postings.
duplicate_job_ids <- jobs_clean %>%
  filter(!is.na(job_id)) %>%
  add_count(job_id, name = "id_count") %>%
  filter(id_count > 1) %>%
  arrange(job_id)

nrow(jobs_raw)
nrow(jobs_clean)
n_distinct(jobs_clean$job_id, na.rm = TRUE)
nrow(duplicate_job_ids)

# -----------------------------------------
# Step 3: Validate posting dates
# -----------------------------------------

class(jobs_clean$posted_at)

jobs_clean %>%
  summarise(
    total_jobs = n(),
    jobs_with_dates = sum(!is.na(posted_at)),
    missing_dates = sum(is.na(posted_at)),
    earliest_date = if (all(is.na(posted_at))) as.Date(NA) else as.Date(min(posted_at, na.rm = TRUE)),
    latest_date = if (all(is.na(posted_at))) as.Date(NA) else as.Date(max(posted_at, na.rm = TRUE))
  )

# -----------------------------------------
# Step 4: Validate salary information
# -----------------------------------------

jobs_clean <- jobs_clean %>%
  mutate(
    salary_complete = !is.na(salary_min_annual) & !is.na(salary_max_annual),
    salary_valid = coalesce(
      salary_complete &
        is.finite(salary_min_annual) &
        is.finite(salary_max_annual) &
        salary_min_annual >= 0 &
        salary_max_annual >= salary_min_annual,
      FALSE
    ),
    salary_outlier_flag = coalesce(
      salary_currency == "USD" &
        ((!is.na(salary_min_annual) & salary_min_annual < 30000) |
           (!is.na(salary_max_annual) & salary_max_annual > 400000)),
      FALSE
    ),
    salary_usd_eligible = coalesce(
      salary_currency == "USD" & salary_valid & !salary_outlier_flag,
      FALSE
    )
  )

jobs_clean %>%
  summarise(
    total_jobs = n(),
    complete_salaries = sum(salary_complete),
    valid_salaries = sum(salary_valid),
    flagged_salaries = sum(salary_outlier_flag),
    usd_eligible = sum(salary_usd_eligible)
  )

jobs_clean %>% count(salary_currency, sort = TRUE)

# -----------------------------------------
# Step 5: Define data-related titles and skills
# -----------------------------------------

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


# -----------------------------------------
# Step 6: Match job titles, departments, and descriptions
# -----------------------------------------

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


jobs_scored <- jobs_clean %>%
  mutate(
    title_match = vapply(title, match_keywords, logical(1), keywords = title_keywords),
    department_match = vapply(department, match_keywords, logical(1), keywords = title_keywords),
    skill_count = vapply(description, count_skills, integer(1)),
    description_match = skill_count >= 3,
    match_reason = case_when(
      title_match ~ "Relevant Job Title",
      department_match & skill_count >= 2 ~ "Relevant Department and Skills",
      description_match ~ "Multiple Technical Skills",
      TRUE ~ "Not Selected"
    ),
    data_related_candidate = title_match |
      (department_match & skill_count >= 2) |
      description_match
  )

# -----------------------------------------
# Step 7: Review data-related candidates
# -----------------------------------------

jobs_data_science <- jobs_scored %>%
  filter(data_related_candidate)

jobs_review <- jobs_data_science %>%
  filter(!title_match, !department_match) %>%
  arrange(desc(skill_count))

title_summary <- jobs_data_science %>%
  count(title, sort = TRUE)

jobs_scored %>% count(data_related_candidate)
jobs_data_science %>% count(match_reason, sort = TRUE)
print(title_summary, n = 50)

jobs_review %>%
  select(title, company, skill_count, match_reason) %>%
  print(n = 50)

jobs_data_science %>% count(salary_currency, sort = TRUE)

# -----------------------------------------
# Step 8: Export full and focused datasets
# -----------------------------------------

write_csv(jobs_clean, file.path("Data", "job_postings_cleaned.csv"))
write_csv(jobs_data_science, file.path("Data", "job_postings_data_science.csv"))
write_csv(jobs_review, file.path("Data", "job_postings_review.csv"))
write_csv(title_summary, file.path("Data", "job_titles_summary.csv"))
