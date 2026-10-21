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

# STEP 0: Confirm required input files exist

required_files <- c(
  "data/jobs_include_updated.csv",
  "data/jobs_validation_reviewed.csv"
)

missing_files <- required_files[!file.exists(required_files)]

if (length(missing_files) > 0) {
  stop("Required input files missing: ", paste(missing_files, collapse = ", "))
}

# STEP 1: Load the updated included jobs and manually reviewed validation file

jobs <- read_csv("data/jobs_include_updated.csv", show_col_types = FALSE)
validation <- read_csv("data/jobs_validation_reviewed.csv", show_col_types = FALSE)

stopifnot(
  all(c("job_id", "description", "posted_at", "salary_usd_eligible") %in% names(jobs)),
  all(c("job_id", "manual_relevant") %in% names(validation))
)

stopifnot(
  !anyNA(jobs$job_id),
  n_distinct(jobs$job_id) == nrow(jobs),
  !anyNA(validation$job_id),
  n_distinct(validation$job_id) == nrow(validation)
)

# STEP 1A: Validate posting dates

cat("\n--- POSTING DATE VALIDATION ---\n")

jobs %>%
  summarise(
    total_jobs = n(),
    valid_dates = sum(!is.na(posted_at)),
    missing_dates = sum(is.na(posted_at)),
    earliest_date = if (all(is.na(posted_at))) as.Date(NA) else as.Date(min(posted_at, na.rm = TRUE)),
    latest_date = if (all(is.na(posted_at))) as.Date(NA) else as.Date(max(posted_at, na.rm = TRUE))
  ) %>%
  print()

stopifnot(all(!is.na(jobs$posted_at)))

# STEP 1B: Inspect manual validation decisions BEFORE applying exclusions

cat("\n--- MANUAL VALIDATION DECISIONS ---\n")

validation <- validation %>%
  mutate(
    manual_decision = str_to_lower(str_trim(coalesce(manual_relevant, "")))
  )

# Do not silently treat unexpected nonblank decisions as unreviewed.
unexpected_decisions <- validation %>%
  filter(!manual_decision %in% c("", "yes", "no"))

if (nrow(unexpected_decisions) > 0) {
  stop("Unexpected manual_relevant values found. Use Yes, No, or blank.")
}

validation %>%
  mutate(
    decision = case_when(
      manual_decision == "yes" ~ "Yes",
      manual_decision == "no" ~ "No",
      TRUE ~ "Not reviewed"
    )
  ) %>%
  count(decision, sort = TRUE) %>%
  print()

# STEP 2: Apply manual validation decisions
# Exclude only jobs marked "No"; unreviewed jobs remain provisional.

excluded_ids <- validation %>%
  filter(manual_decision == "no") %>%
  pull(job_id)

cat(
  "\nRejected validation IDs found in included jobs:",
  sum(excluded_ids %in% jobs$job_id),
  "\n"
)

jobs_final <- jobs %>%
  filter(!job_id %in% excluded_ids)

cat("Original included jobs:", nrow(jobs), "\n")
cat("Excluded after validation:", nrow(jobs) - nrow(jobs_final), "\n")
cat("Jobs retained for analysis:", nrow(jobs_final), "\n")

if (nrow(jobs_final) == 0) {
  stop("No jobs remain after manual validation.")
}

stopifnot(
  n_distinct(jobs_final$job_id) == nrow(jobs_final),
  all(!is.na(jobs_final$posted_at))
)

cat("\nJob IDs and posting dates validated.\n")

# STEP 3: Define technical skill patterns

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

# STEP 4: Create one TRUE/FALSE indicator per skill per job

for (skill in names(skill_patterns)) {
  column_name <- paste0(
    "skill_",
    str_replace_all(str_to_lower(skill), "[^a-z0-9]+", "_")
  )
  
  jobs_final[[column_name]] <- str_detect(
    coalesce(jobs_final$description, ""),
    regex(skill_patterns[[skill]], ignore_case = skill != "R")
  )
}

stopifnot(
  "posted_at" %in% names(jobs_final),
  all(!is.na(jobs_final$posted_at)),
  n_distinct(jobs_final$job_id) == nrow(jobs_final)
)

# STEP 5: Convert skill indicators to long format
# Explicitly select only the 30 newly created skill columns.

skill_columns <- paste0(
  "skill_",
  str_replace_all(str_to_lower(names(skill_patterns)), "[^a-z0-9]+", "_")
)

skills_long <- jobs_final %>%
  select(job_id, all_of(skill_columns)) %>%
  pivot_longer(
    cols = all_of(skill_columns),
    names_to = "skill",
    values_to = "mentioned"
  ) %>%
  filter(mentioned) %>%
  mutate(
    skill = str_remove(skill, "^skill_"),
    skill = str_replace_all(skill, "_", " ")
  )

cat("\nSkill matches:", nrow(skills_long), "\n")

# STEP 6: Count skill demand

skill_summary <- skills_long %>%
  count(skill, name = "job_count", sort = TRUE) %>%
  mutate(
    percentage = round(job_count / nrow(jobs_final) * 100, 1)
  )

cat("\nTOP 20 MOST MENTIONED SKILLS:\n")
print(head(skill_summary, 20), n = 20)

# STEP 7: Create a bar chart

top_skills <- skill_summary %>%
  slice_max(order_by = job_count, n = 15, with_ties = FALSE)

p <- ggplot(
  top_skills,
  aes(x = reorder(skill, job_count), y = job_count)
) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Top 15 Technical Skills Mentioned in Data-Related Job Postings",
    subtitle = paste("Based on", nrow(jobs_final), "provisionally relevant job postings"),
    x = "Technical Skill",
    y = "Number of Job Postings"
  ) +
  theme_minimal()

print(p)

# STEP 8: Save outputs WITHOUT overwriting existing files

save_csv_if_new <- function(data, path) {
  if (!file.exists(path)) {
    write_csv(data, path)
    cat("Created:", path, "\n")
  } else {
    cat("Preserved existing file:", path, "\n")
  }
}

save_csv_if_new(jobs_final, "data/jobs_skills_analyzed.csv")
save_csv_if_new(skills_long, "data/job_skills_long.csv")
save_csv_if_new(skill_summary, "data/skill_demand_summary.csv")

chart_path <- "data/top_15_skills.png"

if (!file.exists(chart_path)) {
  ggsave(filename = chart_path, plot = p, width = 10, height = 7, dpi = 300)
  cat("Created:", chart_path, "\n")
} else {
  cat("Preserved existing chart:", chart_path, "\n")
}

# STEP 9: Final summary

cat("\n--- FINAL SUMMARY ---\n")
cat("Jobs analyzed:", nrow(jobs_final), "\n")
cat("Distinct technical skills tracked:", length(skill_patterns), "\n")
cat("Jobs with eligible USD salaries:",
    sum(jobs_final$salary_usd_eligible %in% TRUE), "\n")
cat("Posting dates:", as.character(min(as.Date(jobs_final$posted_at))),
    "to", as.character(max(as.Date(jobs_final$posted_at))), "\n")
cat("\nScript 09 completed.\n")
cat("Existing output files were preserved where present.\n")
