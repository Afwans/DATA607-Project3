
# =====================================================
# DATA 607 - PROJECT 3
# Dataset 1: Refine Data Science Job Filtering
# Script: 04_refine_jobs.R
# =====================================================

library(readr)
library(dplyr)
library(stringr)

# STEP 1: Load candidate jobs
jobs <- read_csv(
  "data/job_postings_data_science.csv",
  show_col_types = FALSE
)

cat("Original candidates:", nrow(jobs), "\n")

# STEP 2: Define relevant job-title patterns
# These represent core data-related occupations.

core_titles <- c(
  "data scien",
  "data analy",
  "data engineer",
  "analytics engineer",
  "analytics lead",
  "business intelligence",
  "bi analyst",
  "bi developer",
  "machine learning",
  "ml engineer",
  "ai engineer",
  "ai/ml",
  "ai platform engineer",
  "applied scientist",
  "decision scientist",
  "statistician",
  "biostatistician",
  "actuarial analyst",
  "quantitative analyst",
  "quantitative researcher",
  "data architect",
  "database architect",
  "database administrator",
  "database developer",
  "database engineer",
  "sql developer",
  "data governance",
  "data quality",
  "data visualization",
  "data insights",
  "reporting analyst",
  "predictive analytics",
  "research scientist",
  "nlp engineer",
  "computer vision"
)

# STEP 3: Define data-related responsibilities

responsibility_patterns <- c(
  "analyze data",
  "analyzing data",
  "data analysis",
  "statistical modeling",
  "statistical analysis",
  "predictive modeling",
  "build dashboards",
  "develop dashboards",
  "create dashboards",
  "build data pipelines",
  "develop data pipelines",
  "design data pipelines",
  "etl pipelines",
  "build machine learning models",
  "develop machine learning models",
  "train machine learning models",
  "data warehousing",
  "data visualization",
  "develop predictive models",
  "forecasting models",
  "build reports",
  "develop reports",
  "business intelligence"
)

# STEP 4: Define clearly unrelated job-title patterns
# These are only exclusions when no core title matches.

unrelated_titles <- c(
  "account executive",
  "sales specialist",
  "sales representative",
  "financial service representative",
  "technical program manager",
  "project controller",
  "customer support",
  "devops engineer",
  "cloud operations",
  "applications administrator",
  "proposal manager",
  "vp of product",
  "marketing operations manager"
)

# STEP 5: Function for phrase matching

has_phrase <- function(text, phrases) {
  
  if (is.na(text)) return(FALSE)
  
  any(vapply(
    phrases,
    function(phrase) {
      str_detect(
        text,
        fixed(phrase, ignore_case = TRUE)
      )
    },
    logical(1)
  ))
}

# STEP 6: Score job relevance

jobs_refined <- jobs %>%
  mutate(
    core_title_match = vapply(
      title, has_phrase, logical(1),
      phrases = core_titles
    ),
    
    responsibility_count = vapply(
      description,
      function(x) {
        if (is.na(x)) return(0L)
        
        sum(vapply(
          responsibility_patterns,
          function(p) {
            str_detect(
              x,
              fixed(p, ignore_case = TRUE)
            )
          },
          logical(1)
        ))
      },
      integer(1)
    ),
    
    unrelated_title_match = vapply(
      title, has_phrase, logical(1),
      phrases = unrelated_titles
    ),
    
    # Provisional relevance classification
    relevance_status = case_when(
      core_title_match ~ "Likely Relevant",
      
      unrelated_title_match ~ "Likely Unrelated",
      
      responsibility_count >= 2 &
        skill_count >= 3 ~ "Likely Relevant",
      
      TRUE ~ "Needs Review"
    )
  )

# STEP 7: Review classification counts

cat("\n--- RELEVANCE RESULTS ---\n")

jobs_refined %>%
  count(relevance_status, sort = TRUE) %>%
  print()

# STEP 8: Review examples

jobs_refined %>%
  select(
    title,
    company,
    skill_count,
    responsibility_count,
    relevance_status
  ) %>%
  arrange(relevance_status, desc(responsibility_count)) %>%
  print(n = 50)

# STEP 9: Export all scored jobs
write_csv(
  jobs_refined,
  "data/job_postings_refined_all.csv"
)

# STEP 10: Create provisional relevant subset

jobs_relevant <- jobs_refined %>%
  filter(relevance_status == "Likely Relevant")

write_csv(
  jobs_relevant,
  "data/job_postings_relevant.csv"
)

# STEP 11: Export uncertain jobs for review

jobs_uncertain <- jobs_refined %>%
  filter(relevance_status == "Needs Review")

write_csv(
  jobs_uncertain,
  "data/job_postings_uncertain.csv"
)

cat("\n--- FINAL SUMMARY ---\n")
cat("Total candidates:", nrow(jobs), "\n")
cat("Likely relevant:", nrow(jobs_relevant), "\n")
cat("Needs review:", nrow(jobs_uncertain), "\n")
cat(
  "Likely unrelated:",
  sum(jobs_refined$relevance_status == "Likely Unrelated"),
  "\n"
)
