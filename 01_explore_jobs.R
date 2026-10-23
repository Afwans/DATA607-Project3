# DATA 607 - Project 3
# 01: Explore the full job-postings dataset
# Exploratory analysis only: the source CSV is not changed.

library(readr)
library(dplyr)
library(ggplot2)

# -----------------------------------------
# Step 1: Load Dataset 1
# -----------------------------------------

data_path <- file.path("Data", "job_postings_with_salaries.csv")

if (!file.exists(data_path)) {
  stop("Dataset not found: ", data_path)
}

jobs <- readr::read_csv(
  data_path,
  show_col_types = FALSE
)

required_columns <- c(
  "job_id", "title", "company", "location", "salary_currency",
  "salary_period", "salary_min_annual", "salary_max_annual", "posted_at"
)
missing_columns <- setdiff(required_columns, names(jobs))
if (length(missing_columns) > 0) {
  stop("Missing required columns: ", paste(missing_columns, collapse = ", "))
}

cat("\nDATASET DIMENSIONS\n")
print(dim(jobs))
print(names(jobs))
glimpse(jobs)
print(head(jobs))

# -----------------------------------------
# Step 2: Explore Dataset 1
# -----------------------------------------

missing_values <- tibble(
  column = names(jobs),
  missing_count = vapply(jobs, function(x) sum(is.na(x)), integer(1))
) %>%
  mutate(missing_percent = round(100 * missing_count / nrow(jobs), 2)) %>%
  arrange(desc(missing_count))

cat("\nMISSING VALUES\n")
print(missing_values, n = Inf)

# Duplicate rows and duplicate IDs are different issues.
duplicate_rows <- sum(duplicated(jobs))
duplicate_ids <- jobs %>%
  filter(!is.na(job_id)) %>%
  count(job_id, name = "occurrences") %>%
  filter(occurrences > 1) %>%
  arrange(desc(occurrences))

market_overview <- jobs %>%
  summarise(
    total_rows = n(),
    distinct_job_ids = n_distinct(job_id, na.rm = TRUE),
    missing_job_ids = sum(is.na(job_id)),
    distinct_companies = n_distinct(company, na.rm = TRUE),
    distinct_titles = n_distinct(title, na.rm = TRUE),
    distinct_locations = n_distinct(location, na.rm = TRUE)
  )
cat("\nFULL MARKET OVERVIEW\n")
print(market_overview)
cat("Completely duplicated rows:", duplicate_rows, "\n")
cat("Job IDs appearing more than once:", nrow(duplicate_ids), "\n")
print(head(duplicate_ids, 20))

cat("\nTOP EMPLOYERS\n")
print(jobs %>% count(company, sort = TRUE) %>% slice_head(n = 15))
cat("\nTOP JOB TITLES\n")
print(jobs %>% count(title, sort = TRUE) %>% slice_head(n = 15))
cat("\nTOP LOCATIONS\n")
print(jobs %>% count(location, sort = TRUE) %>% slice_head(n = 15))

# View dataset in RStudio
View(jobs)

# -----------------------------------------
# Step 3: Explore Salary Information
# -----------------------------------------

cat("\nSALARY CURRENCIES\n")
print(jobs %>% count(salary_currency, sort = TRUE), n = Inf)
cat("\nSALARY PERIODS\n")
print(jobs %>% count(salary_period, sort = TRUE), n = Inf)

# Annual salary fields remain in their original currencies.
# Do not combine amounts across currencies.
safe_min <- function(x) if (all(is.na(x))) NA_real_ else min(x, na.rm = TRUE)
safe_max <- function(x) if (all(is.na(x))) NA_real_ else max(x, na.rm = TRUE)
safe_mean <- function(x) if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)

salary_by_currency <- jobs %>%
  group_by(salary_currency) %>%
  summarise(
    total_jobs = n(),
    jobs_with_both_annual_bounds = sum(
      is.finite(salary_min_annual) & is.finite(salary_max_annual)
    ),
    average_annual_min = safe_mean(salary_min_annual),
    average_annual_max = safe_mean(salary_max_annual),
    .groups = "drop"
  ) %>%
  arrange(desc(total_jobs))
cat("\nSALARY SUMMARY BY CURRENCY (NO FX CONVERSION)\n")
print(salary_by_currency, n = Inf)

invalid_salary_ranges <- jobs %>%
  filter(
    is.finite(salary_min_annual),
    is.finite(salary_max_annual),
    salary_min_annual > salary_max_annual
  ) %>%
  select(job_id, title, salary_currency, salary_min_annual, salary_max_annual)
