
# DATA 607 - Project 3
# Step 1: Load Dataset 1
# Job Postings with Salaries

# Load required packages
library(readr)
library(dplyr)

# Import the dataset
jobs <- read_csv(
  "data/job_postings_with_salaries.csv",
  show_col_types = FALSE
)

# Check number of rows and columns
dim(jobs)

# Display column names
names(jobs)

# Preview the first six records
head(jobs)

# -----------------------------------------
# Step 2: Explore Dataset 1
# -----------------------------------------

# Display dataset dimensions
dim(jobs)

# Display column names
names(jobs)

# Examine column types
glimpse(jobs)

# Check missing values in each column
missing_values <- colSums(is.na(jobs))

# Display missing values
sort(missing_values, decreasing = TRUE)

# Check completely duplicated rows
sum(duplicated(jobs))

# View dataset in RStudio
View(jobs)


# -----------------------------------------
# Step 3: Explore Salary Information
# -----------------------------------------

# Count postings by salary currency
jobs %>%
  count(salary_currency, sort = TRUE)

# Count postings by salary period
jobs %>%
  count(salary_period, sort = TRUE)

# Summary of annual salary columns
summary(jobs$salary_min_annual)
summary(jobs$salary_max_annual)

# Check records where minimum salary exceeds maximum
jobs %>%
  filter(
    !is.na(salary_min_annual),
    !is.na(salary_max_annual),
    salary_min_annual > salary_max_annual
  ) %>%
  select(
    job_id, title, salary_currency,
    salary_min_annual, salary_max_annual
  )

# Check records with missing annual salaries
jobs %>%
  filter(
    is.na(salary_min_annual) |
      is.na(salary_max_annual)
  ) %>%
  select(
    job_id, title, salary_currency,
    salary_min_annual, salary_max_annual
  )


# Step 3: Explore salary information

# Count each currency
jobs %>%
  count(salary_currency, sort = TRUE)

# Check salary periods
jobs %>%
  count(salary_period, sort = TRUE)

# Summary of USD annual salaries
jobs %>%
  filter(salary_currency == "USD") %>%
  summarise(
    total_jobs = n(),
    min_salary = min(salary_min_annual, na.rm = TRUE),
    average_min_salary = mean(salary_min_annual, na.rm = TRUE),
    average_max_salary = mean(salary_max_annual, na.rm = TRUE),
    max_salary = max(salary_max_annual, na.rm = TRUE)
  )

# Count invalid salary ranges
jobs %>%
  filter(
    !is.na(salary_min_annual),
    !is.na(salary_max_annual),
    salary_min_annual > salary_max_annual
  ) %>%
  count()


# -----------------------------------------
# Step 4: Investigate Unusual Salaries
# -----------------------------------------

# Examine USD jobs with annual minimum below $30,000
low_salary_jobs <- jobs %>%
  filter(
    salary_currency == "USD",
    salary_min_annual < 30000
  ) %>%
  select(
    job_id, title, company, salary_period,
    salary_min, salary_max,
    salary_min_annual, salary_max_annual
  ) %>%
  arrange(salary_min_annual)

print(low_salary_jobs, n = 20)

# Examine USD jobs with annual maximum above $400,000
high_salary_jobs <- jobs %>%
  filter(
    salary_currency == "USD",
    salary_max_annual > 400000
  ) %>%
  select(
    job_id, title, company, salary_period,
    salary_min, salary_max,
    salary_min_annual, salary_max_annual
  ) %>%
  arrange(desc(salary_max_annual))

print(high_salary_jobs, n = 20)

# Count low and high salary records
cat("Low salary records:", nrow(low_salary_jobs), "\n")
cat("High salary records:", nrow(high_salary_jobs), "\n")
