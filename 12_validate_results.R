# ============================================================
# DATA 607 - Project 3
# Dataset 1: Validate Results
# Script: 12_validate_dataset1.R
# ============================================================

library(readr)
library(dplyr)
library(stringr)
library(tidyr)
library(ggplot2)
library(scales)

dir.create("data", showWarnings = FALSE)

# Existing CSV and PNG files are NEVER overwritten.
save_csv_if_new <- function(data, path) {
  if (!file.exists(path)) {
    write_csv(data, path)
    cat("Created:", path, "\n")
  } else {
    cat("Preserved existing file:", path, "\n")
  }
}

# ------------------------------------------------------------
# 1. LOAD DATA
# ------------------------------------------------------------
required_files <- c(
  "data/jobs_skills_analyzed.csv",
  "data/jobs_salary_analysis.csv"
)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0) {
  stop("Required input files missing: ", paste(missing_files, collapse = ", "))
}

jobs <- read_csv(required_files[1], show_col_types = FALSE)
salary_jobs <- read_csv(required_files[2], show_col_types = FALSE)

cat("\n========== DATASET OVERVIEW ==========\n")
cat("Skill-analysis jobs:", nrow(jobs), "\n")
cat("Salary-analysis jobs:", nrow(salary_jobs), "\n")

required_job_columns <- c("job_id", "posted_at", "title", "company")
required_salary_columns <- c(
  "job_id", "posted_at", "job_category_updated", "salary_min_annual",
  "salary_max_annual", "salary_midpoint_annual", "salary_currency",
  "seniority"
)
for (column in setdiff(required_job_columns, names(jobs))) {
  stop("Missing column in skill-analysis dataset: ", column)
}
for (column in setdiff(required_salary_columns, names(salary_jobs))) {
  stop("Missing column in salary-analysis dataset: ", column)
}
if (nrow(jobs) == 0 || nrow(salary_jobs) == 0) {
  stop("One or both input datasets are empty.")
}

# ------------------------------------------------------------
# 1A. VALIDATE POSTING DATES AND DATASET CONSISTENCY
# ------------------------------------------------------------
cat("\n========== POSTING DATE VALIDATION ==========\n")
for (dataset_name in c("jobs", "salary_jobs")) {
  dataset <- get(dataset_name)
  cat("\nDataset:", dataset_name, "\n")
  print(dataset %>% summarise(
    total_jobs = n(),
    valid_dates = sum(!is.na(posted_at)),
    missing_dates = sum(is.na(posted_at)),
    earliest_date = as.Date(min(posted_at, na.rm = TRUE)),
    latest_date = as.Date(max(posted_at, na.rm = TRUE))
  ))
  stopifnot(all(!is.na(dataset$posted_at)))
}

cat("\n========== DATASET CONSISTENCY ==========\n")
stopifnot(
  !anyNA(jobs$job_id),
  !anyNA(salary_jobs$job_id),
  n_distinct(jobs$job_id) == nrow(jobs),
  n_distinct(salary_jobs$job_id) == nrow(salary_jobs)
)

missing_salary_ids <- setdiff(salary_jobs$job_id, jobs$job_id)
cat("Salary jobs missing from skill dataset:", length(missing_salary_ids), "\n")
if (length(missing_salary_ids) > 0) {
  stop("Salary dataset includes job IDs absent from skill dataset.")
}

# Compare timestamps by job ID without relying on the order of rows.
date_comparison <- salary_jobs %>%
  select(job_id, posted_at) %>%
  inner_join(
    jobs %>% select(job_id, posted_at),
    by = "job_id", suffix = c("_salary", "_skills")
  ) %>%
  mutate(
    same_posting_date = as.character(posted_at_salary) ==
      as.character(posted_at_skills)
  )
date_mismatches <- sum(!date_comparison$same_posting_date)
cat("Posting timestamp mismatches:", date_mismatches, "\n")
if (date_mismatches > 0) {
  stop("Posting timestamps differ between datasets for matching job IDs.")
}

# ------------------------------------------------------------
# 2. CHECK DUPLICATE JOB POSTINGS
# ------------------------------------------------------------
cat("\n========== DUPLICATE CHECK ==========\n")
duplicate_ids <- jobs %>%
  count(job_id, name = "duplicate_count") %>%
  filter(duplicate_count > 1)
cat("Duplicate job IDs:", nrow(duplicate_ids), "\n")

duplicate_title_company <- jobs %>%
  mutate(
    title_clean = str_squish(str_to_lower(coalesce(title, ""))),
    company_clean = str_squish(str_to_lower(coalesce(company, "")))
  ) %>%
  group_by(title_clean, company_clean) %>%
  filter(n() > 1) %>%
  ungroup()
