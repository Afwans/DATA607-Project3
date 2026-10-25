# =====================================================
# DATA 607 - PROJECT 3
# Dataset 1: Normalize Job Postings
# Script: 13_normalize_dataset.R
# =====================================================

library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(writexl)

# STEP 1: Load the full job market and Data Science-related jobs

jobs <- read_csv(
  "Data/jobs_skills_analyzed_full.csv",
  show_col_types = FALSE
)

jobs_ds <- read_csv(
  "Data/jobs_skills_analyzed.csv",
  show_col_types = FALSE
)

required_columns <- c(
  "job_id", "company", "title", "posted_at",
  "salary_min_annual", "salary_max_annual", "salary_usd_eligible"
)

stopifnot(
  all(required_columns %in% names(jobs)),
  "job_id" %in% names(jobs_ds),
  nrow(jobs) > 0,
  !anyNA(jobs$job_id),
  !anyDuplicated(jobs$job_id),
  !anyNA(jobs_ds$job_id),
  !anyDuplicated(jobs_ds$job_id),
  all(jobs_ds$job_id %in% jobs$job_id)
)

print(tibble(
  dataset = c("Full Job Market", "Data Science-Related Jobs"),
  job_count = c(nrow(jobs), nrow(jobs_ds)),
  missing_dates = c(
    sum(is.na(jobs$posted_at)),
    sum(is.na(jobs_ds$posted_at))
  )
))

# STEP 2: Prepare stable company keys

if (!"company_id" %in% names(jobs)) {
  jobs$company_id <- NA_character_
}

jobs <- jobs %>%
  mutate(
    company = na_if(str_squish(as.character(company)), ""),
    company_id = na_if(str_squish(as.character(company_id)), "")
  )

if (anyNA(jobs$company)) {
  stop("Missing company names found. Review the source data.")
}

# Use source IDs when available. Otherwise, assign a stable key by company name.
company_names <- sort(unique(jobs$company))
company_keys <- tibble(
  company = company_names,
  normalized_company_id = seq_along(company_names)
)

jobs <- jobs %>%
  left_join(company_keys, by = "company")

company_table <- jobs %>%
  distinct(
    company_id = normalized_company_id,
    company_name = company
  ) %>%
  arrange(company_id)

stopifnot(
  !anyNA(jobs$normalized_company_id),
  !anyDuplicated(company_table$company_id),
  !anyDuplicated(company_table$company_name)
)

# STEP 3: Create JOB_POSTING table for the entire dataset

posting_columns <- intersect(
  c(
    "job_id", "normalized_company_id", "title", "department",
    "location", "city", "region", "country_code",
    "workplace_type", "employment_type", "seniority",
    "posted_at", "first_seen_at", "language",
    "url", "apply_url", "description"
  ),
  names(jobs)
)

job_posting_table <- jobs %>%
  select(all_of(posting_columns)) %>%
  rename(company_id = normalized_company_id) %>%
  mutate(
    is_data_science_related = job_id %in% jobs_ds$job_id
  ) %>%
  arrange(job_id)

stopifnot(
  nrow(job_posting_table) == nrow(jobs),
  !anyDuplicated(job_posting_table$job_id),
  all(job_posting_table$company_id %in% company_table$company_id)
)

# STEP 4: Create SALARY table (including jobs without salary data)

salary_columns <- intersect(
  c(
    "job_id", "salary_min", "salary_max", "salary_currency",
    "salary_period", "salary_text", "salary_source",
    "salary_min_annual", "salary_max_annual",
    "salary_complete", "salary_valid",
    "salary_outlier_flag", "salary_usd_eligible"
  ),
  names(jobs)
)

salary_table <- jobs %>%
  select(all_of(salary_columns)) %>%
  mutate(
    salary_midpoint_annual = if_else(
      salary_usd_eligible %in% TRUE &
        is.finite(salary_min_annual) &
        is.finite(salary_max_annual) &
        salary_min_annual <= salary_max_annual,
      (salary_min_annual + salary_max_annual) / 2,
      NA_real_
    )
  ) %>%
  arrange(job_id)

