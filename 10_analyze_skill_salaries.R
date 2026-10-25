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

# STEP 1: Load full-market and Data Science-related job data

jobs_all <- read_csv("Data/jobs_skills_analyzed_full.csv", show_col_types = FALSE)
jobs_ds <- read_csv("Data/jobs_skills_analyzed.csv", show_col_types = FALSE)

required_columns <- c(
  "job_id", "posted_at", "salary_usd_eligible",
  "salary_min_annual", "salary_max_annual"
)

stopifnot(
  all(required_columns %in% names(jobs_all)),
  all(required_columns %in% names(jobs_ds)),
  !anyNA(jobs_all$job_id),
  !anyDuplicated(jobs_all$job_id),
  !anyNA(jobs_ds$job_id),
  !anyDuplicated(jobs_ds$job_id),
  all(jobs_ds$job_id %in% jobs_all$job_id)
)

skill_columns <- grep("^skill_", names(jobs_all), value = TRUE)
skill_columns <- setdiff(skill_columns, "skill_count")

stopifnot(
  length(skill_columns) == 30,
  all(skill_columns %in% names(jobs_ds)),
  all(vapply(jobs_all[skill_columns], is.logical, logical(1))),
  all(vapply(jobs_ds[skill_columns], is.logical, logical(1)))
)

# STEP 2: Keep eligible USD annual salary records

prepare_salaries <- function(jobs) {
  jobs %>%
    filter(
      salary_usd_eligible %in% TRUE,
      is.finite(salary_min_annual),
      is.finite(salary_max_annual),
      salary_min_annual >= 0,
      salary_min_annual <= salary_max_annual
    ) %>%
    mutate(
      salary_midpoint_annual = (salary_min_annual + salary_max_annual) / 2
    )
}

salary_all <- prepare_salaries(jobs_all)
salary_ds <- prepare_salaries(jobs_ds)

if (nrow(salary_all) == 0) {
  stop("No eligible USD annual salary records in the full dataset.")
}

print(tibble(
  dataset = c("Full Job Market", "Data Science-Related Jobs"),
  total_jobs = c(nrow(jobs_all), nrow(jobs_ds)),
  eligible_salary_jobs = c(nrow(salary_all), nrow(salary_ds)),
  missing_posting_dates = c(
    sum(is.na(jobs_all$posted_at)),
    sum(is.na(jobs_ds$posted_at))
  )
))

# STEP 3: Convert skill indicators to long format

make_salary_skills <- function(jobs) {
  jobs %>%
    select(job_id, salary_midpoint_annual, all_of(skill_columns)) %>%
    pivot_longer(
      cols = all_of(skill_columns),
      names_to = "skill",
      values_to = "mentioned"
    ) %>%
    mutate(
      skill = sub("^skill_", "", skill),
      skill = gsub("_", " ", skill),
      mentioned = coalesce(mentioned, FALSE)
    )
}

salary_skills_all <- make_salary_skills(salary_all)
salary_skills_ds <- make_salary_skills(salary_ds)

# STEP 4: Summarize salaries among jobs mentioning each skill

summarize_skill_salaries <- function(salary_skills, dataset_name) {
  salary_skills %>%
    filter(mentioned) %>%
    group_by(skill) %>%
    summarise(
      job_count = n(),
      mean_salary = round(mean(salary_midpoint_annual), 0),
      median_salary = round(median(salary_midpoint_annual), 0),
      min_salary = min(salary_midpoint_annual),
      max_salary = max(salary_midpoint_annual),
      .groups = "drop"
    ) %>%
    mutate(dataset = dataset_name) %>%
    arrange(desc(median_salary))
}

summary_all <- summarize_skill_salaries(salary_skills_all, "Full Job Market")
summary_ds <- summarize_skill_salaries(salary_skills_ds, "Data Science-Related Jobs")

print(summary_all %>% filter(job_count >= 5), n = Inf)
print(summary_ds %>% filter(job_count >= 5), n = Inf)

# STEP 5: Compare jobs with and without each skill

compare_skill_salaries <- function(salary_skills, dataset_name) {
  salary_skills %>%
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
        median_salary_mentioned_TRUE - median_salary_mentioned_FALSE,
      dataset = dataset_name
    ) %>%
    filter(
      job_count_mentioned_TRUE >= 10,
      job_count_mentioned_FALSE >= 10
    ) %>%
    arrange(desc(median_difference))
}

comparison_all <- compare_skill_salaries(salary_skills_all, "Full Job Market")
comparison_ds <- compare_skill_salaries(salary_skills_ds, "Data Science-Related Jobs")

print(comparison_all, n = Inf)
print(comparison_ds, n = Inf)

# STEP 6: Chart the top median salaries by skill

make_salary_chart <- function(summary, eligible_count, chart_title) {
  plot_data <- summary %>%
    filter(job_count >= 10) %>%
    slice_max(median_salary, n = 15, with_ties = FALSE)

  ggplot(plot_data, aes(x = reorder(skill, median_salary), y = median_salary)) +
    geom_col(fill = "steelblue") +
    coord_flip() +
    scale_y_continuous(labels = label_dollar()) +
    labs(
      title = chart_title,
      subtitle = paste("USD annual salary midpoint;", eligible_count, "eligible postings"),
      x = "Technical Skill",
      y = "Median Annual Salary (USD)",
      caption = "Skills can appear together in the same job posting."
    ) +
    theme_minimal()
}

p_all <- make_salary_chart(
  summary_all, nrow(salary_all),
  "Median Advertised Salary by Technical Skill: Full Job Market"
)

p_ds <- make_salary_chart(
  summary_ds, nrow(salary_ds),
  "Median Advertised Salary by Technical Skill: Data Science-Related Jobs"
)

print(p_all)
if (nrow(salary_ds) > 0) print(p_ds)

# STEP 7: Save outputs

write_csv(salary_all, "Data/jobs_salary_analysis_full.csv")
write_csv(summary_all, "Data/skill_salary_summary_full.csv")
write_csv(comparison_all, "Data/skill_salary_comparison_full.csv")

write_csv(salary_ds, "Data/jobs_salary_analysis.csv")
write_csv(summary_ds, "Data/skill_salary_summary.csv")
write_csv(comparison_ds, "Data/skill_salary_comparison.csv")

write_csv(bind_rows(summary_all, summary_ds), "Data/skill_salary_market_comparison.csv")

ggsave("Data/skill_salary_chart_full.png", p_all, width = 10, height = 7, dpi = 300)

if (nrow(salary_ds) > 0) {
  ggsave("Data/skill_salary_chart.png", p_ds, width = 10, height = 7, dpi = 300)
}

View(bind_rows(summary_all, summary_ds))
