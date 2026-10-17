
# ============================================================
# DATA 607 - Project 3
# Step 12C: Apply Reviewed Decisions
# ============================================================

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)

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

reviews <- read_csv(
  "data/validation_manual_review_sheet_completed.csv",
  show_col_types = FALSE
)

cat("\n========== STEP 12C ==========\n")
cat("Original skill jobs:", nrow(jobs), "\n")
cat("Original salary jobs:", nrow(salary_jobs), "\n")

# ------------------------------------------------------------
# 2. VALIDATE REVIEW DECISIONS
# ------------------------------------------------------------

stopifnot(
  all(c("job_id", "final_decision") %in% names(reviews))
)

stopifnot(
  !anyDuplicated(reviews$job_id)
)

stopifnot(
  all(reviews$final_decision %in% c("Include", "Exclude"))
)

stopifnot(
  all(reviews$job_id %in% jobs$job_id)
)

excluded_ids <- reviews %>%
  filter(final_decision == "Exclude") %>%
  pull(job_id)

cat("Reviewed exclusions:", length(excluded_ids), "\n")

# ------------------------------------------------------------
# 3. CREATE REVISED DATASETS
# ------------------------------------------------------------

jobs_revised <- jobs %>%
  filter(!job_id %in% excluded_ids)

salary_revised <- salary_jobs %>%
  filter(!job_id %in% excluded_ids)

cat("Revised skill jobs:", nrow(jobs_revised), "\n")
cat("Revised salary jobs:", nrow(salary_revised), "\n")

write_csv(
  jobs_revised,
  "data/jobs_skills_revised.csv"
)

write_csv(
  salary_revised,
  "data/jobs_salary_revised.csv"
)

# ------------------------------------------------------------
# 4. RECOMPUTE SKILL DEMAND
# ------------------------------------------------------------

skill_columns <- names(jobs_revised) %>%
  grep(
    pattern = "^skill_",
    x = .,
    value = TRUE
  )

skill_columns <- setdiff(skill_columns, "skill_count")

skill_demand_revised <- jobs_revised %>%
  select(all_of(skill_columns)) %>%
  pivot_longer(
    cols = everything(),
    names_to = "skill",
    values_to = "mentioned"
  ) %>%
  filter(mentioned == TRUE) %>%
  count(skill, name = "job_count") %>%
  mutate(
    percentage = round(
      100 * job_count / nrow(jobs_revised),
      1
    ),
    skill = sub("^skill_", "", skill)
  ) %>%
  arrange(desc(job_count))

print(skill_demand_revised, n = Inf)

write_csv(
  skill_demand_revised,
  "data/skill_demand_revised.csv"
)

# ------------------------------------------------------------
# 5. RECOMPUTE SALARY DISTRIBUTION
# ------------------------------------------------------------

salary_summary_revised <- salary_revised %>%
  summarise(
    job_count = n(),
    mean_salary = mean(
      salary_midpoint_annual,
      na.rm = TRUE
    ),
    median_salary = median(
      salary_midpoint_annual,
      na.rm = TRUE
    ),
    min_salary = min(
      salary_midpoint_annual,
      na.rm = TRUE
    ),
    max_salary = max(
      salary_midpoint_annual,
      na.rm = TRUE
    )
  )

print(salary_summary_revised)

write_csv(
  salary_summary_revised,
  "data/salary_summary_revised.csv"
)

# ------------------------------------------------------------
# 6. RECOMPUTE SALARY BY SKILL
# ------------------------------------------------------------

salary_skill_columns <- intersect(
  skill_columns,
  names(salary_revised)
)

skill_salary_revised <- salary_revised %>%
  select(
    salary_midpoint_annual,
    all_of(salary_skill_columns)
  ) %>%
  pivot_longer(
    cols = all_of(salary_skill_columns),
    names_to = "skill",
    values_to = "mentioned"
  ) %>%
  filter(mentioned == TRUE) %>%
  group_by(skill) %>%
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
  mutate(
    skill = sub("^skill_", "", skill)
  ) %>%
  arrange(desc(median_salary))

write_csv(
  skill_salary_revised,
  "data/skill_salary_revised.csv"
)

print(skill_salary_revised, n = Inf)

# ------------------------------------------------------------
# 7. RECOMPUTE SALARY BY JOB CATEGORY
# ------------------------------------------------------------

category_salary_revised <- salary_revised %>%
  group_by(job_category_updated) %>%
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

write_csv(
  category_salary_revised,
  "data/category_salary_revised.csv"
)

print(category_salary_revised, n = Inf)

# ------------------------------------------------------------
# 8. CREATE REVISED CHARTS
# ------------------------------------------------------------

skill_plot <- skill_demand_revised %>%
  slice_max(
    job_count,
    n = 15,
    with_ties = FALSE
  ) %>%
  ggplot(
    aes(
      x = reorder(skill, job_count),
      y = job_count
    )
  ) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Top 15 Skills - Revised Sample",
    x = "Technical Skill",
    y = "Job Postings"
  ) +
  theme_minimal()

ggsave(
  "data/top_15_skills_revised.png",
  skill_plot,
  width = 10,
  height = 7,
  dpi = 300
)

salary_plot <- skill_salary_revised %>%
  filter(job_count >= 10) %>%
  slice_max(
    median_salary,
    n = 15,
    with_ties = FALSE
  ) %>%
  ggplot(
    aes(
      x = reorder(skill, median_salary),
      y = median_salary
    )
  ) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  scale_y_continuous(labels = label_dollar()) +
  labs(
    title = "Median Salary by Skill - Revised Sample",
    x = "Technical Skill",
    y = "Median Salary Midpoint (USD)"
  ) +
  theme_minimal()

ggsave(
  "data/skill_salary_revised.png",
  salary_plot,
  width = 10,
  height = 7,
  dpi = 300
)

category_plot <- category_salary_revised %>%
  ggplot(
    aes(
      x = reorder(
        job_category_updated,
        median_salary
      ),
      y = median_salary
    )
  ) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  scale_y_continuous(labels = label_dollar()) +
  labs(
    title = "Median Salary by Job Category - Revised",
    x = "Job Category",
    y = "Median Salary Midpoint (USD)"
  ) +
  theme_minimal()

ggsave(
  "data/category_salary_revised.png",
  category_plot,
  width = 10,
  height = 6,
  dpi = 300
)

# ------------------------------------------------------------
# 9. FINAL COMPARISON
# ------------------------------------------------------------

comparison <- tibble(
  measure = c(
    "Skill-analysis jobs",
    "Salary-analysis jobs",
    "Median salary"
  ),
  original = c(
    nrow(jobs),
    nrow(salary_jobs),
    median(salary_jobs$salary_midpoint_annual)
  ),
  revised = c(
    nrow(jobs_revised),
    nrow(salary_revised),
    median(salary_revised$salary_midpoint_annual)
  )
)

print(comparison)

write_csv(
  comparison,
  "data/validation_original_vs_revised.csv"
)

cat("\nSTEP 12C COMPLETED.\n")
cat("Original files were not overwritten.\n")
