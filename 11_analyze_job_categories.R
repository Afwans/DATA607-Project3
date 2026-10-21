# =====================================================
# DATA 607 - PROJECT 3
# Dataset 1: Job Categories and Salary Differences
# Script: 11_analyze_category_salaries.R
# =====================================================

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)

# STEP 0: Confirm the input file exists
input_path <- "data/jobs_salary_analysis.csv"

if (!file.exists(input_path)) {
  stop("Required input file not found: ", input_path)
}

jobs <- read_csv(input_path, show_col_types = FALSE)

# STEP 0A: Validate input data and posting dates
cat("\n--- INPUT DATA VALIDATION ---\n")

required_columns <- c(
  "job_id",
  "posted_at",
  "job_category_updated",
  "salary_midpoint_annual"
)

missing_columns <- setdiff(required_columns, names(jobs))
if (length(missing_columns) > 0) {
  stop("Missing required columns: ", paste(missing_columns, collapse = ", "))
}

if (nrow(jobs) == 0) {
  stop("No salary records available for category analysis.")
}

stopifnot(
  !anyNA(jobs$job_id),
  n_distinct(jobs$job_id) == nrow(jobs),
  all(!is.na(jobs$posted_at)),
  all(is.finite(jobs$salary_midpoint_annual)),
  all(jobs$salary_midpoint_annual >= 0),
  all(!is.na(jobs$job_category_updated)),
  all(nzchar(trimws(jobs$job_category_updated)))
)

jobs %>%
  summarise(
    total_jobs = n(),
    valid_dates = sum(!is.na(posted_at)),
    missing_dates = sum(is.na(posted_at)),
    earliest_date = as.Date(min(posted_at)),
    latest_date = as.Date(max(posted_at))
  ) %>%
  print()

cat("Input validation passed.\n")
cat("Note: This script reads the existing saved CSV, which may differ from\n")
cat("results calculated in memory in Script 10.\n")

# STEP 1: Salary by job category
category_salary <- jobs %>%
  group_by(job_category_updated) %>%
  summarise(
    job_count = n(),
    median_salary = median(salary_midpoint_annual),
    mean_salary = mean(salary_midpoint_annual),
    .groups = "drop"
  ) %>%
  arrange(desc(median_salary))

cat("\n--- SALARY BY JOB CATEGORY ---\n")
print(category_salary, n = Inf)

# STEP 1A: Verify category totals
cat("\n--- CATEGORY VALIDATION ---\n")
cat("Total salary jobs:", nrow(jobs), "\n")
cat("Jobs across categories:", sum(category_salary$job_count), "\n")
stopifnot(sum(category_salary$job_count) == nrow(jobs))
cat("Category totals validated.\n")

# STEP 2: Compare skill salaries within categories
skills_to_compare <- c(
  "skill_python",
  "skill_sql",
  "skill_machine_learning",
  "skill_llm",
  "skill_pytorch",
  "skill_excel",
  "skill_tableau"
)

# STEP 2A: Validate selected skill indicators
cat("\n--- SKILL COLUMN VALIDATION ---\n")

missing_skills <- setdiff(skills_to_compare, names(jobs))
if (length(missing_skills) > 0) {
  stop("Missing skill columns: ", paste(missing_skills, collapse = ", "))
}

stopifnot(
  all(vapply(jobs[skills_to_compare], is.logical, logical(1))),
  all(vapply(jobs[skills_to_compare], function(x) !anyNA(x), logical(1)))
)

cat("All 7 selected skill indicators validated.\n")

category_skill_salary <- jobs %>%
  select(
    job_id,
    job_category_updated,
    salary_midpoint_annual,
    all_of(skills_to_compare)
  ) %>%
  pivot_longer(
    cols = all_of(skills_to_compare),
    names_to = "skill",
    values_to = "mentioned"
  ) %>%
  group_by(job_category_updated, skill, mentioned) %>%
  summarise(
    job_count = n(),
    median_salary = median(salary_midpoint_annual),
    .groups = "drop"
  ) %>%
  mutate(skill = sub("^skill_", "", skill))

cat("\n--- SKILLS WITHIN JOB CATEGORIES ---\n")
print(category_skill_salary, n = Inf)
cat("Note: Small category/skill groups may have unstable median salaries.\n")

# STEP 3: Plot salary by job category
p <- ggplot(
  category_salary,
  aes(
    x = reorder(job_category_updated, median_salary),
    y = median_salary
  )
) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  scale_y_continuous(labels = label_dollar()) +
  labs(
    title = "Median Advertised Salary by Job Category",
    subtitle = paste(nrow(jobs), "USD salary-eligible job postings"),
    x = "Job Category",
    y = "Median Annual Salary Midpoint (USD)",
    caption = "Salary midpoints are based on advertised ranges, not actual pay."
  ) +
  theme_minimal()

print(p)

# STEP 4: Save results without overwriting existing files
save_csv_if_new <- function(data, path) {
  if (!file.exists(path)) {
    write_csv(data, path)
    cat("Created:", path, "\n")
  } else {
    cat("Preserved existing file:", path, "\n")
  }
}

save_csv_if_new(category_salary, "data/job_category_salary_summary.csv")
save_csv_if_new(category_skill_salary, "data/category_skill_salary_summary.csv")

chart_path <- "data/job_category_salary_chart.png"

if (!file.exists(chart_path)) {
  ggsave(
    filename = chart_path,
    plot = p,
    width = 10,
    height = 6,
    dpi = 300
  )
  cat("Created:", chart_path, "\n")
} else {
  cat("Preserved existing chart:", chart_path, "\n")
}

# STEP 5: Final summary
cat("\n--- FINAL SUMMARY ---\n")
cat("Total USD salary-eligible jobs:", nrow(jobs), "\n")
cat("Job categories:", nrow(category_salary), "\n")
cat("Skills compared within categories:", length(skills_to_compare), "\n")
cat("Posting dates:", as.character(min(as.Date(jobs$posted_at))),
    "to", as.character(max(as.Date(jobs$posted_at))), "\n")
cat("Overall median annual salary midpoint:",
    dollar(median(jobs$salary_midpoint_annual)), "\n")
cat("\nScript 11 completed.\n")
cat("Existing output files were preserved where present.\n")
