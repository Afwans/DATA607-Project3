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

# STEP 1: Load the full cleaned dataset and Data Science candidates

jobs_all <- read_csv(
  "Data/job_postings_cleaned.csv",
  show_col_types = FALSE
)

jobs_ds <- read_csv(
  "Data/jobs_include_updated.csv",
  show_col_types = FALSE
)

stopifnot(
  all(c("job_id", "description", "posted_at", "salary_usd_eligible") %in% names(jobs_all)),
  all(c("job_id", "description", "posted_at", "salary_usd_eligible") %in% names(jobs_ds)),
  !anyNA(jobs_all$job_id),
  !anyDuplicated(jobs_all$job_id),
  !anyNA(jobs_ds$job_id),
  !anyDuplicated(jobs_ds$job_id),
  all(jobs_ds$job_id %in% jobs_all$job_id)
)

# STEP 2: Apply reviewed decisions to Data Science candidates

review_path <- "Data/jobs_validation_reviewed.csv"

if (file.exists(review_path)) {
  validation <- read_csv(review_path, show_col_types = FALSE)

  stopifnot(
    all(c("job_id", "manual_relevant") %in% names(validation)),
    !anyNA(validation$job_id),
    !anyDuplicated(validation$job_id)
  )

  validation <- validation %>%
    mutate(
      manual_decision = str_to_lower(str_trim(coalesce(manual_relevant, "")))
    )

  stopifnot(all(validation$manual_decision %in% c("", "yes", "no")))

  validation %>%
    count(manual_decision, sort = TRUE) %>%
    print()

  excluded_ids <- validation %>%
    filter(manual_decision == "no") %>%
    pull(job_id)

  jobs_ds <- jobs_ds %>%
    filter(!job_id %in% excluded_ids)
}

stopifnot(nrow(jobs_ds) > 0)

# STEP 3: Review dataset sizes and posting dates

data_summary <- tibble(
  dataset = c("Full Job Market", "Data Science Candidates"),
  total_jobs = c(nrow(jobs_all), nrow(jobs_ds)),
  unique_jobs = c(n_distinct(jobs_all$job_id), n_distinct(jobs_ds$job_id)),
  missing_dates = c(sum(is.na(jobs_all$posted_at)), sum(is.na(jobs_ds$posted_at)))
)

print(data_summary)

jobs_all %>%
  summarise(
    earliest_date = if (all(is.na(posted_at))) as.Date(NA) else as.Date(min(posted_at, na.rm = TRUE)),
    latest_date = if (all(is.na(posted_at))) as.Date(NA) else as.Date(max(posted_at, na.rm = TRUE))
  ) %>%
  print()

# STEP 4: Define technical skill patterns

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

stopifnot(
  length(skill_patterns) == 30,
  !anyDuplicated(names(skill_patterns))
)

print(names(skill_patterns))

# STEP 5: Extract skill mentions from job descriptions

extract_skills <- function(jobs) {
  
  skill_matches <- lapply(seq_along(skill_patterns), function(i) {
    
    skill <- names(skill_patterns)[i]
    pattern <- unname(skill_patterns[i])
    case_insensitive <- !identical(skill, "R")
    
    tibble(
      job_id = jobs$job_id,
      skill = skill,
      mentioned = str_detect(
        coalesce(jobs$description, ""),
        regex(pattern, ignore_case = case_insensitive)
      )
    )
  })
  
  bind_rows(skill_matches) %>%
    filter(mentioned) %>%
    select(job_id, skill)
}

skills_all <- extract_skills(jobs_all)
skills_ds <- extract_skills(jobs_ds)

# Retain one indicator column per skill for downstream salary analysis
for (i in seq_along(skill_patterns)) {
  skill <- names(skill_patterns)[i]
  pattern <- skill_patterns[[i]]
  column_name <- paste0(
    "skill_",
    str_replace_all(str_to_lower(skill), "[^a-z0-9]+", "_")
  )

  jobs_all[[column_name]] <- str_detect(
    coalesce(jobs_all$description, ""),
    regex(pattern, ignore_case = skill != "R")
  )

  jobs_ds[[column_name]] <- str_detect(
    coalesce(jobs_ds$description, ""),
    regex(pattern, ignore_case = skill != "R")
  )
}

stopifnot(
  !anyDuplicated(skills_all[c("job_id", "skill")]),
  !anyDuplicated(skills_ds[c("job_id", "skill")])
)

# STEP 6: Summarize skill demand for each population

summarize_skills <- function(skills, jobs, population) {
  tibble(skill = names(skill_patterns)) %>%
    left_join(
      skills %>% count(skill, name = "job_count"),
      by = "skill"
    ) %>%
    mutate(
      job_count = coalesce(job_count, 0L),
      percentage = round(100 * job_count / nrow(jobs), 1),
      population = population,
      total_jobs = nrow(jobs)
    ) %>%
    arrange(desc(job_count), skill)
}

skill_summary_all <- summarize_skills(skills_all, jobs_all, "Full Job Market")
skill_summary_ds <- summarize_skills(skills_ds, jobs_ds, "Data Science Candidates")
skill_comparison <- bind_rows(skill_summary_all, skill_summary_ds)

print(head(skill_summary_all, 20), n = 20)
print(head(skill_summary_ds, 20), n = 20)

# STEP 7: Visualize the top skills in the full job market

top_skills_all <- skill_summary_all %>%
  slice_max(job_count, n = 15, with_ties = FALSE)

p_all <- ggplot(
  top_skills_all,
  aes(x = reorder(skill, job_count), y = job_count)
) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Top 15 Technical Skills Mentioned Across All Job Postings",
    subtitle = paste("Based on", nrow(jobs_all), "cleaned job postings"),
    x = "Technical Skill",
    y = "Number of Job Postings"
  ) +
  theme_minimal()

print(p_all)

# STEP 8: Visualize the top skills among Data Science candidates

top_skills_ds <- skill_summary_ds %>%
  slice_max(job_count, n = 15, with_ties = FALSE)

p_ds <- ggplot(
  top_skills_ds,
  aes(x = reorder(skill, job_count), y = job_count)
) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Top 15 Technical Skills in Data Science-Related Job Postings",
    subtitle = paste("Based on", nrow(jobs_ds), "provisionally relevant jobs"),
    x = "Technical Skill",
    y = "Number of Job Postings"
  ) +
  theme_minimal()

print(p_ds)

# STEP 9: Export full-market results and Data Science comparison

write_csv(jobs_all, "Data/jobs_skills_analyzed_full.csv")
write_csv(skills_all, "Data/job_skills_long_full.csv")
write_csv(skill_summary_all, "Data/skill_demand_summary_full.csv")
write_csv(skill_comparison, "Data/skill_demand_comparison.csv")

# Retain the established output names for downstream Data Science scripts
write_csv(jobs_ds, "Data/jobs_skills_analyzed.csv")
write_csv(
  skills_ds %>%
    mutate(
      skill = str_replace_all(str_to_lower(skill), "[^a-z0-9]+", " ")
    ),
  "Data/job_skills_long.csv"
)
write_csv(
  skill_summary_ds %>% select(skill, job_count, percentage),
  "Data/skill_demand_summary.csv"
)

ggsave(
  "Data/top_15_skills_full.png",
  plot = p_all,
  width = 10,
  height = 7,
  dpi = 300
)

ggsave(
  "Data/top_15_skills.png",
  plot = p_ds,
  width = 10,
  height = 7,
  dpi = 300
)

View(skill_comparison)
