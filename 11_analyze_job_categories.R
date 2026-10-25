# =====================================================
# DATA 607 - PROJECT 3
# Dataset 1: Job Categories and Salary Differences
# Script: 11_analyze_job_categories.R
# =====================================================

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)

# STEP 1: Load salary-eligible jobs from Script 10

jobs_all <- read_csv("Data/jobs_salary_analysis_full.csv", show_col_types = FALSE)
jobs_ds <- read_csv("Data/jobs_salary_analysis.csv", show_col_types = FALSE)

required_columns <- c("job_id", "posted_at", "salary_midpoint_annual")

stopifnot(
  all(required_columns %in% names(jobs_all)),
  all(c(required_columns, "job_category_updated") %in% names(jobs_ds)),
  !anyNA(jobs_all$job_id),
  !anyDuplicated(jobs_all$job_id),
  !anyNA(jobs_ds$job_id),
  !anyDuplicated(jobs_ds$job_id),
  all(jobs_ds$job_id %in% jobs_all$job_id),
  all(is.finite(jobs_all$salary_midpoint_annual)),
  all(is.finite(jobs_ds$salary_midpoint_annual))
)

if (nrow(jobs_all) == 0 || nrow(jobs_ds) == 0) {
  stop("Salary-eligible records are needed for both datasets.")
}

print(tibble(
  dataset = c("Full Job Market", "Data Science-Related Jobs"),
  salary_eligible_jobs = c(
    nrow(jobs_all),
    nrow(jobs_ds)
  ),
  missing_dates = c(
    sum(is.na(jobs_all$posted_at)),
    sum(is.na(jobs_ds$posted_at))
  )
))

# STEP 2: Compare overall salaries across both populations

market_salary_summary <- bind_rows(
  jobs_all %>% mutate(dataset = "Full Job Market"),
  jobs_ds %>% mutate(dataset = "Data Science-Related Jobs")
) %>%
  group_by(dataset) %>%
  summarise(
    job_count = n(),
    median_salary = median(salary_midpoint_annual),
    mean_salary = mean(salary_midpoint_annual),
    .groups = "drop"
  )

print(market_salary_summary)

# STEP 3: Salary differences across Data Science-related job categories

jobs_ds <- jobs_ds %>%
  mutate(
    job_category_updated = if_else(
      is.na(job_category_updated) | trimws(job_category_updated) == "",
      "Uncategorized",
      job_category_updated
    )
  )

category_salary <- jobs_ds %>%
  group_by(job_category_updated) %>%
  summarise(
    job_count = n(),
    median_salary = median(salary_midpoint_annual),
    mean_salary = mean(salary_midpoint_annual),
    .groups = "drop"
  ) %>%
  arrange(desc(median_salary))

stopifnot(sum(category_salary$job_count) == nrow(jobs_ds))
print(category_salary, n = Inf)

# STEP 4: Compare seven technical skills within categories

skills_to_compare <- c(
  "skill_python",
  "skill_sql",
  "skill_machine_learning",
  "skill_llm",
  "skill_pytorch",
  "skill_excel",
  "skill_tableau"
)

stopifnot(
  all(skills_to_compare %in% names(jobs_ds)),
  all(vapply(jobs_ds[skills_to_compare], is.logical, logical(1)))
)

category_skill_salary <- jobs_ds %>%
  select(
    job_id, job_category_updated, salary_midpoint_annual,
    all_of(skills_to_compare)
  ) %>%
  pivot_longer(
    cols = all_of(skills_to_compare),
    names_to = "skill",
    values_to = "mentioned"
  ) %>%
  mutate(
    skill = gsub("_", " ", sub("^skill_", "", skill)),
    mentioned = coalesce(mentioned, FALSE)
  ) %>%
  group_by(job_category_updated, skill, mentioned) %>%
  summarise(
    job_count = n(),
    median_salary = median(salary_midpoint_annual),
    .groups = "drop"
  )

print(category_skill_salary, n = Inf)

# STEP 5: Use existing full-market category information if available

market_category_candidates <- c(
  "job_category", "category", "department", "industry"
)

market_category_column <- market_category_candidates[
  market_category_candidates %in% names(jobs_all)
][1]

if (!is.na(market_category_column)) {
  market_category_salary <- jobs_all %>%
    mutate(
      market_category = as.character(.data[[market_category_column]]),
      market_category = if_else(
        is.na(market_category) | trimws(market_category) == "",
        "Uncategorized", market_category
      )
    ) %>%
    group_by(market_category) %>%
    summarise(
      job_count = n(),
      median_salary = median(salary_midpoint_annual),
      mean_salary = mean(salary_midpoint_annual),
      .groups = "drop"
    ) %>%
    arrange(desc(job_count))

  write_csv(market_category_salary, "Data/job_category_salary_summary_full.csv")
  print(head(market_category_salary, 20), n = 20)
} else {
  message("No full-market category column found; overall market salary comparison is available.")
}

# STEP 6: Plot Data Science-related category salaries

p <- ggplot(
  category_salary,
  aes(x = reorder(job_category_updated, median_salary), y = median_salary)
) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  scale_y_continuous(labels = label_dollar()) +
  labs(
    title = "Median Advertised Salary by Data Science-Related Job Category",
    subtitle = paste(nrow(jobs_ds), "USD salary-eligible job postings"),
    x = "Job Category",
    y = "Median Annual Salary Midpoint (USD)",
    caption = "Salary midpoints use advertised ranges, not actual pay."
  ) +
  theme_minimal()

print(p)

# STEP 7: Save summaries and chart

write_csv(market_salary_summary, "Data/market_salary_summary.csv")
write_csv(category_salary, "Data/job_category_salary_summary.csv")
write_csv(category_skill_salary, "Data/category_skill_salary_summary.csv")

ggsave(
  "Data/job_category_salary_chart.png",
  plot = p,
  width = 10,
  height = 6,
  dpi = 300
)

View(category_salary)
