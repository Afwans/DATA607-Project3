# =====================================================
# DATA 607 Project 3
# Script 13: Normalize Dataset 1 (safe, non-overwriting)
# =====================================================

library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(writexl)

# Input files are read-only. Existing outputs are never overwritten.
find_input <- function(filename) {
  candidates <- c(file.path('Data', filename), file.path('data', filename))
  found <- candidates[file.exists(candidates)]
  if (!length(found)) stop('Required input file not found: ', filename,
                           '\nChecked: ', paste(candidates, collapse = ', '))
  if (length(found) > 1L) {
    a <- normalizePath(found[1], winslash = '/', mustWork = TRUE)
    b <- normalizePath(found[2], winslash = '/', mustWork = TRUE)
    if (a != b) stop('Two different copies of ', filename,
                     ' found under Data/ and data/. Choose one explicitly.')
  }
  found[1]
}

original_path <- find_input('job_postings_cleaned.csv')
revised_path <- find_input('jobs_skills_revised.csv')
jobs_original <- read_csv(original_path, show_col_types = FALSE)
jobs_revised <- read_csv(revised_path, show_col_types = FALSE)

cat('\n========== INPUT DATA ==========',
    '\nOriginal source:', original_path,
    '\nRevised source:', revised_path,
    '\nOriginal jobs:', nrow(jobs_original),
    '\nSelected jobs:', nrow(jobs_revised), '\n')

required_columns <- c(
  'job_id', 'company_id', 'company', 'title', 'department', 'location',
  'city', 'region', 'country_code', 'workplace_type', 'employment_type',
  'seniority', 'posted_at', 'first_seen_at', 'language', 'url',
  'apply_url', 'description', 'job_category_updated',
  'classification_updated', 'salary_min', 'salary_max',
  'salary_currency', 'salary_period', 'salary_text', 'salary_source',
  'salary_min_annual', 'salary_max_annual', 'salary_midpoint_annual',
  'salary_complete', 'salary_valid', 'salary_outlier_flag',
  'salary_usd_eligible'
)
missing_columns <- setdiff(required_columns, names(jobs_revised))
if (length(missing_columns)) stop('Missing revised-data columns: ',
                                  paste(missing_columns, collapse = ', '))
if (!nrow(jobs_revised)) stop('Revised dataset is empty.')

# Validate keys and source relationships BEFORE distinct() could mask problems.
stopifnot(!anyNA(jobs_revised$job_id),
          !anyNA(jobs_revised$company_id),
          !anyNA(jobs_revised$posted_at))
if (anyDuplicated(jobs_revised$job_id)) {
  stop('Duplicate job_id in revised input; inspect before normalizing.')
}
if (any(!nzchar(trimws(as.character(jobs_revised$company_id))))) {
  stop('Blank company_id in revised input.')
}
if (any(is.na(jobs_revised$company) |
        !nzchar(trimws(jobs_revised$company)))) {
  stop('Missing or blank company name in revised input.')
}

cat('\n========== POSTING DATE VALIDATION ==========\n')
print(jobs_revised %>% summarise(
  total_jobs = n(),
  valid_dates = sum(!is.na(posted_at)),
  missing_dates = sum(is.na(posted_at)),
  earliest_date = as.Date(min(posted_at)),
  latest_date = as.Date(max(posted_at))
))

# A company_id must refer to one name, and a company name must not map to
# multiple IDs without deliberate reconciliation.
company_mapping <- jobs_revised %>%
  distinct(company_id, company)
conflicting_ids <- company_mapping %>% count(company_id) %>% filter(n > 1)
conflicting_names <- company_mapping %>% count(company) %>% filter(n > 1)
cat('Company IDs mapped to multiple names:', nrow(conflicting_ids), '\n')
cat('Company names mapped to multiple IDs:', nrow(conflicting_names), '\n')
if (nrow(conflicting_ids) || nrow(conflicting_names)) {
  stop('Inconsistent company mappings; review input before exporting.')
}

