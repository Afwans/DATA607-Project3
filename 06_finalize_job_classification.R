
# =====================================================
# DATA 607 - PROJECT 3
# Dataset 1: Finalize Job Classification
# Script: 06_finalize_job_classification.R
# =====================================================

library(readr)
library(dplyr)
library(stringr)

# STEP 1: Load the refined dataset

jobs <- read_csv(
  "data/job_postings_refined_all.csv",
  show_col_types = FALSE
)

# STEP 2: Define data-related job title patterns

patterns <- list(
  "Data Science" =
    "\\b(data scien(tist|ce)|decision scientist|applied scientist)\\b",
  
  "AI/ML" =
    "\\b(machine learning|deep learning|ai/ml|ml engineer|ai engineer|ai platform engineer|nlp engineer|computer vision|artificial intelligence researcher)\\b",
  
  "Data Engineering" =
    "\\b(data engineer(ing)?|analytics engineer(ing)?|data architect|data pipeline|etl developer|data warehouse architect)\\b",
  
  "Business Intelligence" =
    "\\b(business intelligence|bi analyst|bi developer|power bi developer|tableau developer)\\b",
  
  "Statistics" =
    "\\b(biostatistic(s|ian)|statistician|actuarial analyst|quantitative analyst|quantitative researcher|statistical programmer)\\b",
  
  "Data Analytics" =
    "\\b(data analy(st|stics|sis)|analytics lead|analytics manager|marketing analytics|product analytics|customer analytics|reporting analyst|insights analyst|information analyst|forecast analytics|data insights|analytics & insights)\\b",
  
  "Database" =
    "\\b(database administrator|database engineer|database developer|sql developer|database architect)\\b"
)

# STEP 3: Define job titles that are usually unrelated

non_data_roles <- paste(
  c(
    "account executive",
    "sales specialist",
    "sales representative",
    "technical program manager",
    "project controller",
    "proposal manager",
    "customer support",
    "devops engineer",
    "cloud operations",
    "applications administrator",
    "vp of product",
    "marketing operations manager",
    "regulatory affairs",
    "compliance intern",
    "permit coordinator"
  ),
  collapse = "|"
)

# STEP 4: Identify strong data-related responsibilities

strong_work <- paste(
  c(
    "statistical model(ing|s)?",
    "predictive model(ing|s)?",
    "machine learning model(s)?",
    "train(ing)? (machine learning|ml) models?",
    "build(ing)? data pipelines?",
    "develop(ing)? data pipelines?",
    "etl pipelines?",
    "data warehouse",
    "business intelligence",
    "analy[sz](e|ing) data",
    "data analysis",
    "build(ing)? dashboards?",
    "develop(ing)? dashboards?",
    "data visualization"
  ),
  collapse = "|"
)

# STEP 5: Function to identify job category

find_category <- function(title) {
  
  if (is.na(title)) {
    return(NA_character_)
  }
  
  for (nm in names(patterns)) {
    
    if (
      str_detect(
        title,
        regex(
          patterns[[nm]],
          ignore_case = TRUE
        )
      )
    ) {
      return(nm)
    }
  }
  
  NA_character_
}

# STEP 6: Classify all candidate jobs

jobs_final <- jobs %>%
  mutate(
    
    job_category = vapply(
      title,
      find_category,
      character(1)
    ),
    
    non_data_title = str_detect(
      coalesce(title, ""),
      regex(non_data_roles, ignore_case = TRUE)
    ),
    
    strong_work_evidence = str_detect(
      coalesce(description, ""),
      regex(strong_work, ignore_case = TRUE)
    ),
    
    classification = case_when(
      
      !is.na(job_category) &
        !non_data_title ~ "Include",
      
      !is.na(job_category) &
        non_data_title ~ "Review",
      
      non_data_title ~ "Exclude",
      
      strong_work_evidence ~ "Review",
      
      TRUE ~ "Review"
    ),
    
    classification_basis = case_when(
      
      classification == "Include" ~
        "Specific data-related job title",
      
      classification == "Exclude" ~
        "Non-data primary job title",
      
      classification == "Review" &
        !is.na(job_category) ~
        "Conflicting title signals",
      
      classification == "Review" &
        strong_work_evidence ~
        "Data responsibilities but nonspecific title",
      
      TRUE ~
        "Insufficient evidence for automatic decision"
    ),
    
    # Calculate salary midpoint for eligible USD jobs
    
    salary_midpoint_annual = if_else(
      salary_usd_eligible %in% TRUE,
      (salary_min_annual + salary_max_annual) / 2,
      NA_real_
    )
  )

# STEP 7: Validate dataset

stopifnot(
  nrow(jobs_final) == nrow(jobs)
)

stopifnot(
  n_distinct(jobs_final$job_id) == nrow(jobs_final)
)

# STEP 8: Export classified jobs

write_csv(
  jobs_final,
  "data/jobs_classified_all.csv"
)

# STEP 9: Export provisionally included jobs

write_csv(
  filter(
    jobs_final,
    classification == "Include"
  ),
  "data/jobs_include_provisional.csv"
)

# STEP 10: Export jobs requiring manual review

write_csv(
  jobs_final %>%
    filter(classification == "Review") %>%
    select(
      job_id,
      title,
      company,
      job_category,
      skill_count,
      classification_basis,
      description
    ),
  "data/jobs_manual_review_queue.csv"
)

# STEP 11: Display classification results

cat("\nClassification counts:\n")

print(
  count(
    jobs_final,
    classification,
    sort = TRUE
  )
)

cat("\nCategories among provisional inclusions:\n")

print(
  jobs_final %>%
    filter(classification == "Include") %>%
    count(job_category, sort = TRUE)
)

cat(
  "\nUSD salary-eligible among provisional inclusions: ",
  sum(
    jobs_final$classification == "Include" &
      jobs_final$salary_usd_eligible %in% TRUE
  ),
  "\n",
  sep = ""
)

cat("\nSaved three CSV files to the data folder.\n")
