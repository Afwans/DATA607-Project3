
# =====================================================
# DATA 607 - PROJECT 3
# Dataset 1: Skills vs. Salary Analysis
# Script: 10_analyze_skill_salaries.R
# =====================================================

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)

# STEP 1: Load skill analysis dataset

jobs <- read_csv(
  "data/jobs_skills_analyzed.csv",
  show_col_types = FALSE
)

# STEP 1A: Validate input data and posting dates

cat("\n--- INPUT DATA VALIDATION ---\n")

required_columns <- c(
  "job_id",
  "posted_at",
  "job_category_updated",
  "salary_usd_eligible",
  "salary_min_annual",
  "salary_max_annual"
)

stopifnot(all(required_columns %in% names(jobs)))

stopifnot(
  !anyNA(jobs$job_id),
  n_distinct(jobs$job_id) == nrow(jobs)
)

jobs %>%
  summarise(
    total_jobs = n(),
    valid_dates = sum(!is.na(posted_at)),
    missing_dates = sum(is.na(posted_at)),
    earliest_date = if (all(is.na(posted_at))) {
      as.Date(NA)
    } else {
      as.Date(min(posted_at, na.rm = TRUE))
    },
    latest_date = if (all(is.na(posted_at))) {
      as.Date(NA)
    } else {
      as.Date(max(posted_at, na.rm = TRUE))
    }
  ) %>%
  print()

stopifnot(all(!is.na(jobs$posted_at)))

# STEP 2: Keep eligible USD salary records

salary_jobs <- jobs %>%
  filter(
    salary_usd_eligible %in% TRUE,
    !is.na(salary_min_annual),
    !is.na(salary_max_annual),
    salary_min_annual <= salary_max_annual
  ) %>%
  mutate(
    salary_midpoint_annual =
      (salary_min_annual + salary_max_annual) / 2
  )

cat(
  "Jobs with eligible USD salaries:",
  nrow(salary_jobs), "\n"
)

# STEP 2A: Validate salary analysis records

if (nrow(salary_jobs) == 0) {
  stop("No eligible USD salary records available.")
}

stopifnot(
  all(is.finite(salary_jobs$salary_midpoint_annual)),
  all(salary_jobs$salary_midpoint_annual >= 0),
  all(!is.na(salary_jobs$posted_at))
)

cat("\n--- SALARY DATA VALIDATION ---\n")

cat("Total jobs loaded:", nrow(jobs), "\n")
cat("Salary-eligible jobs:", nrow(salary_jobs), "\n")

cat(
  "Median annual salary midpoint:",
  dollar(median(salary_jobs$salary_midpoint_annual)),
  "\n"
)

# STEP 3: Identify the 30 technical skill columns
# Exclude the original numeric skill_count column.

skill_columns <- names(salary_jobs)[
  startsWith(names(salary_jobs), "skill_") &
    names(salary_jobs) != "skill_count"
]

# STEP 3A: Validate skill indicators

cat("\n--- SKILL COLUMN VALIDATION ---\n")

cat("Skill columns detected:", length(skill_columns), "\n")

if (length(skill_columns) != 30) {
  stop(
    "Expected 30 technical skill columns, but found ",
    length(skill_columns)
  )
}

stopifnot(
  all(vapply(
    salary_jobs[skill_columns],
    is.logical,
    logical(1)
  ))
)

stopifnot(
  all(vapply(
    salary_jobs[skill_columns],
    function(x) !anyNA(x),
    logical(1)
  ))
)

cat("All 30 skill indicators validated.\n")

# STEP 4: Convert skill indicators to long format
# Keep both TRUE and FALSE for salary comparisons.

salary_skills_long <- salary_jobs %>%
  select(
    job_id,
    job_category_updated,
    salary_midpoint_annual,
    all_of(skill_columns)
  ) %>%
  pivot_longer(
    cols = all_of(skill_columns),
    names_to = "skill",
    values_to = "mentioned"
  ) %>%
  mutate(
    skill = sub("^skill_", "", skill),
    skill = gsub("_", " ", skill)
  )

