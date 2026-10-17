
# =====================================================
# DATA 607 - PROJECT 3
# Dataset 1: Improve Job Classification
# Script: 07_improve_job_classification.R
# =====================================================

library(readr)
library(dplyr)
library(stringr)

# STEP 1: Load the previously classified dataset

jobs <- read_csv(
  "data/jobs_classified_all.csv",
  show_col_types = FALSE
)

# STEP 2: Define additional job title patterns

extra_patterns <- list(
  "AI/ML" = paste(
    c(
      "mlops",
      "ai software engineer",
      "ai research",
      "llm engineer",
      "generative ai",
      "genai",
      "ai scientist",
      "machine learning operations",
      "model evaluation",
      "benchmarks & evals"
    ),
    collapse = "|"
  ),
  
  "Data Engineering" = paste(
    c(
      "data operations engineer",
      "data platform engineer",
      "data infrastructure engineer",
      "data reliability engineer",
      "data systems engineer"
    ),
    collapse = "|"
  ),
  
  "Data Analytics" = paste(
    c(
      "head of data",
      "director of analytics",
      "director, analytics",
      "manager, data & analytics",
      "analytics director",
      "advanced analytics",
      "analytics consultant",
      "insights & analytics",
      "analytics and insights"
    ),
    collapse = "|"
  ),
  
  "Statistics" = paste(
    c(
      "biostatistics",
      "statistical scientist",
      "statistical analyst",
      "quantitative expert",
      "forecasting modeler"
    ),
    collapse = "|"
  )
)

# STEP 3: Match additional titles

find_extra_category <- function(title) {
  
  if (is.na(title)) {
    return(NA_character_)
  }
  
  for (category in names(extra_patterns)) {
    
    if (
      str_detect(
        title,
        regex(
          extra_patterns[[category]],
          ignore_case = TRUE
        )
      )
    ) {
      return(category)
    }
  }
  
  NA_character_
}

# STEP 4: Improve classification

jobs_updated <- jobs %>%
  mutate(
    extra_category = vapply(
      title,
      find_extra_category,
      character(1)
    ),
    
    job_category_updated = coalesce(
      job_category,
      extra_category
    ),
    
    classification_updated = case_when(
      classification == "Include" ~ "Include",
      
      classification == "Exclude" ~ "Exclude",
      
      classification == "Review" &
        !is.na(extra_category) &
        !non_data_title ~ "Include",
      
      TRUE ~ "Review"
    )
  )

# STEP 5: Display results

cat("\nUpdated classification counts:\n")

jobs_updated %>%
  count(classification_updated, sort = TRUE) %>%
  print()

cat("\nUpdated job categories:\n")

jobs_updated %>%
  filter(classification_updated == "Include") %>%
  count(job_category_updated, sort = TRUE) %>%
  print()

# STEP 6: Export results

write_csv(
  jobs_updated,
  "data/jobs_classified_updated.csv"
)

write_csv(
  jobs_updated %>%
    filter(classification_updated == "Include"),
  "data/jobs_include_updated.csv"
)

write_csv(
  jobs_updated %>%
    filter(classification_updated == "Review"),
  "data/jobs_review_remaining.csv"
)

cat("\nFiles saved successfully.\n")
