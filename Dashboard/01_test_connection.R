
# DATA 607 Project 3
# Step 1: Test PostgreSQL Connection

library(DBI)
library(RPostgres)

# Connect to local PostgreSQL database
con <- dbConnect(
  RPostgres::Postgres(),
  dbname = "data607_project3",
  host = "localhost",
  port = 5432,
  user = "postgres",
  password = rstudioapi::askForPassword(
    "Enter your PostgreSQL password"
  )
)

# Verify connection
print(dbGetQuery(con, "
  SELECT current_database() AS database_name;
"))

# Verify table counts
print(dbGetQuery(con, "
  SELECT
    (SELECT COUNT(*) FROM public.company) AS companies,
    (SELECT COUNT(*) FROM public.job_posting) AS jobs,
    (SELECT COUNT(*) FROM public.salary) AS salaries,
    (SELECT COUNT(*) FROM public.skill) AS skills,
    (SELECT COUNT(*) FROM public.job_skill) AS job_skills,
    (SELECT COUNT(*) FROM public.data_science_classification) AS data_science_jobs,
    (SELECT COUNT(*) FROM public.job_sector_classification) AS job_sector_classifications;
"))

# Close connection
dbDisconnect(con)

cat("PostgreSQL connection test completed successfully!\n")
