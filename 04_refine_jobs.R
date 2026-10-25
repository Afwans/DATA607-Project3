# =====================================================
# DATA 607 - PROJECT 3
# Dataset 1: Refine Data Science Job Filtering
# Script: 04_refine_jobs.R
# =====================================================

library(readr)
library(dplyr)
library(stringr)

# STEP 1: Load full dataset and data-related candidates
jobs_full <- read_csv(
  "Data/job_postings_cleaned.csv",
  show_col_types = FALSE
)

jobs <- read_csv(
  "Data/job_postings_data_science.csv",
  show_col_types = FALSE
)

cat("Full cleaned dataset:", nrow(jobs_full), "\n")
cat("Data-related candidates:", nrow(jobs), "\n")

# STEP 2: Define core data-related job titles
core_titles <- c(
  "data scien", "data analy", "data engineer", "analytics engineer",
  "analytics lead", "business intelligence", "bi analyst", "bi developer",
  "machine learning", "ml engineer", "ai engineer", "ai/ml",
  "ai platform engineer", "applied scientist", "decision scientist",
  "statistician", "biostatistician", "actuarial analyst",
  "quantitative analyst", "quantitative researcher", "data architect",
  "database architect", "database administrator", "database developer",
  "database engineer", "sql developer", "data governance", "data quality",
  "data visualization", "data insights", "reporting analyst",
  "predictive analytics", "research scientist", "nlp engineer",
  "computer vision"
)

# STEP 3: Define data-related responsibilities
responsibility_patterns <- c(
  "analyze data", "analyzing data", "data analysis", "statistical modeling",
  "statistical analysis", "predictive modeling", "build dashboards",
  "develop dashboards", "create dashboards", "build data pipelines",
  "develop data pipelines", "design data pipelines", "etl pipelines",
  "build machine learning models", "develop machine learning models",
  "train machine learning models", "data warehousing", "data visualization",
  "develop predictive models", "forecasting models", "build reports",
  "develop reports", "business intelligence"
)

# STEP 4: Define unrelated job-title patterns
unrelated_titles <- c(
  "account executive", "sales specialist", "sales representative",
  "financial service representative", "technical program manager",
  "project controller", "customer support", "devops engineer",
  "cloud operations", "applications administrator", "proposal manager",
  "vp of product", "marketing operations manager"
)

# STEP 5: Match phrases and count responsibilities
has_phrase <- function(text, phrases) {
  if (is.na(text) || !nzchar(text)) return(FALSE)

  any(vapply(
    phrases,
    function(phrase) str_detect(text, fixed(phrase, ignore_case = TRUE)),
    logical(1)
  ))
}

count_responsibilities <- function(text) {
  if (is.na(text) || !nzchar(text)) return(0L)

  sum(vapply(
    responsibility_patterns,
    function(phrase) str_detect(text, fixed(phrase, ignore_case = TRUE)),
    logical(1)
  ))
}

# STEP 6: Score data-related job relevance
jobs_refined <- jobs %>%
  mutate(
    core_title_match = vapply(
      title, has_phrase, logical(1), phrases = core_titles
    ),
    responsibility_count = vapply(
      description, count_responsibilities, integer(1)
    ),
    unrelated_title_match = vapply(
      title, has_phrase, logical(1), phrases = unrelated_titles
    ),
    relevance_status = case_when(
      core_title_match ~ "Likely Relevant",
      unrelated_title_match ~ "Likely Unrelated",
      responsibility_count >= 2 & coalesce(skill_count, 0L) >= 3 ~
        "Likely Relevant",
      TRUE ~ "Needs Review"
    )
  )

# STEP 7: Review relevance classifications
jobs_refined %>%
  count(relevance_status, sort = TRUE) %>%
  print()

# STEP 8: Review classification examples
jobs_refined %>%
  select(title, company, skill_count, responsibility_count, relevance_status) %>%
  arrange(relevance_status, desc(responsibility_count)) %>%
  print(n = 50)

# STEP 9: Validate job IDs against the full dataset
jobs_refined %>%
  summarise(
    total_candidates = n(),
    unique_job_ids = n_distinct(job_id),
    duplicate_job_ids = n() - n_distinct(job_id),
    missing_from_full_dataset = sum(!job_id %in% jobs_full$job_id)
  ) %>%
  print()

# STEP 10: Validate posting dates
jobs_refined %>%
  summarise(
    total_jobs = n(),
    valid_posting_dates = sum(!is.na(posted_at)),
    missing_posting_dates = sum(is.na(posted_at)),
    earliest_date = if (all(is.na(posted_at))) as.Date(NA) else
      as.Date(min(posted_at, na.rm = TRUE)),
    latest_date = if (all(is.na(posted_at))) as.Date(NA) else
      as.Date(max(posted_at, na.rm = TRUE))
  ) %>%
  print()

# STEP 11: Create relevant and uncertain subsets
jobs_relevant <- jobs_refined %>%
  filter(relevance_status == "Likely Relevant")

jobs_uncertain <- jobs_refined %>%
  filter(relevance_status == "Needs Review")

# STEP 12: Export updated derived datasets
write_csv(jobs_refined, "Data/job_postings_refined_all.csv")
write_csv(jobs_relevant, "Data/job_postings_relevant.csv")
write_csv(jobs_uncertain, "Data/job_postings_uncertain.csv")

# STEP 13: Review uncertain jobs
View(jobs_uncertain)
