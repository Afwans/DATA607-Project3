
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

# STEP 3: Identify the 30 technical skill columns
# Exclude the original numeric skill_count column.

skill_columns <- names(salary_jobs)[
  startsWith(names(salary_jobs), "skill_") &
    names(salary_jobs) != "skill_count"
]

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

write_csv(
  salary_jobs,
  "data/jobs_salary_analysis.csv"
)

write_csv(
  skill_salary_summary,
  "data/skill_salary_summary.csv"
)

write_csv(
  skill_comparison,
  "data/skill_salary_comparison.csv"
)

ggsave(
  "data/skill_salary_chart.png",
  plot = p,
  width = 10,
  height = 7,
  dpi = 300
)

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

cat("\nSalary analysis completed successfully.\n")