cat("Rows sharing title and company:", nrow(duplicate_title_company), "\n")
save_csv_if_new(duplicate_ids, "data/validation_duplicate_ids.csv")
save_csv_if_new(duplicate_title_company, "data/validation_duplicate_titles.csv")

# ------------------------------------------------------------
# 3. CHECK SKILL INDICATORS
# ------------------------------------------------------------
cat("\n========== SKILL VALIDATION ==========\n")
skill_columns <- names(jobs) %>%
  str_subset("^skill_") %>%
  setdiff("skill_count")
cat("Skill columns detected:", length(skill_columns), "\n")
if (length(skill_columns) != 30) {
  stop("Expected 30 skill columns, found ", length(skill_columns))
}
stopifnot(all(vapply(jobs[skill_columns], is.logical, logical(1))))

skill_quality <- tibble(
  skill_column = skill_columns,
  data_type = vapply(jobs[skill_columns], function(x) class(x)[1], character(1)),
  missing_values = vapply(jobs[skill_columns], function(x) sum(is.na(x)), integer(1)),
  true_count = vapply(jobs[skill_columns], function(x) sum(x == TRUE, na.rm = TRUE), integer(1))
)
print(skill_quality, n = Inf)
save_csv_if_new(skill_quality, "data/validation_skill_quality.csv")

jobs_skill_check <- jobs %>%
  mutate(detected_skill_count = rowSums(
    across(all_of(skill_columns), ~ .x == TRUE), na.rm = TRUE
  ))
zero_skill_jobs <- sum(jobs_skill_check$detected_skill_count == 0)
cat("\nJobs with zero detected skills:", zero_skill_jobs, "\n")
cat("These jobs are flagged for review, not automatically excluded.\n")
save_csv_if_new(
  jobs_skill_check %>% filter(detected_skill_count == 0),
  "data/validation_jobs_no_skills.csv"
)

# ------------------------------------------------------------
# 4. VERIFY SALARY VALUES
# ------------------------------------------------------------
cat("\n========== SALARY VALIDATION ==========\n")
salary_check <- salary_jobs %>%
  mutate(
    recalculated_midpoint = (salary_min_annual + salary_max_annual) / 2,
    midpoint_difference = salary_midpoint_annual - recalculated_midpoint,
    invalid_range = !is.na(salary_min_annual) & !is.na(salary_max_annual) &
      salary_min_annual > salary_max_annual,
    midpoint_mismatch = is.finite(midpoint_difference) &
      abs(midpoint_difference) > 0.01,
    salary_issue = is.na(salary_min_annual) |
      is.na(salary_max_annual) |
      is.na(salary_midpoint_annual) |
      !is.finite(salary_min_annual) |
      !is.finite(salary_max_annual) |
      !is.finite(salary_midpoint_annual) |
      salary_min_annual < 0 |
      salary_max_annual < 0 |
      invalid_range |
      midpoint_mismatch |
      is.na(salary_currency) |
      salary_currency != "USD"
  )
cat("Invalid salary ranges:", sum(salary_check$invalid_range), "\n")
cat("Midpoint mismatches:", sum(salary_check$midpoint_mismatch), "\n")
cat("Non-USD or missing currency records:",
    sum(is.na(salary_check$salary_currency) |
          salary_check$salary_currency != "USD"), "\n")
cat("Total salary issue records:", sum(salary_check$salary_issue), "\n")
save_csv_if_new(
  salary_check %>% filter(salary_issue),
  "data/validation_salary_issues.csv"
)

# ------------------------------------------------------------
# 5. SALARY DISTRIBUTION
# ------------------------------------------------------------
cat("\n========== SALARY DISTRIBUTION ==========\n")
if (any(salary_check$salary_issue)) {
  stop("Salary validation found issues. Review before calculating salary distributions.")
}
salary_distribution <- salary_jobs %>%
  summarise(
    n = n(),
    minimum = min(salary_midpoint_annual),
    q1 = as.numeric(quantile(salary_midpoint_annual, 0.25)),
    median = median(salary_midpoint_annual),
    mean = mean(salary_midpoint_annual),
    q3 = as.numeric(quantile(salary_midpoint_annual, 0.75)),
    maximum = max(salary_midpoint_annual),
    standard_deviation = sd(salary_midpoint_annual)
  )
print(salary_distribution)
save_csv_if_new(salary_distribution, "data/validation_salary_distribution.csv")

