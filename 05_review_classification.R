# =====================================================
# DATA 607 - PROJECT 3
# Dataset 1: Review Job Classification
# Script: 05_review_classification.R
# =====================================================

library(readr)
library(dplyr)

# STEP 1: Load the full cleaned dataset and refined candidates
jobs_all <- read_csv(
  "Data/job_postings_cleaned.csv",
  show_col_types = FALSE
)

jobs <- read_csv(
  "Data/job_postings_refined_all.csv",
  show_col_types = FALSE
)

# STEP 2: Compare full dataset and refined candidates
classification_summary <- tibble(
  dataset = c("Full cleaned dataset", "Refined Data Science candidates"),
  total_jobs = c(nrow(jobs_all), nrow(jobs)),
  unique_job_ids = c(n_distinct(jobs_all$job_id), n_distinct(jobs$job_id))
)

print(classification_summary)

# Check for candidate IDs missing from the full dataset
missing_candidates <- jobs %>%
  anti_join(jobs_all %>% select(job_id), by = "job_id")

print(nrow(missing_candidates))

# STEP 3: Review relevance classifications
jobs %>%
  count(relevance_status, sort = TRUE) %>%
  print()

# STEP 4: Validate posting dates
jobs %>%
  summarise(
    total_jobs = n(),
    valid_dates = sum(!is.na(posted_at)),
    missing_dates = sum(is.na(posted_at)),
    earliest_date = if (all(is.na(posted_at))) as.Date(NA) else as.Date(min(posted_at, na.rm = TRUE)),
    latest_date = if (all(is.na(posted_at))) as.Date(NA) else as.Date(max(posted_at, na.rm = TRUE))
  ) %>%
  print()

# STEP 5: Identify review groups
review_columns <- c(
  "job_id", "title", "company", "posted_at",
  "skill_count", "responsibility_count", "description"
)

# Potential false positives: relevant without a core job title
possible_false_positives <- jobs %>%
  filter(relevance_status == "Likely Relevant", !coalesce(core_title_match, FALSE)) %>%
  select(all_of(review_columns)) %>%
  arrange(desc(responsibility_count))

# Uncertain candidates, not a complete search for false negatives
possible_false_negatives <- jobs %>%
  filter(relevance_status == "Needs Review") %>%
  select(all_of(review_columns)) %>%
  arrange(desc(responsibility_count))

review_summary <- tibble(
  review_group = c("Possible false positives", "Needs review"),
  total_jobs = c(nrow(possible_false_positives), nrow(possible_false_negatives))
)

print(review_summary)

# STEP 6: Save review groups without overwriting existing reviews
false_positives_path <- "Data/possible_false_positives.csv"
false_negatives_path <- "Data/possible_false_negatives.csv"

if (!file.exists(false_positives_path)) {
  write_csv(possible_false_positives, false_positives_path)
}

if (!file.exists(false_negatives_path)) {
  write_csv(possible_false_negatives, false_negatives_path)
}

# STEP 7: Inspect review groups
possible_false_positives %>%
  select(title, company, skill_count, responsibility_count) %>%
  print(n = 50)

View(possible_false_positives)
View(possible_false_negatives)
