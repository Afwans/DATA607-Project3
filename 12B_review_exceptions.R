
# ============================================================
# DATA 607 - Project 3
# Step 12B: Review Classification and Skill Exceptions
# ============================================================

library(readr)
library(dplyr)
library(stringr)
library(tidyr)

# ------------------------------------------------------------
# 1. LOAD VALIDATION FILES
# ------------------------------------------------------------

jobs <- read_csv(
  "data/jobs_skills_analyzed.csv",
  show_col_types = FALSE
)

zero_skill_jobs <- read_csv(
  "data/validation_jobs_no_skills.csv",
  show_col_types = FALSE
)

duplicate_jobs <- read_csv(
  "data/validation_duplicate_titles.csv",
  show_col_types = FALSE
)

cat("\n========== STEP 12B ==========\n")
cat("Total analysis jobs:", nrow(jobs), "\n")
cat("Zero-skill jobs:", nrow(zero_skill_jobs), "\n")
cat("Repeated title/company rows:", nrow(duplicate_jobs), "\n")

# ------------------------------------------------------------
# 2. BUILD MANUAL REVIEW SHEET
# ------------------------------------------------------------

review_sheet <- zero_skill_jobs %>%
  mutate(
    proposed_decision = case_when(
      str_detect(
        str_to_lower(title),
        "sensor technician|testing and qualification"
      ) ~ "Review for exclusion",
      
      str_detect(
        str_to_lower(title),
        "gtm|go.to.market"
      ) ~ "Review for exclusion",
      
      TRUE ~ "Review for inclusion"
    ),
    
    final_decision = NA_character_,
    reviewer_notes = NA_character_,
    missed_skills = NA_character_
  ) %>%
  select(
    job_id,
    title,
    company,
    job_category_updated,
    description,
    proposed_decision,
    final_decision,
    missed_skills,
    reviewer_notes
  )

write_csv(
  review_sheet,
  "data/validation_manual_review_sheet.csv"
)

cat("\nManual review sheet created.\n")
print(
  review_sheet %>%
    select(
      job_id,
      title,
      proposed_decision
    ),
  n = Inf
)

# ------------------------------------------------------------
# 3. DOCUMENT REPEATED TITLE/COMPANY POSTINGS
# ------------------------------------------------------------

duplicate_review <- duplicate_jobs %>%
  mutate(
    proposed_decision = "Keep - verify separate posting",
    final_decision = NA_character_,
    reviewer_notes = NA_character_
  ) %>%
  select(
    job_id,
    title,
    company,
    everything()
  )

write_csv(
  duplicate_review,
  "data/validation_duplicate_review_sheet.csv"
)

cat("\nDuplicate review sheet created.\n")

# ------------------------------------------------------------
# 4. GENERATE REVIEW SUMMARY
# ------------------------------------------------------------

review_summary <- tibble(
  review_type = c(
    "Zero detected skills",
    "Repeated title/company"
  ),
  records = c(
    nrow(zero_skill_jobs),
    nrow(duplicate_jobs)
  ),
  status = c(
    "Pending manual review",
    "Pending confirmation"
  )
)

print(review_summary)

write_csv(
  review_summary,
  "data/validation_exception_summary.csv"
)

cat("\nSTEP 12B COMPLETED.\n")
cat("No existing analysis data was modified.\n")