stopifnot(
  nrow(salary_table) == nrow(jobs),
  !anyDuplicated(salary_table$job_id),
  all(salary_table$job_id %in% job_posting_table$job_id)
)

# STEP 5: Create SKILL lookup from the 30 indicators

skill_columns <- setdiff(
  grep("^skill_", names(jobs), value = TRUE),
  "skill_count"
)

stopifnot(
  length(skill_columns) == 30,
  all(vapply(jobs[skill_columns], is.logical, logical(1))),
  all(vapply(jobs[skill_columns], function(x) !anyNA(x), logical(1)))
)

skill_table <- tibble(
  skill_id = seq_along(skill_columns),
  source_column = skill_columns,
  skill_name = skill_columns %>%
    str_remove("^skill_") %>%
    str_replace_all("_", " ") %>%
    str_to_title()
) %>%
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
      source_column == "skill_dbt" ~ "dbt",
      source_column == "skill_r" ~ "R",
      TRUE ~ skill_name
    )
  )

stopifnot(
  !anyDuplicated(skill_table$skill_id),
  !anyDuplicated(skill_table$skill_name)
)

# STEP 6: Create JOB_SKILL bridge table

job_skill_table <- jobs %>%
  select(job_id, all_of(skill_columns)) %>%
  pivot_longer(
    cols = all_of(skill_columns),
    names_to = "source_column",
    values_to = "mentioned"
  ) %>%
  filter(mentioned) %>%
  inner_join(
    skill_table %>% select(skill_id, source_column),
    by = "source_column"
  ) %>%
  select(job_id, skill_id) %>%
  distinct() %>%
  arrange(job_id, skill_id)

expected_links <- sum(vapply(
  jobs[skill_columns], sum, integer(1)
))

stopifnot(
  nrow(job_skill_table) == expected_links,
  !anyDuplicated(job_skill_table),
  all(job_skill_table$job_id %in% job_posting_table$job_id),
  all(job_skill_table$skill_id %in% skill_table$skill_id)
)

# STEP 7: Keep detailed Data Science classification separately

classification_columns <- intersect(
  c(
    "job_id", "job_category_updated",
    "classification_updated", "classification_basis"
  ),
  names(jobs_ds)
)

classification_table <- jobs_ds %>%
  select(all_of(classification_columns)) %>%
  distinct(job_id, .keep_all = TRUE) %>%
  arrange(job_id)

stopifnot(
  nrow(classification_table) == nrow(jobs_ds),
  all(classification_table$job_id %in% job_posting_table$job_id)
)

# STEP 8: Validate normalized tables

normalized_summary <- tibble(
  table_name = c(
    "COMPANY", "JOB_POSTING", "SALARY",
    "SKILL", "JOB_SKILL", "DATA_SCIENCE_CLASSIFICATION"
  ),
  row_count = c(
    nrow(company_table), nrow(job_posting_table),
    nrow(salary_table), nrow(skill_table),
    nrow(job_skill_table), nrow(classification_table)
  )
)

print(normalized_summary)

date_check <- job_posting_table %>%
  select(job_id, posted_at) %>%
  inner_join(
    jobs %>% select(job_id, posted_at),
    by = "job_id",
    suffix = c("_normalized", "_source")
  )

stopifnot(
  nrow(date_check) == nrow(jobs),
  identical(
    as.character(date_check$posted_at_normalized),
    as.character(date_check$posted_at_source)
  )
)

# STEP 9: Export normalized tables

output_folder <- "Data/Normalized"
dir.create(output_folder, recursive = TRUE, showWarnings = FALSE)

normalized_tables <- list(
  COMPANY = company_table,
  JOB_POSTING = job_posting_table,
  SALARY = salary_table,
  SKILL = skill_table,
  JOB_SKILL = job_skill_table,
  DATA_SCIENCE_CLASSIFICATION = classification_table
)

for (table_name in names(normalized_tables)) {
  write_csv(
    normalized_tables[[table_name]],
    file.path(output_folder, paste0(table_name, ".csv"))
  )
}

write_xlsx(
  normalized_tables,
  path = file.path(output_folder, "Dataset1_Normalized_Database.xlsx")
)

View(normalized_summary)
