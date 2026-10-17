
# =====================================================
# DATA 607 - PROJECT 3
# Dataset 1: Technical Skills Demand Analysis
# Script: 09_analyze_skills.R
# =====================================================

library(readr)
library(dplyr)
library(stringr)
library(tidyr)
library(ggplot2)

# STEP 1: Load the updated job dataset

jobs <- read_csv(
  "data/jobs_include_updated.csv",
  show_col_types = FALSE
)

# Load the reviewed validation sample
validation <- read_csv(
  "data/jobs_validation_reviewed.csv",
  show_col_types = FALSE
)

# STEP 2: Apply manual validation decisions
# Exclude only jobs marked "No".
# Jobs not in the validation sample remain provisional.

excluded_ids <- validation %>%
  filter(str_to_lower(str_trim(manual_relevant)) == "no") %>%
  pull(job_id)

jobs_final <- jobs %>%
  filter(!job_id %in% excluded_ids)

cat("Original included jobs:", nrow(jobs), "\n")
cat("Excluded after validation:", nrow(jobs) - nrow(jobs_final), "\n")
cat("Jobs retained for analysis:", nrow(jobs_final), "\n")

# STEP 3: Define technical skill patterns
# Word boundaries help avoid false substring matches.

skill_patterns <- c(
  "Python" = "\\bpython\\b",
  "SQL" = "\\bsql\\b",
  "R" = "\\bR\\b",
  "Excel" = "\\bexcel\\b",
  "Tableau" = "\\btableau\\b",
  "Power BI" = "\\bpower\\s*bi\\b",
  "Looker" = "\\blooker\\b",
  "Machine Learning" = "\\bmachine learning\\b",
  "Deep Learning" = "\\bdeep learning\\b",
  "Statistics" = "\\b(statistics|statistical analysis|statistical modeling)\\b",
  "Data Visualization" = "\\bdata visuali[sz]ation\\b",
  "ETL" = "\\betl\\b",
  "Data Pipelines" = "\\bdata pipelines?\\b",
  "Spark" = "\\b(?:apache\\s+)?spark\\b",
  "Databricks" = "\\bdatabricks\\b",
  "AWS" = "\\baws\\b|\\bamazon web services\\b",
  "Azure" = "\\bazure\\b",
  "Google Cloud" = "\\bgoogle cloud\\b|\\bgcp\\b",
  "Snowflake" = "\\bsnowflake\\b",
  "TensorFlow" = "\\btensorflow\\b",
  "PyTorch" = "\\bpytorch\\b",
  "Scikit-learn" = "\\bscikit[- ]learn\\b|\\bsklearn\\b",
  "NLP" = "\\bnlp\\b|\\bnatural language processing\\b",
  "LLM" = "\\bllms?\\b|\\blarge language models?\\b",
  "Generative AI" = "\\bgenerative ai\\b|\\bgenai\\b",
  "Docker" = "\\bdocker\\b",
  "Kubernetes" = "\\bkubernetes\\b",
  "Git" = "\\bgit\\b",
  "Airflow" = "\\bairflow\\b",
  "dbt" = "\\bdbt\\b"
)

# STEP 4: Create skill indicators
# Each job counts at most once for each skill.

for (skill in names(skill_patterns)) {
  
  column_name <- paste0(
    "skill_",
    str_replace_all(
      str_to_lower(skill),
      "[^a-z0-9]+",
      "_"
    )
  )
  
  jobs_final[[column_name]] <- str_detect(
    coalesce(jobs_final$description, ""),
    regex(
      skill_patterns[[skill]],
      ignore_case = skill != "R"
    )
  )
}


# STEP 5: Convert skill indicators to long format
# Exclude skill_count because it is numeric.

skills_long <- jobs_final %>%
  select(
    job_id,
    starts_with("skill_"),
    -skill_count
  ) %>%
  pivot_longer(
    cols = -job_id,
    names_to = "skill",
    values_to = "mentioned"
  ) %>%
  filter(mentioned == TRUE) %>%
  mutate(
    skill = str_remove(skill, "^skill_"),
    skill = str_replace_all(skill, "_", " ")
  )

cat("\nSkill matches:", nrow(skills_long), "\n")


# STEP 6: Count skill demand

skill_summary <- skills_long %>%
  count(skill, name = "job_count", sort = TRUE) %>%
  mutate(
    percentage = round(
      job_count / nrow(jobs_final) * 100,
      1
    )
  )

cat("\nTOP 20 MOST REQUESTED SKILLS:\n")

print(
  head(skill_summary, 20),
  n = 20
)

# STEP 7: Create a bar chart

top_skills <- skill_summary %>%
  slice_max(
    order_by = job_count,
    n = 15,
    with_ties = FALSE
  )

p <- ggplot(
  top_skills,
  aes(
    x = reorder(skill, job_count),
    y = job_count
  )
) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Top 15 Technical Skills in Data Science Job Postings",
    subtitle = paste(
      "Based on",
      nrow(jobs_final),
      "provisionally relevant job postings"
    ),
    x = "Technical Skill",
    y = "Number of Job Postings"
  ) +
  theme_minimal()

print(p)

# STEP 8: Save analysis files

write_csv(
  jobs_final,
  "data/jobs_skills_analyzed.csv"
)

write_csv(
  skills_long,
  "data/job_skills_long.csv"
)

write_csv(
  skill_summary,
  "data/skill_demand_summary.csv"
)

ggsave(
  filename = "data/top_15_skills.png",
  plot = p,
  width = 10,
  height = 7,
  dpi = 300
)

# STEP 9: Display final summary

cat("\n--- FINAL SUMMARY ---\n")

cat(
  "Jobs analyzed:",
  nrow(jobs_final),
  "\n"
)

cat(
  "Distinct technical skills tracked:",
  length(skill_patterns),
  "\n"
)

cat(
  "Jobs with eligible USD salaries:",
  sum(jobs_final$salary_usd_eligible %in% TRUE),
  "\n"
)

cat("\nAnalysis files saved successfully.\n")