# STEP 5: Calculate salary statistics for each skill

skill_salary_summary <- salary_skills_long %>%
  filter(mentioned == TRUE) %>%
  group_by(skill) %>%
  summarise(
    job_count = n(),
    mean_salary = round(
      mean(salary_midpoint_annual), 0
    ),
    median_salary = round(
      median(salary_midpoint_annual), 0
    ),
    min_salary = min(salary_midpoint_annual),
    max_salary = max(salary_midpoint_annual),
    .groups = "drop"
  ) %>%
  arrange(desc(median_salary))

cat("\n--- SALARY BY SKILL ---\n")

skill_salary_summary %>%
  filter(job_count >= 5) %>%
  print(n = Inf)

# STEP 6: Compare salaries with and without skills

skill_comparison <- salary_skills_long %>%
  group_by(skill, mentioned) %>%
  summarise(
    job_count = n(),
    median_salary = median(salary_midpoint_annual),
    .groups = "drop"
  ) %>%
  pivot_wider(
    names_from = mentioned,
    values_from = c(job_count, median_salary),
    names_prefix = "mentioned_"
  ) %>%
  mutate(
    median_difference =
      median_salary_mentioned_TRUE -
      median_salary_mentioned_FALSE
  ) %>%
  filter(
    job_count_mentioned_TRUE >= 10,
    job_count_mentioned_FALSE >= 10
  ) %>%
  arrange(desc(median_difference))

cat("\n--- SALARY COMPARISON ---\n")

print(skill_comparison, n = Inf)

# STEP 7: Create a salary chart
# Only display skills with at least 10 salary records.

plot_data <- skill_salary_summary %>%
  filter(job_count >= 10) %>%
  slice_max(
    order_by = median_salary,
    n = 15,
    with_ties = FALSE
  )

p <- ggplot(
  plot_data,
  aes(
    x = reorder(skill, median_salary),
    y = median_salary
  )
) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  scale_y_continuous(
    labels = label_dollar()
  ) +
  labs(
    title = "Median Advertised Salary by Technical Skill",
    subtitle = paste(
      "USD annual salary midpoint;",
      nrow(salary_jobs),
      "eligible postings"
    ),
    x = "Technical Skill",
    y = "Median Annual Salary (USD)",
    caption = "Skills are not mutually exclusive."
  ) +
  theme_minimal()

print(p)

# STEP 8: Save results

# STEP 8: Save results safely

save_csv_if_new <- function(data, path) {
  
  if (!file.exists(path)) {
    
    write_csv(data, path)
    
    cat("Created:", path, "\n")
    
  } else {
    
    cat("Preserved existing file:", path, "\n")
    
  }
}

save_csv_if_new(
  salary_jobs,
  "data/jobs_salary_analysis.csv"
)

save_csv_if_new(
  skill_salary_summary,
  "data/skill_salary_summary.csv"
)

save_csv_if_new(
  skill_comparison,
  "data/skill_salary_comparison.csv"
)

chart_path <- "data/skill_salary_chart.png"

if (!file.exists(chart_path)) {
  
  ggsave(
    filename = chart_path,
    plot = p,
    width = 10,
    height = 7,
    dpi = 300
  )
  
  cat("Created:", chart_path, "\n")
  
} else {
  
  cat("Preserved existing chart:", chart_path, "\n")
  
}

# STEP 9: Final summary

cat("\n--- FINAL SUMMARY ---\n")

cat("Total jobs analyzed:", nrow(jobs), "\n")

cat(
  "USD salary-eligible jobs:",
  nrow(salary_jobs), "\n"
)

cat(
  "Overall median advertised salary:",
  dollar(median(salary_jobs$salary_midpoint_annual)),
  "\n"
)

cat("\nScript 10 completed.\n")
cat("Existing output files were preserved where present.\n")
