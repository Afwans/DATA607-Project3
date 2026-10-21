
# ===================================================
# DATA 607 - PROJECT 3
# Step 7: Validate Data Science Job Filtering
# ===================================================

library(readr)
library(dplyr)
library(stringr)

# Load filtered candidate jobs
jobs_ds <- read_csv(
  "data/job_postings_data_science.csv",
  show_col_types = FALSE
)

# Load jobs selected for description review
jobs_review <- read_csv(
  "data/job_postings_review.csv",
  show_col_types = FALSE
)

# 1. Check dataset sizes
cat("Data-related candidates:", nrow(jobs_ds), "\n")
cat("Description-only candidates:", nrow(jobs_review), "\n")

# 2. Check how jobs were selected
jobs_ds %>%
  count(match_reason, sort = TRUE) %>%
  print()

# 3. Review the most common job titles
jobs_ds %>%
  count(title, sort = TRUE) %>%
  print(n = 30)

# 4. Review jobs selected only by descriptions
review_sample <- jobs_review %>%
  select(
    job_id,
    title,
    company,
    skill_count,
    description
  ) %>%
  arrange(desc(skill_count))

# Open the records in RStudio
View(review_sample)

# 5. Create a reproducible random review sample
set.seed(607)

sample_size <- min(30, nrow(jobs_review))

sample_review <- jobs_review %>%
  slice_sample(n = sample_size) %>%
  select(
    job_id,
    title,
    company,
    skill_count,
    description
  )

# Protect existing review sample
sample_path <- "data/job_review_sample.csv"

if (!file.exists(sample_path)) {
  
  write_csv(
    sample_review,
    sample_path
  )
  
  cat("New review sample exported.\n")
  
} else {
  
  cat("Existing review sample preserved.\n")
  
}

cat("Review sample exported:", nrow(sample_review), "\n")


# ---------------------------------------------------
# Step 8: Prepare Manual Relevance Review
# ---------------------------------------------------

# Create a review sheet
manual_review <- sample_review %>%
  mutate(
    relevant = NA_character_,
    job_category = NA_character_,
    review_notes = NA_character_
  ) %>%
  select(
    job_id,
    title,
    company,
    skill_count,
    relevant,
    job_category,
    review_notes,
    description
  )

# Export review sheet
# Protect existing manual review decisions
manual_review_path <- "data/job_manual_review.csv"

if (!file.exists(manual_review_path)) {
  
  write_csv(
    manual_review,
    manual_review_path,
    na = ""
  )
  
  cat("New manual review sheet created.\n")
  
} else {
  
  cat("Existing manual review CSV preserved.\n")
  cat("No manual decisions were overwritten.\n")
  
}

cat("Manual review step completed.\n")
