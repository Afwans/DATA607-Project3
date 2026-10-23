# ===================================================
# DATA 607 - PROJECT 3
# 03: Validate Data Science Job Filtering
# ===================================================

library(readr)
library(dplyr)
library(stringr)

# Load full cleaned dataset and Data Science candidates
jobs_clean <- read_csv(
  "Data/job_postings_cleaned.csv",
  show_col_types = FALSE
)

jobs_ds <- read_csv(
  "Data/job_postings_data_science.csv",
  show_col_types = FALSE
)

jobs_review <- read_csv(
  "Data/job_postings_review.csv",
  show_col_types = FALSE
)

# -----------------------------------------
# Step 1: Validate dataset sizes
# -----------------------------------------

validation_summary <- tibble(
  dataset = c("Full cleaned jobs", "Data-related candidates", "Description-only review"),
  total_jobs = c(nrow(jobs_clean), nrow(jobs_ds), nrow(jobs_review)),
  unique_job_ids = c(
    n_distinct(jobs_clean$job_id),
    n_distinct(jobs_ds$job_id),
    n_distinct(jobs_review$job_id)
  )
)

print(validation_summary)

# Check that candidate and review job IDs exist in the full dataset
candidate_ids_missing <- jobs_ds %>%
  anti_join(jobs_clean %>% distinct(job_id), by = "job_id")

review_ids_missing <- jobs_review %>%
  anti_join(jobs_ds %>% distinct(job_id), by = "job_id")

nrow(candidate_ids_missing)
nrow(review_ids_missing)

# Check duplicate job IDs
jobs_ds %>%
  count(job_id, name = "records") %>%
  filter(records > 1) %>%
  arrange(desc(records)) %>%
  print(n = 30)

# -----------------------------------------
# Step 2: Check how candidates were selected
# -----------------------------------------

jobs_ds %>%
  count(match_reason, sort = TRUE) %>%
  print()

# -----------------------------------------
# Step 3: Review common job titles
# -----------------------------------------

jobs_ds %>%
  count(title, sort = TRUE) %>%
  print(n = 30)

# -----------------------------------------
# Step 4: Review description-only candidates
# -----------------------------------------

review_sample <- jobs_review %>%
  select(job_id, title, company, skill_count, description) %>%
  arrange(desc(skill_count))

View(review_sample)

# -----------------------------------------
# Step 5: Create reproducible review sample
# -----------------------------------------

set.seed(607)

sample_size <- min(30, nrow(jobs_review))

sample_review <- jobs_review %>%
  slice_sample(n = sample_size) %>%
  select(job_id, title, company, skill_count, description)

sample_path <- "Data/job_review_sample.csv"

if (!file.exists(sample_path)) {
  write_csv(sample_review, sample_path)
}

# -----------------------------------------
# Step 6: Prepare manual relevance review
# -----------------------------------------

manual_review <- sample_review %>%
  mutate(
    relevant = NA_character_,
    job_category = NA_character_,
    review_notes = NA_character_
  ) %>%
  select(
    job_id, title, company, skill_count,
    relevant, job_category, review_notes, description
  )

manual_review_path <- "Data/job_manual_review.csv"

if (!file.exists(manual_review_path)) {
  write_csv(manual_review, manual_review_path, na = "")
}

# View the saved manual review sheet
manual_review_saved <- read_csv(
  manual_review_path,
  show_col_types = FALSE
)

View(manual_review_saved)
