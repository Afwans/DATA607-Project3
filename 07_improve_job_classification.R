# =====================================================
# DATA 607 - PROJECT 3
# Dataset 1: Improve Job Classification
# Script: 07_improve_job_classification.R
# =====================================================

library(readr)
library(dplyr)
library(stringr)

# STEP 1: Load classified Data Science candidates and full cleaned data
jobs <- read_csv("Data/jobs_classified_all.csv", show_col_types = FALSE)
jobs_full <- read_csv("Data/job_postings_cleaned.csv", show_col_types = FALSE)

jobs %>% count(classification, sort = TRUE) %>% print()

# STEP 2: Validate job IDs and posting dates
stopifnot(n_distinct(jobs$job_id) == nrow(jobs))
stopifnot(all(jobs$job_id %in% jobs_full$job_id))
stopifnot("posted_at" %in% names(jobs))

jobs %>%
  summarise(
    total_jobs = n(),
    valid_dates = sum(!is.na(posted_at)),
    missing_dates = sum(is.na(posted_at)),
    earliest_date = if (all(is.na(posted_at))) as.Date(NA) else as.Date(min(posted_at, na.rm = TRUE)),
    latest_date = if (all(is.na(posted_at))) as.Date(NA) else as.Date(max(posted_at, na.rm = TRUE))
  ) %>%
  print()

# STEP 3: Define additional data-related job title patterns
extra_patterns <- list(
  "AI/ML" = c(
    "mlops", "ai software engineer", "ai research", "llm engineer",
    "generative ai", "genai", "ai scientist", "machine learning operations",
    "model evaluation", "benchmarks & evals"
  ),
  "Data Engineering" = c(
    "data operations engineer", "data platform engineer", "data infrastructure engineer",
    "data reliability engineer", "data systems engineer"
  ),
  "Data Analytics" = c(
    "head of data", "director of analytics", "director, analytics",
    "manager, data & analytics", "analytics director", "advanced analytics",
    "analytics consultant", "insights & analytics", "analytics and insights"
  ),
  "Statistics" = c(
    "biostatistics", "statistical scientist", "statistical analyst",
    "quantitative expert", "forecasting modeler"
  )
)

# STEP 4: Match additional job titles
find_extra_category <- function(title) {
  if (is.na(title)) return(NA_character_)

  for (category in names(extra_patterns)) {
    matched <- any(vapply(
      extra_patterns[[category]],
      function(phrase) str_detect(title, fixed(phrase, ignore_case = TRUE)),
      logical(1)
    ))
    if (matched) return(category)
  }

  NA_character_
}

# STEP 5: Improve classifications without changing prior exclusions
jobs_updated <- jobs %>%
  mutate(
    extra_category = vapply(title, find_extra_category, character(1)),
    job_category_updated = coalesce(job_category, extra_category),
    classification_updated = case_when(
      classification == "Include" ~ "Include",
      classification == "Exclude" ~ "Exclude",
      classification == "Review" &
        !is.na(extra_category) &
        !coalesce(non_data_title, FALSE) ~ "Include",
      TRUE ~ "Review"
    )
  )

# STEP 6: Validate updated results
stopifnot(nrow(jobs_updated) == nrow(jobs))
stopifnot(n_distinct(jobs_updated$job_id) == nrow(jobs_updated))
stopifnot(identical(jobs_updated$posted_at, jobs$posted_at))

jobs_updated %>% count(classification_updated, sort = TRUE) %>% print()

jobs_updated %>%
  filter(classification_updated == "Include") %>%
  count(job_category_updated, sort = TRUE) %>%
  print()

# STEP 7: Export generated classifications
write_csv(jobs_updated, "Data/jobs_classified_updated.csv")

jobs_included <- jobs_updated %>%
  filter(classification_updated == "Include")
write_csv(jobs_included, "Data/jobs_include_updated.csv")

jobs_review_remaining <- jobs_updated %>%
  filter(classification_updated == "Review")
write_csv(jobs_review_remaining, "Data/jobs_review_remaining.csv")

View(jobs_review_remaining)
