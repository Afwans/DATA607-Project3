# DATA 607 - Project 3
# Script 12C: Apply Reviewed Decisions

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)

required <- c('Data/jobs_skills_analyzed_full.csv',
              'Data/jobs_skills_analyzed.csv',
              'Data/jobs_salary_analysis_full.csv',
              'Data/jobs_salary_analysis.csv',
              'Data/validation_manual_review_sheet_completed.csv')
missing <- required[!file.exists(required)]
if (length(missing)) stop('Missing files: ', paste(missing, collapse = ', '))

jobs_all <- read_csv(required[1], show_col_types = FALSE)
jobs_ds <- read_csv(required[2], show_col_types = FALSE)
salary_all <- read_csv(required[3], show_col_types = FALSE)
salary_ds <- read_csv(required[4], show_col_types = FALSE)
reviews <- read_csv(required[5], show_col_types = FALSE)

stopifnot(all(c('job_id','final_decision') %in% names(reviews)),
          !anyNA(reviews$job_id), !anyDuplicated(reviews$job_id),
          !anyNA(jobs_ds$job_id), !anyDuplicated(jobs_ds$job_id),
          all(jobs_ds$job_id %in% jobs_all$job_id),
          all(reviews$job_id %in% jobs_ds$job_id),
          all(!is.na(reviews$final_decision)),
          all(reviews$final_decision %in% c('Include','Exclude')))

excluded_ids <- reviews %>% filter(final_decision == 'Exclude') %>% pull(job_id)
jobs_revised <- jobs_ds %>% filter(!job_id %in% excluded_ids)
salary_revised <- salary_ds %>% filter(job_id %in% jobs_revised$job_id)

# Preserve full-market datasets and original subgroup datasets.
write_csv(jobs_revised, 'Data/jobs_skills_revised.csv')
write_csv(salary_revised, 'Data/jobs_salary_revised.csv')

skill_columns <- grep('^skill_', names(jobs_revised), value = TRUE)
skill_columns <- setdiff(skill_columns, 'skill_count')
if (!length(skill_columns)) stop('No skill indicator columns found.')

skill_demand <- jobs_revised %>%
  select(all_of(skill_columns)) %>%
  pivot_longer(everything(), names_to = 'skill', values_to = 'mentioned') %>%
  filter(mentioned %in% TRUE) %>%
  count(skill, name = 'job_count') %>%
  mutate(percentage = round(100 * job_count / nrow(jobs_revised), 1),
         skill = sub('^skill_', '', skill)) %>%
  arrange(desc(job_count))
write_csv(skill_demand, 'Data/skill_demand_revised.csv')

valid_salary <- salary_revised %>%
  filter(salary_usd_eligible %in% TRUE, is.finite(salary_midpoint_annual))

salary_summary <- valid_salary %>%
  summarise(job_count = n(),
            mean_salary = if (n()) mean(salary_midpoint_annual) else NA_real_,
            median_salary = if (n()) median(salary_midpoint_annual) else NA_real_,
            min_salary = if (n()) min(salary_midpoint_annual) else NA_real_,
            max_salary = if (n()) max(salary_midpoint_annual) else NA_real_)
write_csv(salary_summary, 'Data/salary_summary_revised.csv')

salary_skill_columns <- intersect(skill_columns, names(valid_salary))
skill_salary <- valid_salary %>%
  select(salary_midpoint_annual, all_of(salary_skill_columns)) %>%
  pivot_longer(all_of(salary_skill_columns), names_to = 'skill', values_to = 'mentioned') %>%
  filter(mentioned %in% TRUE) %>%
  group_by(skill) %>%
  summarise(job_count = n(), median_salary = median(salary_midpoint_annual),
            mean_salary = mean(salary_midpoint_annual), .groups = 'drop') %>%
  mutate(skill = sub('^skill_', '', skill)) %>%
  arrange(desc(median_salary))
write_csv(skill_salary, 'Data/skill_salary_revised.csv')

category_salary <- valid_salary %>%
  group_by(job_category_updated) %>%
  summarise(job_count = n(), median_salary = median(salary_midpoint_annual),
            mean_salary = mean(salary_midpoint_annual), .groups = 'drop') %>%
  arrange(desc(median_salary))
write_csv(category_salary, 'Data/category_salary_revised.csv')

if (nrow(skill_demand)) {
  p <- skill_demand %>% slice_max(job_count, n = 15, with_ties = FALSE) %>%
    ggplot(aes(reorder(skill, job_count), job_count)) +
    geom_col(fill = 'steelblue') + coord_flip() + theme_minimal() +
    labs(title = 'Top 15 Skills - Reviewed Data Science-Related Jobs',
         x = 'Technical Skill', y = 'Job Postings')
  ggsave('Data/top_15_skills_revised.png', p, width = 10, height = 7, dpi = 300)
}
if (nrow(skill_salary)) {
  p <- skill_salary %>% filter(job_count >= 10) %>%
    slice_max(median_salary, n = 15, with_ties = FALSE) %>%
    ggplot(aes(reorder(skill, median_salary), median_salary)) +
    geom_col(fill = 'steelblue') + coord_flip() +
    scale_y_continuous(labels = label_dollar()) + theme_minimal() +
    labs(title = 'Median Salary by Skill - Reviewed Data Science-Related Jobs',
         x = 'Technical Skill', y = 'Median Annual Salary Midpoint (USD)')
  ggsave('Data/skill_salary_revised.png', p, width = 10, height = 7, dpi = 300)
}
if (nrow(category_salary)) {
  p <- ggplot(category_salary,
              aes(reorder(job_category_updated, median_salary), median_salary)) +
    geom_col(fill = 'steelblue') + coord_flip() +
    scale_y_continuous(labels = label_dollar()) + theme_minimal() +
    labs(title = 'Median Salary by Category - Reviewed Data Science-Related Jobs',
         x = 'Job Category', y = 'Median Annual Salary Midpoint (USD)')
  ggsave('Data/category_salary_revised.png', p, width = 10, height = 6, dpi = 300)
}

comparison <- tibble(
  measure = c('Full-market skill jobs (unchanged)', 'Data Science skill jobs',
              'Data Science eligible salary jobs', 'Data Science median salary'),
  original = c(nrow(jobs_all), nrow(jobs_ds),
               sum(salary_ds$salary_usd_eligible %in% TRUE &
                   is.finite(salary_ds$salary_midpoint_annual)),
               median(salary_ds$salary_midpoint_annual[
                 salary_ds$salary_usd_eligible %in% TRUE &
                 is.finite(salary_ds$salary_midpoint_annual)], na.rm = TRUE)),
  revised = c(nrow(jobs_all), nrow(jobs_revised), nrow(valid_salary),
              if (nrow(valid_salary)) median(valid_salary$salary_midpoint_annual) else NA_real_)
)
write_csv(comparison, 'Data/validation_original_vs_revised.csv')
print(comparison)
View(comparison)
# Run Script 13 after reviewing these outputs.
