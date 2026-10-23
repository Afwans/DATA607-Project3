# =====================================================
# DATA 607 - PROJECT 3
# Dataset 1: Validate Results
# Script: 12_validate_dataset1.R
# =====================================================

library(readr)
library(dplyr)
library(stringr)
library(tidyr)
library(ggplot2)
library(scales)

# STEP 1: Load outputs from Scripts 09 and 10

required_files <- c(
  "Data/jobs_skills_analyzed_full.csv",
  "Data/jobs_skills_analyzed.csv",
  "Data/jobs_salary_analysis_full.csv",
  "Data/jobs_salary_analysis.csv"
)

missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0) {
  stop("Missing input files: ", paste(missing_files, collapse = ", "))
}

jobs_all <- read_csv(required_files[1], show_col_types = FALSE)
jobs_ds <- read_csv(required_files[2], show_col_types = FALSE)
salary_all <- read_csv(required_files[3], show_col_types = FALSE)
salary_ds <- read_csv(required_files[4], show_col_types = FALSE)

datasets <- list(
  "Full Job Market" = jobs_all,
  "Data Science-Related Jobs" = jobs_ds,
  "Full Market Salaries" = salary_all,
  "Data Science Salaries" = salary_ds
)

# STEP 2: Validate job IDs and posting dates

required_job_columns <- c("job_id", "posted_at", "title", "company")
required_salary_columns <- c(
  "job_id", "posted_at", "salary_min_annual",
  "salary_max_annual", "salary_midpoint_annual"
)

stopifnot(
  all(required_job_columns %in% names(jobs_all)),
  all(required_job_columns %in% names(jobs_ds)),
  all(required_salary_columns %in% names(salary_all)),
  all(required_salary_columns %in% names(salary_ds)),
  "job_category_updated" %in% names(salary_ds)
)

for (dataset_name in names(datasets)) {
  data <- datasets[[dataset_name]]

  if (nrow(data) == 0) {
    stop("Dataset is empty: ", dataset_name)
  }

  stopifnot(
    !anyNA(data$job_id),
    !anyDuplicated(data$job_id),
    all(!is.na(data$posted_at))
  )
}

stopifnot(
  all(jobs_ds$job_id %in% jobs_all$job_id),
  all(salary_all$job_id %in% jobs_all$job_id),
  all(salary_ds$job_id %in% jobs_ds$job_id),
  all(salary_ds$job_id %in% salary_all$job_id)
)

dataset_summary <- bind_rows(lapply(names(datasets), function(dataset_name) {
  data <- datasets[[dataset_name]]

  tibble(
    dataset = dataset_name,
    total_jobs = nrow(data),
    unique_jobs = n_distinct(data$job_id),
    missing_dates = sum(is.na(data$posted_at)),
    earliest_date = as.Date(min(data$posted_at)),
    latest_date = as.Date(max(data$posted_at))
  )
}))

print(dataset_summary)

check_dates <- function(subset_data, reference_data) {
  joined <- subset_data %>%
    select(job_id, posted_at) %>%
    inner_join(
      reference_data %>% select(job_id, posted_at),
      by = "job_id",
      suffix = c("_subset", "_reference")
    )

  sum(
    as.character(joined$posted_at_subset) !=
      as.character(joined$posted_at_reference)
  )
}

date_validation <- tibble(
  comparison = c(
    "Data Science vs Full Market",
    "Full Salaries vs Full Market",
    "Data Science Salaries vs Data Science Jobs"
  ),
  date_mismatches = c(
    check_dates(jobs_ds, jobs_all),
    check_dates(salary_all, jobs_all),
    check_dates(salary_ds, jobs_ds)
  )
)

print(date_validation)
stopifnot(all(date_validation$date_mismatches == 0))

# STEP 3: Check possible duplicate postings

duplicate_ids <- jobs_all %>%
  count(job_id, name = "duplicate_count") %>%
  filter(duplicate_count > 1)

