# =====================================================
# DATA 607 Project 3
# Script 13: Normalize Dataset 1
# =====================================================

# Load required libraries
library(readr)
library(dplyr)
library(tidyr)
library(stringr)

# Read the cleaned original dataset
jobs_original <- read_csv(
  "Data/job_postings_cleaned.csv",
  show_col_types = FALSE
)

# Read the revised selected dataset
jobs_revised <- read_csv(
  "Data/jobs_skills_revised.csv",
  show_col_types = FALSE
)

# Check the number of records
cat("Original jobs:", nrow(jobs_original), "\n")
cat("Selected jobs:", nrow(jobs_revised), "\n")

# Display column names
names(jobs_revised)

# =====================================================
# Step 3: Create COMPANY Table
# =====================================================

company_table <- jobs_revised %>%
  select(company_id, company) %>%
  distinct() %>%
  rename(company_name = company) %>%
  arrange(company_name)

# Check total company records
cat("Total companies:", nrow(company_table), "\n")

# Check for duplicate company IDs
cat(
  "Duplicate company IDs:",
  sum(duplicated(company_table$company_id)),
  "\n"
)

# Check for missing company IDs
cat(
  "Missing company IDs:",
  sum(is.na(company_table$company_id)),
  "\n"
)

# Preview the first 10 companies
print(head(company_table, 10))


# =====================================================
# Step 4: Create JOB_POSTING Table
# =====================================================

job_posting_table <- jobs_revised %>%
  select(
    job_id,
    company_id,
    title,
    department,
    location,
    city,
    region,
    country_code,
    workplace_type,
    employment_type,
    seniority,
    posted_at,
    first_seen_at,
    language,
    url,
    apply_url,
    description,
    job_category_updated,
    classification_updated
  ) %>%
  distinct() %>%
  arrange(job_id)

# Check total job postings
cat("Total job postings:", nrow(job_posting_table), "\n")

# Check duplicate job IDs
cat(
  "Duplicate job IDs:",
  sum(duplicated(job_posting_table$job_id)),
  "\n"
)

# Check missing job IDs
cat(
  "Missing job IDs:",
  sum(is.na(job_posting_table$job_id)),
  "\n"
)

# Check company relationships
cat(
  "Jobs with unmatched company IDs:",
  sum(
    !job_posting_table$company_id %in%
      company_table$company_id
  ),
  "\n"
)

# Preview the first 10 records
print(
  job_posting_table %>%
    select(
      job_id,
      company_id,
      title,
      job_category_updated
    ) %>%
    head(10)
)


# =====================================================
# Step 5: Create SALARY Table
# =====================================================

salary_table <- jobs_revised %>%
  select(
    job_id,
    salary_min,
    salary_max,
    salary_currency,
    salary_period,
    salary_text,
    salary_source,
    salary_min_annual,
    salary_max_annual,
    salary_midpoint_annual,
    salary_complete,
    salary_valid,
    salary_outlier_flag,
    salary_usd_eligible
  ) %>%
  distinct() %>%
  arrange(job_id)

# Check total salary records
cat("Total salary records:", nrow(salary_table), "\n")

# Check duplicate job IDs
cat(
  "Duplicate job IDs:",
  sum(duplicated(salary_table$job_id)),
  "\n"
)

# Check missing job IDs
cat(
  "Missing job IDs:",
  sum(is.na(salary_table$job_id)),
  "\n"
)

# Check relationship with JOB_POSTING
cat(
  "Salary records with unmatched job IDs:",
  sum(
    !salary_table$job_id %in%
      job_posting_table$job_id
  ),
  "\n"
)

# Check eligible USD salary records
cat(
  "Eligible USD salary records:",
  sum(salary_table$salary_usd_eligible %in% TRUE),
  "\n"
)

# Preview first 10 salary records
print(
  salary_table %>%
    select(
      job_id,
      salary_min_annual,
      salary_max_annual,
      salary_midpoint_annual,
      salary_usd_eligible
    ) %>%
    head(10)
)

# =====================================================
# Step 6: Create SKILL Table
# =====================================================

