
# =====================================================
# DATA 607 - PROJECT 3
# Step 11: Job Categories and Salary Differences
# =====================================================

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)

jobs <- read_csv(
  "data/jobs_salary_analysis.csv",
  show_col_types = FALSE
)

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
  group_by(
    job_category_updated,
    skill,
    mentioned
  ) %>%
  summarise(
    job_count = n(),
    median_salary = median(salary_midpoint_annual),
    .groups = "drop"
  ) %>%
  mutate(
    skill = sub("^skill_", "", skill)
  )

cat("\n--- SKILLS WITHIN JOB CATEGORIES ---\n")
print(category_skill_salary, n = Inf)

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
    x = "Job Category",
    y = "Median Annual Salary Midpoint (USD)"
  ) +
  theme_minimal()

print(p)

# STEP 4: Save results

write_csv(
  category_salary,
  "data/job_category_salary_summary.csv"
)

write_csv(
  category_skill_salary,
  "data/category_skill_salary_summary.csv"
)

ggsave(
  "data/job_category_salary_chart.png",
  plot = p,
  width = 10,
  height = 6,
  dpi = 300
)

cat("\nStep 11 completed successfully.\n")
