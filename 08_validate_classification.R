
# =====================================================
# DATA 607 - PROJECT 3
# Script: 08_validate_classification.R
# =====================================================

library(readr)
library(dplyr)

jobs <- read_csv(
  "data/jobs_classified_updated.csv",
  show_col_types = FALSE
)

# STEP 0A: Validate posting dates

cat("\n--- POSTING DATE VALIDATION ---\n")

stopifnot("posted_at" %in% names(jobs))

jobs %>%
  summarise(
    total_jobs = n(),
    valid_dates = sum(!is.na(posted_at)),
    missing_dates = sum(is.na(posted_at)),
    earliest_date = if (all(is.na(posted_at))) {
      as.Date(NA)
    } else {
      as.Date(min(posted_at, na.rm = TRUE))
    },
    latest_date = if (all(is.na(posted_at))) {
      as.Date(NA)
    } else {
      as.Date(max(posted_at, na.rm = TRUE))
    }
  ) %>%
  print()

cat("\nSaved classification counts:\n")

jobs %>%
  count(classification_updated, sort = TRUE) %>%
  print()

# STEP 1: Identify newly included jobs

new_jobs <- jobs %>%
  filter(
    classification_updated == "Include",
    classification != "Include"
  )

# STEP 2: Sample 30 previously included jobs

set.seed(607)

existing_sample <- jobs %>%
  filter(
    classification_updated == "Include",
    classification == "Include"
  ) %>%
  slice_sample(n = 30)

# STEP 3: Combine into one review file

validation <- bind_rows(
  new_jobs %>%
    mutate(review_group = "New Inclusion"),
  
  existing_sample %>%
    mutate(review_group = "Existing Inclusion")
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

# STEP 3A: Validate the review sample

stopifnot(
  n_distinct(validation$job_id) == nrow(validation)
)

stopifnot(
  "posted_at" %in% names(validation)
)

stopifnot(
  all(!is.na(validation$posted_at))
)

cat("\nValidation sample checks passed.\n")

# STEP 4: Save validation file safely

validation_path <- "data/jobs_validation_sample.csv"

if (!file.exists(validation_path)) {
  
  write_csv(
    validation,
    validation_path,
    na = ""
  )
  
  cat("New validation sample CSV created.\n")
  
} else {
  
  cat("Existing validation sample CSV preserved.\n")
  cat("Manual relevance decisions and review notes were not overwritten.\n")
  
}
# STEP 5: Display summary

cat("\nNewly included jobs:", nrow(new_jobs), "\n")
cat("Previously included jobs sampled:",
    nrow(existing_sample), "\n")
cat("Total jobs for validation:",
    nrow(validation), "\n")

validation %>%
  count(review_group) %>%
  print()

cat("\nScript 08 completed.\n")
cat("Existing validation CSV was preserved if already present.\n")