# Identify skill columns, excluding numeric skill_count
skill_columns <- setdiff(
  grep("^skill_", names(jobs_revised), value = TRUE),
  "skill_count"
)

# Create a lookup table for the technical skills
skill_table <- tibble(
  skill_id = seq_along(skill_columns),
  skill_name = skill_columns %>%
    str_remove("^skill_") %>%
    str_replace_all("_", " ") %>%
    str_to_title(),
  source_column = skill_columns
)

# Check total skills
cat("Total technical skills:", nrow(skill_table), "\n")

# Check duplicate skill IDs
cat(
  "Duplicate skill IDs:",
  sum(duplicated(skill_table$skill_id)),
  "\n"
)

# Check duplicate skill names
cat(
  "Duplicate skill names:",
  sum(duplicated(skill_table$skill_name)),
  "\n"
)

# Check missing skill names
cat(
  "Missing skill names:",
  sum(is.na(skill_table$skill_name)),
  "\n"
)

# Display all skills
print(skill_table, n = 30)


# =====================================================
# Step 7: Create JOB_SKILL Table
# =====================================================

# Improve skill name capitalization
skill_table <- skill_table %>%
  mutate(
    skill_name = case_when(
      source_column == "skill_sql" ~ "SQL",
      source_column == "skill_power_bi" ~ "Power BI",
      source_column == "skill_etl" ~ "ETL",
      source_column == "skill_aws" ~ "AWS",
      source_column == "skill_tensorflow" ~ "TensorFlow",
      source_column == "skill_pytorch" ~ "PyTorch",
      source_column == "skill_scikit_learn" ~ "Scikit-learn",
      source_column == "skill_nlp" ~ "NLP",
      source_column == "skill_llm" ~ "LLM",
      source_column == "skill_generative_ai" ~ "Generative AI",
      source_column == "skill_dbt" ~ "dbt",
      TRUE ~ skill_name
    )
  )

# Convert TRUE skill indicators into job-skill relationships
job_skill_table <- jobs_revised %>%
  select(job_id, all_of(skill_columns)) %>%
  pivot_longer(
    cols = all_of(skill_columns),
    names_to = "source_column",
    values_to = "has_skill"
  ) %>%
  filter(has_skill %in% TRUE) %>%
  inner_join(
    skill_table,
    by = "source_column"
  ) %>%
  select(job_id, skill_id) %>%
  distinct() %>%
  arrange(job_id, skill_id)

# Validate the JOB_SKILL table
cat("Total job-skill relationships:", nrow(job_skill_table), "\n")

cat(
  "Duplicate job-skill pairs:",
  sum(duplicated(job_skill_table)),
  "\n"
)

cat(
  "Unmatched job IDs:",
  sum(!job_skill_table$job_id %in% job_posting_table$job_id),
  "\n"
)

cat(
  "Unmatched skill IDs:",
  sum(!job_skill_table$skill_id %in% skill_table$skill_id),
  "\n"
)

# Preview first 10 relationships
print(head(job_skill_table, 10))

# =====================================================
# Step 8: Export Normalized Database
# =====================================================

library(writexl)

# Create output folder
output_folder <- "Data/Normalized"

dir.create(
  output_folder,
  recursive = TRUE,
  showWarnings = FALSE
)

# Store the five tables in a named list
normalized_tables <- list(
  COMPANY = company_table,
  JOB_POSTING = job_posting_table,
  SALARY = salary_table,
  SKILL = skill_table,
  JOB_SKILL = job_skill_table
)

# Export all tables into one Excel workbook
write_xlsx(
  normalized_tables,
  path = file.path(
    output_folder,
    "Dataset1_Normalized_Database.xlsx"
  )
)

# Export each table as a separate CSV
for (table_name in names(normalized_tables)) {
  
  write_csv(
    normalized_tables[[table_name]],
    file.path(
      output_folder,
      paste0(table_name, ".csv")
    )
  )
  
}

# Confirm exported files
cat("\nNormalized database exported successfully!\n")

print(
  list.files(output_folder)
)