duplicate_title_company <- jobs_all %>%
  mutate(
    title_clean = str_squish(str_to_lower(coalesce(title, ""))),
    company_clean = str_squish(str_to_lower(coalesce(company, "")))
  ) %>%
  group_by(title_clean, company_clean) %>%
  filter(n() > 1) %>%
  ungroup()

print(tibble(
  duplicate_job_ids = nrow(duplicate_ids),
  rows_sharing_title_and_company = nrow(duplicate_title_company)
))

write_csv(duplicate_ids, "Data/validation_duplicate_ids.csv")
write_csv(duplicate_title_company, "Data/validation_duplicate_titles.csv")

# STEP 4: Validate all 30 technical skill indicators

skill_columns <- grep("^skill_", names(jobs_all), value = TRUE)
skill_columns <- setdiff(skill_columns, "skill_count")

stopifnot(
  length(skill_columns) == 30,
  all(skill_columns %in% names(jobs_ds)),
  all(skill_columns %in% names(salary_all)),
  all(skill_columns %in% names(salary_ds))
)

for (dataset_name in names(datasets)) {
  data <- datasets[[dataset_name]]
  stopifnot(
    all(vapply(data[skill_columns], is.logical, logical(1))),
    all(vapply(data[skill_columns], function(x) !anyNA(x), logical(1)))
  )
}

skill_quality <- tibble(
  skill_column = skill_columns,
  missing_values = vapply(
    jobs_all[skill_columns], function(x) sum(is.na(x)), integer(1)
  ),
  full_market_mentions = vapply(
    jobs_all[skill_columns], sum, integer(1)
  ),
  data_science_mentions = vapply(
    jobs_ds[skill_columns], sum, integer(1)
  )
)

print(skill_quality, n = Inf)
write_csv(skill_quality, "Data/validation_skill_quality.csv")

jobs_skill_check <- jobs_all %>%
  mutate(
    detected_skill_count = rowSums(
      across(all_of(skill_columns))
    )
  )

no_skill_jobs <- jobs_skill_check %>%
  filter(detected_skill_count == 0)

write_csv(no_skill_jobs, "Data/validation_jobs_no_skills.csv")

# STEP 5: Validate annual USD salary values and midpoints

validate_salaries <- function(data, dataset_name) {
  checked <- data %>%
    mutate(
      recalculated_midpoint = (salary_min_annual + salary_max_annual) / 2,
      invalid_range = !is.finite(salary_min_annual) |
        !is.finite(salary_max_annual) |
        salary_min_annual < 0 |
        salary_min_annual > salary_max_annual,
      midpoint_mismatch = !is.finite(salary_midpoint_annual) |
        abs(salary_midpoint_annual - recalculated_midpoint) > 0.01,
      salary_issue = invalid_range | midpoint_mismatch
    )

  if ("salary_usd_eligible" %in% names(checked)) {
    checked <- checked %>%
      mutate(salary_issue = salary_issue | !(salary_usd_eligible %in% TRUE))
  }

  if ("salary_currency" %in% names(checked)) {
    checked <- checked %>%
      mutate(salary_issue = salary_issue |
        is.na(salary_currency) |
        str_to_upper(str_trim(salary_currency)) != "USD")
  }

  checked %>%
    mutate(
      dataset = dataset_name,
      salary_issue = coalesce(salary_issue, TRUE)
    )
}

salary_check_all <- validate_salaries(salary_all, "Full Job Market")
salary_check_ds <- validate_salaries(salary_ds, "Data Science-Related Jobs")

salary_issues <- bind_rows(
  salary_check_all %>% filter(salary_issue),
  salary_check_ds %>% filter(salary_issue)
)

write_csv(salary_issues, "Data/validation_salary_issues.csv")

print(tibble(
  dataset = c("Full Job Market", "Data Science-Related Jobs"),
  salary_records = c(nrow(salary_all), nrow(salary_ds)),
  salary_issues = c(
    sum(salary_check_all$salary_issue),
    sum(salary_check_ds$salary_issue)
  )
))

