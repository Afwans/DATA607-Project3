# =====================================================
# DATA 607 - PROJECT 3
# Dataset 1: Validate Job Classification
# Script: 08_validate_classification.R
# =====================================================

library(readr)
library(dplyr)

# STEP 1: Load full dataset and updated classifications
jobs_full <- read_csv(
  "Data/job_postings_cleaned.csv",
  show_col_types = FALSE
)

jobs <- read_csv(
  "Data/jobs_classified_updated.csv",
  show_col_types = FALSE
)

# STEP 2: Validate dataset coverage and job IDs
stopifnot(
  !anyNA(jobs_full$job_id),
  n_distinct(jobs_full$job_id) == nrow(jobs_full),
  !anyNA(jobs$job_id),
  n_distinct(jobs$job_id) == nrow(jobs),
  all(jobs$job_id %in% jobs_full$job_id)
)

coverage_summary <- tibble(
  dataset = c("Full cleaned dataset", "Data-related candidates"),
  total_jobs = c(nrow(jobs_full), nrow(jobs))
)

print(coverage_summary)

# STEP 3: Validate posting dates
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

# STEP 4: Review classification counts
jobs %>%
  count(classification_updated, sort = TRUE) %>%
  print()

jobs %>%
  filter(classification_updated == "Include") %>%
  count(job_category_updated, sort = TRUE) %>%
  print()

# STEP 5: Identify newly included jobs
new_jobs <- jobs %>%
  filter(
    classification_updated == "Include",
    classification != "Include"
  )

# STEP 6: Sample previously included jobs
set.seed(607)

previously_included <- jobs %>%
  filter(
    classification_updated == "Include",
    classification == "Include"
  )

existing_sample <- previously_included %>%
  slice_sample(n = min(30L, nrow(previously_included)))

# STEP 7: Prepare manual validation sheet
validation <- bind_rows(
  new_jobs %>% mutate(review_group = "New Inclusion"),
  existing_sample %>% mutate(review_group = "Existing Inclusion")
) %>%
  transmute(
    job_id,
    title,
    company,
    posted_at,
    review_group,
    suggested_category = job_category_updated,
    description,
    manual_relevant = NA_character_,
    manual_category = NA_character_,
    review_notes = NA_character_
  )

stopifnot(
  n_distinct(validation$job_id) == nrow(validation),
  "posted_at" %in% names(validation)
)

# STEP 8: Preserve existing manual review decisions
validation_path <- "Data/jobs_validation_sample.csv"

if (!file.exists(validation_path)) {
  write_csv(validation, validation_path, na = "")
}

# STEP 9: Review validation sample
print(
  tibble(
    review_group = c("New Inclusion", "Existing Inclusion"),
    total_jobs = c(nrow(new_jobs), nrow(existing_sample))
  )
)

View(validation)