# =====================================================
# Step 3: COMPANY
# =====================================================
company_table <- company_mapping %>%
  rename(company_name = company) %>%
  arrange(company_name)
cat('\nCOMPANY rows:', nrow(company_table), '\n')
print(head(company_table, 10))

# =====================================================
# Step 4: JOB_POSTING (posted_at preserved)
# =====================================================
job_posting_table <- jobs_revised %>%
  select(job_id, company_id, title, department, location, city,
         region, country_code, workplace_type, employment_type,
         seniority, posted_at, first_seen_at, language, url,
         apply_url, description, job_category_updated,
         classification_updated) %>%
  arrange(job_id)

stopifnot(nrow(job_posting_table) == nrow(jobs_revised),
          !anyDuplicated(job_posting_table$job_id),
          all(job_posting_table$company_id %in% company_table$company_id))
posting_date_check <- job_posting_table %>%
  select(job_id, posted_at) %>%
  inner_join(jobs_revised %>% select(job_id, posted_at),
             by = 'job_id', suffix = c('_normalized', '_source'))
stopifnot(nrow(posting_date_check) == nrow(jobs_revised),
          all(as.character(posting_date_check$posted_at_normalized) ==
                as.character(posting_date_check$posted_at_source)))
cat('\nJOB_POSTING rows:', nrow(job_posting_table), '\n')
cat('Unmatched company IDs:',
    sum(!job_posting_table$company_id %in% company_table$company_id), '\n')
cat('Posting timestamp mismatches: 0\n')
print(head(job_posting_table %>%
             select(job_id, company_id, title, posted_at,
                    job_category_updated), 10))

# =====================================================
# Step 5: SALARY (one record per selected job)
# =====================================================
salary_table <- jobs_revised %>%
  select(job_id, salary_min, salary_max, salary_currency,
         salary_period, salary_text, salary_source,
         salary_min_annual, salary_max_annual,
         salary_midpoint_annual, salary_complete, salary_valid,
         salary_outlier_flag, salary_usd_eligible) %>%
  arrange(job_id)
stopifnot(nrow(salary_table) == nrow(job_posting_table),
          !anyDuplicated(salary_table$job_id),
          all(salary_table$job_id %in% job_posting_table$job_id))
cat('\nSALARY rows:', nrow(salary_table), '\n')
cat('Eligible USD salary records:',
    sum(salary_table$salary_usd_eligible %in% TRUE), '\n')
print(head(salary_table %>%
             select(job_id, salary_min_annual, salary_max_annual,
                    salary_midpoint_annual, salary_usd_eligible), 10))

# =====================================================
# Step 6: SKILL lookup (30 logical indicator columns)
# =====================================================
skill_columns <- setdiff(
  grep('^skill_', names(jobs_revised), value = TRUE), 'skill_count'
)
cat('\nSkill columns detected:', length(skill_columns), '\n')
if (length(skill_columns) != 30L) {
  stop('Expected 30 skill indicator columns, found ', length(skill_columns))
}
if (!all(vapply(jobs_revised[skill_columns], is.logical, logical(1)))) {
  stop('Skill indicator columns must be logical TRUE/FALSE values.')
}
if (any(vapply(jobs_revised[skill_columns], anyNA, logical(1)))) {
  stop('Missing values found in skill indicators.')
}

