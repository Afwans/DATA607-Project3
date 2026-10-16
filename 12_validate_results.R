
# ============================================================
# DATA 607 - Project 3
# Step 12: Validate Dataset 1 Results
# ============================================================

library(readr)
library(dplyr)
library(stringr)
library(tidyr)
library(ggplot2)
library(scales)

dir.create("data", showWarnings = FALSE)

# ------------------------------------------------------------
# 1. LOAD DATA
# ------------------------------------------------------------

jobs <- read_csv(
  "data/jobs_skills_analyzed.csv",
  show_col_types = FALSE
)

salary_jobs <- read_csv(
  "data/jobs_salary_analysis.csv",
  show_col_types = FALSE
)

cat("\n========== DATASET OVERVIEW ==========\n")
cat("Skill-analysis jobs:", nrow(jobs), "\n")
cat("Salary-analysis jobs:", nrow(salary_jobs), "\n")

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

cat(
  "Rows sharing title and company:",
  nrow(duplicate_title_company), "\n"
)

write_csv(
  duplicate_ids,
  "data/validation_duplicate_ids.csv"
)

write_csv(
  duplicate_title_company,
  "data/validation_duplicate_titles.csv"
)

# ------------------------------------------------------------
# 3. CHECK SKILL INDICATORS
# ------------------------------------------------------------

cat("\n========== SKILL VALIDATION ==========\n")

skill_columns <- names(jobs) %>%
  str_subset("^skill_")

# Exclude the original numeric screening column.
skill_columns <- setdiff(skill_columns, "skill_count")

skill_quality <- tibble(
  skill_column = skill_columns,
  data_type = vapply(
    jobs[skill_columns],
    function(x) class(x)[1],
    character(1)
  ),
  missing_values = vapply(
    jobs[skill_columns],
    function(x) sum(is.na(x)),
    integer(1)
  ),
  true_count = vapply(
    jobs[skill_columns],
    function(x) sum(x == TRUE, na.rm = TRUE),
    integer(1)
  )
)

print(skill_quality, n = Inf)

write_csv(
  skill_quality,
  "data/validation_skill_quality.csv"
)

# Check whether every job has at least one detected skill.
jobs_skill_check <- jobs %>%
  mutate(
    detected_skill_count = rowSums(
      across(all_of(skill_columns), ~ .x == TRUE),
      na.rm = TRUE
    )
  )

cat(
  "\nJobs with zero detected skills:",
  sum(jobs_skill_check$detected_skill_count == 0),
  "\n"
)

write_csv(
  jobs_skill_check %>%
    filter(detected_skill_count == 0),
  "data/validation_jobs_no_skills.csv"
)

# ------------------------------------------------------------
# 4. VERIFY SALARY VALUES
# ------------------------------------------------------------

cat("\n========== SALARY VALIDATION ==========\n")

salary_check <- salary_jobs %>%
  mutate(
    recalculated_midpoint =
      (salary_min_annual + salary_max_annual) / 2,
    
    midpoint_difference =
      salary_midpoint_annual - recalculated_midpoint,
    
    invalid_range =
      salary_min_annual > salary_max_annual,
    
    midpoint_mismatch =
      abs(midpoint_difference) > 0.01
  )

cat(
  "Invalid salary ranges:",
  sum(salary_check$invalid_range, na.rm = TRUE),
  "\n"
)

cat(
  "Midpoint mismatches:",
  sum(salary_check$midpoint_mismatch, na.rm = TRUE),
  "\n"
)

cat(
  "Non-USD salary records:",
  sum(salary_check$salary_currency != "USD", na.rm = TRUE),
  "\n"
)

write_csv(
  salary_check %>%
    filter(
      invalid_range |
        midpoint_mismatch |
        is.na(salary_min_annual) |
        is.na(salary_max_annual) |
        is.na(salary_midpoint_annual) |
        is.na(salary_currency) |
        salary_currency != "USD"
    ),
  "data/validation_salary_issues.csv"
)

# ------------------------------------------------------------
# 5. SALARY DISTRIBUTION
# ------------------------------------------------------------

cat("\n========== SALARY DISTRIBUTION ==========\n")

salary_distribution <- salary_jobs %>%
  summarise(
    n = n(),
    minimum = min(salary_midpoint_annual, na.rm = TRUE),
    q1 = quantile(salary_midpoint_annual, 0.25, na.rm = TRUE),
    median = median(salary_midpoint_annual, na.rm = TRUE),
    mean = mean(salary_midpoint_annual, na.rm = TRUE),
    q3 = quantile(salary_midpoint_annual, 0.75, na.rm = TRUE),
    maximum = max(salary_midpoint_annual, na.rm = TRUE),
    standard_deviation =
      sd(salary_midpoint_annual, na.rm = TRUE)
  )