salary_plot <- ggplot(salary_jobs, aes(x = salary_midpoint_annual)) +
  geom_histogram(bins = 25, fill = "steelblue", color = "white") +
  geom_vline(
    xintercept = median(salary_jobs$salary_midpoint_annual),
    linetype = "dashed", linewidth = 1
  ) +
  scale_x_continuous(labels = label_dollar()) +
  labs(
    title = "Distribution of Advertised Salary Midpoints",
    subtitle = paste(nrow(salary_jobs), "eligible USD job postings"),
    x = "Annual Salary Midpoint", y = "Number of Jobs"
  ) +
  theme_minimal()
print(salary_plot)
chart_path <- "data/validation_salary_distribution.png"
if (!file.exists(chart_path)) {
  ggsave(chart_path, plot = salary_plot, width = 10, height = 6, dpi = 300)
  cat("Created:", chart_path, "\n")
} else {
  cat("Preserved existing chart:", chart_path, "\n")
}

# ------------------------------------------------------------
# 6. SALARY BY SENIORITY
# ------------------------------------------------------------
cat("\n========== SALARY BY SENIORITY ==========\n")
seniority_salary <- salary_jobs %>%
  mutate(seniority = coalesce(as.character(seniority), "Unknown")) %>%
  group_by(seniority) %>%
  summarise(
    job_count = n(),
    median_salary = median(salary_midpoint_annual),
    mean_salary = mean(salary_midpoint_annual),
    .groups = "drop"
  ) %>%
  arrange(desc(median_salary))
print(seniority_salary, n = Inf)
save_csv_if_new(seniority_salary, "data/validation_seniority_salary.csv")

# ------------------------------------------------------------
# 7. SALARY BY JOB CATEGORY AND SENIORITY
# ------------------------------------------------------------
cat("\n========== CATEGORY + SENIORITY ==========\n")
category_seniority <- salary_jobs %>%
  mutate(seniority = coalesce(as.character(seniority), "Unknown")) %>%
  group_by(job_category_updated, seniority) %>%
  summarise(
    job_count = n(),
    median_salary = median(salary_midpoint_annual),
    .groups = "drop"
  ) %>%
  arrange(job_category_updated, desc(job_count))
print(category_seniority, n = Inf)
save_csv_if_new(category_seniority, "data/validation_category_seniority.csv")

# ------------------------------------------------------------
# 8. RECHECK SELECTED SKILL-SALARY ASSOCIATIONS
# ------------------------------------------------------------
cat("\n========== WITHIN-CATEGORY SKILL COMPARISON ==========\n")
selected_skills <- c(
  "skill_python", "skill_sql", "skill_machine_learning", "skill_llm",
  "skill_pytorch", "skill_tableau", "skill_power_bi"
)
missing_selected <- setdiff(selected_skills, names(salary_jobs))
if (length(missing_selected) > 0) {
  stop("Selected skills missing from salary data: ",
       paste(missing_selected, collapse = ", "))
}
stopifnot(all(vapply(salary_jobs[selected_skills], is.logical, logical(1))))

skill_category_validation <- salary_jobs %>%
  select(job_id, job_category_updated, salary_midpoint_annual,
         all_of(selected_skills)) %>%
  pivot_longer(cols = all_of(selected_skills),
               names_to = "skill", values_to = "mentioned") %>%
  filter(!is.na(mentioned)) %>%
  group_by(job_category_updated, skill, mentioned) %>%
  summarise(
    job_count = n(),
    median_salary = median(salary_midpoint_annual),
    .groups = "drop"
  )
print(skill_category_validation, n = Inf)
save_csv_if_new(
  skill_category_validation,
  "data/validation_skill_category_salary.csv"
)

# ------------------------------------------------------------
# 9. FINAL VALIDATION SUMMARY
# ------------------------------------------------------------
cat("\n========== FINAL SUMMARY ==========\n")
cat("Total skill-analysis jobs:", nrow(jobs), "\n")
cat("Total salary-analysis jobs:", nrow(salary_jobs), "\n")
cat("Duplicate job IDs:", nrow(duplicate_ids), "\n")
cat("Jobs with no detected skills:", zero_skill_jobs, "\n")
cat("Invalid salary ranges:", sum(salary_check$invalid_range), "\n")
cat("Salary midpoint mismatches:", sum(salary_check$midpoint_mismatch), "\n")
cat("Posting timestamp mismatches:", date_mismatches, "\n")
cat("Posting dates:", as.character(min(as.Date(jobs$posted_at))),
    "to", as.character(max(as.Date(jobs$posted_at))), "\n")
cat("Overall median salary:",
    dollar(median(salary_jobs$salary_midpoint_annual)), "\n")
cat("\nSTEP 12 COMPLETED. Existing output files preserved where present.\n")