skill_table <- tibble(
  skill_id = seq_along(skill_columns),
  skill_name = skill_columns %>%
    str_remove('^skill_') %>%
    str_replace_all('_', ' ') %>%
    str_to_title(),
  source_column = skill_columns
) %>%
  mutate(skill_name = case_when(
    source_column == 'skill_sql' ~ 'SQL',
    source_column == 'skill_power_bi' ~ 'Power BI',
    source_column == 'skill_etl' ~ 'ETL',
    source_column == 'skill_aws' ~ 'AWS',
    source_column == 'skill_tensorflow' ~ 'TensorFlow',
    source_column == 'skill_pytorch' ~ 'PyTorch',
    source_column == 'skill_scikit_learn' ~ 'Scikit-learn',
    source_column == 'skill_nlp' ~ 'NLP',
    source_column == 'skill_llm' ~ 'LLM',
    source_column == 'skill_generative_ai' ~ 'Generative AI',
    source_column == 'skill_dbt' ~ 'dbt',
    TRUE ~ skill_name
  ))
stopifnot(!anyDuplicated(skill_table$skill_id),
          !anyDuplicated(skill_table$skill_name),
          !anyNA(skill_table$skill_name))
cat('SKILL rows:', nrow(skill_table), '\n')
print(skill_table, n = Inf)

# =====================================================
# Step 7: JOB_SKILL bridge
# =====================================================
job_skill_table <- jobs_revised %>%
  select(job_id, all_of(skill_columns)) %>%
  pivot_longer(cols = all_of(skill_columns),
               names_to = 'source_column', values_to = 'has_skill') %>%
  filter(has_skill %in% TRUE) %>%
  inner_join(skill_table, by = 'source_column') %>%
  select(job_id, skill_id) %>%
  distinct() %>%
  arrange(job_id, skill_id)

expected_links <- sum(unlist(jobs_revised[skill_columns]), na.rm = TRUE)
stopifnot(nrow(job_skill_table) == expected_links,
          !anyDuplicated(job_skill_table),
          all(job_skill_table$job_id %in% job_posting_table$job_id),
          all(job_skill_table$skill_id %in% skill_table$skill_id))
cat('\nJOB_SKILL rows:', nrow(job_skill_table), '\n')
cat('Duplicate job-skill pairs:', sum(duplicated(job_skill_table)), '\n')
print(head(job_skill_table, 10))

# =====================================================
# Step 8: Safe export (never overwrite existing files)
# =====================================================
# Keep original Data/Normalized convention; use existing lowercase folder
# if that is the only existing normalized output location.
if (dir.exists('Data/Normalized')) {
  output_folder <- 'Data/Normalized'
} else if (dir.exists('data/Normalized')) {
  output_folder <- 'data/Normalized'
} else {
  output_folder <- file.path(dirname(revised_path), 'Normalized')
}
dir.create(output_folder, recursive = TRUE, showWarnings = FALSE)

normalized_tables <- list(
  COMPANY = company_table,
  JOB_POSTING = job_posting_table,
  SALARY = salary_table,
  SKILL = skill_table,
  JOB_SKILL = job_skill_table
)

excel_path <- file.path(output_folder, 'Dataset1_Normalized_Database.xlsx')
if (!file.exists(excel_path)) {
  write_xlsx(normalized_tables, path = excel_path)
  cat('Created:', excel_path, '\n')
} else {
  cat('Preserved existing workbook:', excel_path, '\n')
}

for (table_name in names(normalized_tables)) {
  csv_path <- file.path(output_folder, paste0(table_name, '.csv'))
  if (!file.exists(csv_path)) {
    write_csv(normalized_tables[[table_name]], csv_path)
    cat('Created:', csv_path, '\n')
  } else {
    cat('Preserved existing file:', csv_path, '\n')
  }
}

cat('\n========== NORMALIZATION SUMMARY ==========\n')
for (table_name in names(normalized_tables)) {
  cat(table_name, ':', nrow(normalized_tables[[table_name]]), 'rows\n')
}
cat('Posting dates:', as.character(min(as.Date(job_posting_table$posted_at))),
    'to', as.character(max(as.Date(job_posting_table$posted_at))), '\n')
cat('Output folder:', output_folder, '\n')
cat('Existing CSV and Excel files were preserved wherever present.\n')
cat('\nSCRIPT 13 COMPLETED.\n')
