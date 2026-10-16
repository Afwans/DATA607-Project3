
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
    review_group,
    suggested_category = job_category_updated,
    description,
    manual_relevant = NA_character_,
    manual_category = NA_character_,
    review_notes = NA_character_
  )

# STEP 4: Save the review file

write_csv(
  validation,
  "data/jobs_validation_sample.csv"
)

# STEP 5: Display summary

cat("\nNewly included jobs:", nrow(new_jobs), "\n")
cat("Previously included jobs sampled:",
    nrow(existing_sample), "\n")
cat("Total jobs for validation:",
    nrow(validation), "\n")

validation %>%
  count(review_group) %>%
  print()

cat("\nValidation file saved successfully.\n")
