# =====================================================
# DATA 607 - PROJECT 3
# Dataset 1: Review Job Filtering Results
# Script: 05_review_filtering.R
# =====================================================

library(readr)
library(dplyr)

# STEP 1: Load existing refined classifications (read-only)
jobs <- read_csv(
  "data/job_postings_refined_all.csv",
  show_col_types = FALSE
)

cat("Total refined jobs loaded:", nrow(jobs), "\n")

# STEP 2: Validate posting dates in the saved file
cat("\n--- POSTING DATE VALIDATION ---\n")

has_posted_at <- "posted_at" %in% names(jobs)

if (has_posted_at) {
  jobs %>%
    summarise(
      total_jobs = n(),
      valid_dates = sum(!is.na(posted_at)),
      missing_dates = sum(is.na(posted_at)),
      earliest_date = if (all(is.na(posted_at))) as.Date(NA) else as.Date(min(posted_at, na.rm = TRUE)),
      latest_date = if (all(is.na(posted_at))) as.Date(NA) else as.Date(max(posted_at, na.rm = TRUE))
    ) %>%
    print()
} else {
  cat("WARNING: posted_at is missing from the saved refined CSV.\n")
  cat("Review groups will be created without the posting date column.\n")
}

# STEP 3: Build review groups
# Include posted_at when available, without changing saved source data.
review_columns <- c(
  "job_id", "title", "company",
  if (has_posted_at) "posted_at",
  "skill_count", "responsibility_count", "description"
)

# Jobs classified as relevant based on responsibilities,
# but without a core data-related job title
possible_false_positives <- jobs %>%
  filter(
    relevance_status == "Likely Relevant",
    !core_title_match
  ) %>%
  select(all_of(review_columns)) %>%
  arrange(desc(responsibility_count))

# Jobs requiring additional review
possible_false_negatives <- jobs %>%
  filter(relevance_status == "Needs Review") %>%
  select(all_of(review_columns)) %>%
  arrange(desc(responsibility_count))

cat("\n--- REVIEW GROUP COUNTS ---\n")
cat("Possible false positives:", nrow(possible_false_positives), "\n")
cat("Jobs requiring additional review:", nrow(possible_false_negatives), "\n")

# STEP 4: Export review groups only when the CSV does not exist
# Existing files may contain manual decisions; never overwrite them.
false_positives_path <- "data/possible_false_positives.csv"

if (!file.exists(false_positives_path)) {
  write_csv(possible_false_positives, false_positives_path)
  cat("New false positives CSV created.\n")
} else {
  cat("Existing false positives CSV preserved.\n")
}

false_negatives_path <- "data/possible_false_negatives.csv"

if (!file.exists(false_negatives_path)) {
  write_csv(possible_false_negatives, false_negatives_path)
  cat("New false negatives CSV created.\n")
} else {
  cat("Existing false negatives CSV preserved.\n")
}

# STEP 5: Display review titles without lengthy descriptions
cat("\n--- POSSIBLE FALSE POSITIVES (FIRST 50) ---\n")

possible_false_positives %>%
  select(title, company, skill_count, responsibility_count) %>%
  print(n = 50)

cat("\nReview filtering script completed.\n")