cat("\nINVALID ANNUAL SALARY RANGES:", nrow(invalid_salary_ranges), "\n")
print(head(invalid_salary_ranges, 20))

missing_annual_salaries <- jobs %>%
  filter(!is.finite(salary_min_annual) | !is.finite(salary_max_annual))
cat("JOBS MISSING ONE OR BOTH ANNUAL SALARY BOUNDS:",
    nrow(missing_annual_salaries), "\n")

# USD-only salary summary, using complete valid ranges.
usd_salary_jobs <- jobs %>%
  filter(
    salary_currency == "USD",
    is.finite(salary_min_annual),
    is.finite(salary_max_annual),
    salary_min_annual >= 0,
    salary_max_annual >= salary_min_annual
  )
cat("\nVALID USD ANNUAL SALARY SUMMARY\n")
print(usd_salary_jobs %>% summarise(
  jobs_with_valid_usd_ranges = n(),
  lowest_annual_min = safe_min(salary_min_annual),
  average_annual_min = safe_mean(salary_min_annual),
  average_annual_max = safe_mean(salary_max_annual),
  highest_annual_max = safe_max(salary_max_annual)
))

# -----------------------------------------
# Step 4: Investigate Unusual Salaries
# -----------------------------------------

# These thresholds are exploratory review flags, not deletion rules.
low_salary_jobs <- usd_salary_jobs %>%
  filter(salary_min_annual < 30000) %>%
  select(job_id, title, company, salary_period,
         salary_min, salary_max, salary_min_annual, salary_max_annual) %>%
  arrange(salary_min_annual)

high_salary_jobs <- usd_salary_jobs %>%
  filter(salary_max_annual > 400000) %>%
  select(job_id, title, company, salary_period,
         salary_min, salary_max, salary_min_annual, salary_max_annual) %>%
  arrange(desc(salary_max_annual))

cat("\nUSD SALARY REVIEW FLAGS\n")
cat("Below $30,000 annual minimum:", nrow(low_salary_jobs), "\n")
print(head(low_salary_jobs, 20))
cat("Above $400,000 annual maximum:", nrow(high_salary_jobs), "\n")
print(head(high_salary_jobs, 20))

# -----------------------------------------
# Step 5: Explore Job Posting Dates
# -----------------------------------------

cat("\nPOSTING DATE COLUMN CLASS\n")
print(class(jobs$posted_at))

# Use the date component without changing the original timestamp.
# This avoids machine-local timezone shifts when the field is timestamp text.
jobs_date_analysis <- jobs %>%
  mutate(posted_date = as.Date(substr(as.character(posted_at), 1, 10)))

valid_dates <- jobs_date_analysis$posted_date[!is.na(jobs_date_analysis$posted_date)]
date_overview <- jobs_date_analysis %>%
  summarise(
    total_jobs = n(),
    jobs_with_dates = sum(!is.na(posted_date)),
    missing_dates = sum(is.na(posted_date)),
    distinct_posting_days = n_distinct(posted_date, na.rm = TRUE)
  )
date_overview$earliest_date <- if (length(valid_dates)) min(valid_dates) else as.Date(NA)
date_overview$latest_date <- if (length(valid_dates)) max(valid_dates) else as.Date(NA)
cat("\nPOSTING DATE OVERVIEW\n")
print(date_overview)

daily_postings <- jobs_date_analysis %>%
  filter(!is.na(posted_date)) %>%
  count(posted_date, name = "total_jobs") %>%
  arrange(posted_date)
cat("\nDAILY POSTING COUNTS\n")
print(daily_postings, n = Inf)

cat("\nBUSIEST POSTING DAY\n")
print(daily_postings %>% arrange(desc(total_jobs)) %>% slice_head(n = 1))

cat("\nPOSTINGS BY DAY OF WEEK\n")
print(jobs_date_analysis %>%
  filter(!is.na(posted_date)) %>%
  mutate(day_of_week = weekdays(posted_date)) %>%
  count(day_of_week, sort = TRUE))

if (nrow(daily_postings) > 0) {
  daily_plot <- ggplot(daily_postings, aes(x = posted_date, y = total_jobs)) +
    geom_col(fill = "#2874A6") +
    scale_x_date(date_labels = "%b %d", date_breaks = "1 week") +
    labs(
      title = "Daily Job Posting Activity — Full Dataset",
      subtitle = paste(format(nrow(jobs), big.mark = ","), "job records"),
      x = "Date Posted", y = "Number of Job Postings"
    ) +
    theme_minimal(base_size = 12) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  print(daily_plot)
}