print(salary_distribution)

write_csv(
  salary_distribution,
  "data/validation_salary_distribution.csv"
)

salary_plot <- ggplot(
  salary_jobs,
  aes(x = salary_midpoint_annual)
) +
  geom_histogram(
    bins = 25,
    fill = "steelblue",
    color = "white"
  ) +
  geom_vline(
    xintercept = median(
      salary_jobs$salary_midpoint_annual,
      na.rm = TRUE
    ),
    linetype = "dashed",
    linewidth = 1
  ) +
  scale_x_continuous(labels = label_dollar()) +
  labs(
    title = "Distribution of Advertised Salary Midpoints",
    subtitle = "Eligible USD job postings",
    x = "Annual Salary Midpoint",
    y = "Number of Jobs"
  ) +
  theme_minimal()

print(salary_plot)

ggsave(
  "data/validation_salary_distribution.png",
  salary_plot,
  width = 10,
  height = 6,
  dpi = 300
)

# ------------------------------------------------------------
# 6. SALARY BY SENIORITY
# ------------------------------------------------------------

cat("\n========== SALARY BY SENIORITY ==========\n")

seniority_salary <- salary_jobs %>%
  mutate(
    seniority = coalesce(
      as.character(seniority),
      "Unknown"
    )
  ) %>%
  group_by(seniority) %>%
  summarise(
    job_count = n(),
    median_salary = median(
      salary_midpoint_annual,
      na.rm = TRUE
    ),
    mean_salary = mean(
      salary_midpoint_annual,
      na.rm = TRUE
    ),
    .groups = "drop"
  ) %>%
  arrange(desc(median_salary))

print(seniority_salary, n = Inf)

write_csv(
  seniority_salary,
  "data/validation_seniority_salary.csv"
)

# ------------------------------------------------------------
# 7. SALARY BY JOB CATEGORY AND SENIORITY
# ------------------------------------------------------------

cat("\n========== CATEGORY + SENIORITY ==========\n")

category_seniority <- salary_jobs %>%
  mutate(
    seniority = coalesce(
      as.character(seniority),
      "Unknown"
    )
  ) %>%
  group_by(job_category_updated, seniority) %>%
  summarise(
    job_count = n(),
    median_salary = median(
      salary_midpoint_annual,
      na.rm = TRUE
    ),
    .groups = "drop"
  ) %>%
  arrange(job_category_updated, desc(job_count))

print(category_seniority, n = Inf)

write_csv(
  category_seniority,
  "data/validation_category_seniority.csv"
)

# ------------------------------------------------------------
# 8. RECHECK SELECTED SKILL-SALARY ASSOCIATIONS
# ------------------------------------------------------------

cat("\n========== WITHIN-CATEGORY SKILL COMPARISON ==========\n")

selected_skills <- intersect(
  c(
    "skill_python",
    "skill_sql",
    "skill_machine_learning",
    "skill_llm",
    "skill_pytorch",
    "skill_tableau",
    "skill_power_bi"
  ),
  names(salary_jobs)
)

skill_category_validation <- salary_jobs %>%
  select(
    job_id,
    job_category_updated,
    salary_midpoint_annual,
    all_of(selected_skills)
  ) %>%
  pivot_longer(
    cols = all_of(selected_skills),
    names_to = "skill",
    values_to = "mentioned"
  ) %>%
  filter(!is.na(mentioned)) %>%
  group_by(
    job_category_updated,
    skill,
    mentioned
  ) %>%
  summarise(
    job_count = n(),
    median_salary = median(
      salary_midpoint_annual,
      na.rm = TRUE
    ),
    .groups = "drop"
  )

print(skill_category_validation, n = Inf)

write_csv(
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
cat(
  "Jobs with no detected skills:",
  sum(jobs_skill_check$detected_skill_count == 0),
  "\n"
)
cat(
  "Invalid salary ranges:",
  sum(salary_check$invalid_range, na.rm = TRUE),
  "\n"
)
cat(
  "Salary midpoint mismatches:",
  sum(salary_check$midpoint_mismatch, na.rm = TRUE),
  "\n"
)
cat(
  "Overall median salary:",
  dollar(median(
    salary_jobs$salary_midpoint_annual,
    na.rm = TRUE
  )),
  "\n"
)

cat("\nSTEP 12 COMPLETED.\n")