if (nrow(salary_issues) > 0) {
  stop("Salary issues found. Review Data/validation_salary_issues.csv.")
}

# STEP 6: Salary distribution for the full job market

salary_distribution <- salary_all %>%
  summarise(
    job_count = n(),
    minimum = min(salary_midpoint_annual),
    q1 = as.numeric(quantile(salary_midpoint_annual, 0.25)),
    median = median(salary_midpoint_annual),
    mean = mean(salary_midpoint_annual),
    q3 = as.numeric(quantile(salary_midpoint_annual, 0.75)),
    maximum = max(salary_midpoint_annual),
    standard_deviation = sd(salary_midpoint_annual)
  )

print(salary_distribution)
write_csv(salary_distribution, "Data/validation_salary_distribution.csv")

salary_plot <- ggplot(salary_all, aes(x = salary_midpoint_annual)) +
  geom_histogram(bins = 25, fill = "steelblue", color = "white") +
  geom_vline(
    xintercept = median(salary_all$salary_midpoint_annual),
    linetype = "dashed"
  ) +
  scale_x_continuous(labels = label_dollar()) +
  labs(
    title = "Distribution of Advertised Salary Midpoints: Full Job Market",
    subtitle = paste(nrow(salary_all), "eligible USD job postings"),
    x = "Annual Salary Midpoint (USD)",
    y = "Number of Jobs"
  ) +
  theme_minimal()

print(salary_plot)
ggsave(
  "Data/validation_salary_distribution.png",
  plot = salary_plot, width = 10, height = 6, dpi = 300
)

# STEP 7: Salary by seniority across the full market

if ("seniority" %in% names(salary_all)) {
  seniority_salary <- salary_all %>%
    mutate(
      seniority = coalesce(as.character(seniority), "Unknown")
    ) %>%
    group_by(seniority) %>%
    summarise(
      job_count = n(),
      median_salary = median(salary_midpoint_annual),
      mean_salary = mean(salary_midpoint_annual),
      .groups = "drop"
    ) %>%
    arrange(desc(median_salary))

  print(seniority_salary, n = Inf)
  write_csv(seniority_salary, "Data/validation_seniority_salary.csv")
}

# STEP 8: Data Science category and seniority checks

if ("seniority" %in% names(salary_ds)) {
  category_seniority <- salary_ds %>%
    mutate(
      seniority = coalesce(as.character(seniority), "Unknown"),
      job_category_updated = coalesce(
        as.character(job_category_updated), "Uncategorized"
      )
    ) %>%
    group_by(job_category_updated, seniority) %>%
    summarise(
      job_count = n(),
      median_salary = median(salary_midpoint_annual),
      .groups = "drop"
    ) %>%
    arrange(job_category_updated, desc(job_count))

  print(category_seniority, n = Inf)
  write_csv(category_seniority, "Data/validation_category_seniority.csv")
}

# STEP 9: Validate selected skills within Data Science categories

selected_skills <- c(
  "skill_python", "skill_sql", "skill_machine_learning",
  "skill_llm", "skill_pytorch", "skill_tableau", "skill_power_bi"
)

stopifnot(all(selected_skills %in% names(salary_ds)))

skill_category_validation <- salary_ds %>%
  select(
    job_id, job_category_updated, salary_midpoint_annual,
    all_of(selected_skills)
  ) %>%
  pivot_longer(
    cols = all_of(selected_skills),
    names_to = "skill",
    values_to = "mentioned"
  ) %>%
  group_by(job_category_updated, skill, mentioned) %>%
  summarise(
    job_count = n(),
    median_salary = median(salary_midpoint_annual),
    .groups = "drop"
  )

print(skill_category_validation, n = Inf)
write_csv(
  skill_category_validation,
  "Data/validation_skill_category_salary.csv"
)

# STEP 10: Review validation results

View(dataset_summary)
View(skill_quality)
View(salary_distribution)
