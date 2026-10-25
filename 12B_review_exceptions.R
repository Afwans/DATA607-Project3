# DATA 607 - Project 3
# Script 12B: Review Classification and Skill Exceptions

library(readr)
library(dplyr)
library(stringr)
library(tidyr)

required <- c('Data/jobs_skills_analyzed.csv',
              'Data/validation_jobs_no_skills.csv',
              'Data/validation_duplicate_titles.csv')
missing <- required[!file.exists(required)]
if (length(missing)) stop('Run Script 12 first. Missing: ', paste(missing, collapse = ', '))

jobs <- read_csv(required[1], show_col_types = FALSE)
zero_skill_all <- read_csv(required[2], show_col_types = FALSE)
duplicates_all <- read_csv(required[3], show_col_types = FALSE)
stopifnot(all(c('job_id','title','company') %in% names(jobs)),
          !anyNA(jobs$job_id), !anyDuplicated(jobs$job_id))

# Script 12's exception files cover the full market. Manual classification
# decisions below apply only to the Data Science-related subgroup.
zero_skill_ds <- zero_skill_all %>% semi_join(jobs, by = 'job_id')
duplicates_ds <- duplicates_all %>% semi_join(jobs, by = 'job_id')

review_sheet <- zero_skill_ds %>%
  mutate(
    proposed_decision = case_when(
      str_detect(str_to_lower(coalesce(title, '')),
                 'sensor technician|testing and qualification|gtm|go.to.market') ~
        'Review for exclusion',
      TRUE ~ 'Review for inclusion'
    ),
    final_decision = NA_character_,
    missed_skills = NA_character_,
    reviewer_notes = NA_character_
  ) %>%
  select(any_of(c('job_id','title','company','job_category_updated','description',
                  'proposed_decision','final_decision','missed_skills','reviewer_notes')))

review_path <- 'Data/validation_manual_review_sheet.csv'
if (!file.exists(review_path)) {
  write_csv(review_sheet, review_path)
} else {
  message('Preserving existing manual review sheet: ', review_path)
}

duplicate_review <- duplicates_ds %>%
  mutate(proposed_decision = 'Keep - verify separate posting',
         final_decision = NA_character_, reviewer_notes = NA_character_)
dup_path <- 'Data/validation_duplicate_review_sheet.csv'
if (!file.exists(dup_path)) {
  write_csv(duplicate_review, dup_path)
} else {
  message('Preserving existing duplicate review sheet: ', dup_path)
}

summary <- tibble(
  review_type = c('Zero skills - full market', 'Zero skills - DS subgroup',
                  'Repeated title/company - full market',
                  'Repeated title/company - DS subgroup'),
  records = c(nrow(zero_skill_all), nrow(zero_skill_ds),
              nrow(duplicates_all), nrow(duplicates_ds))
)
print(summary)
write_csv(summary, 'Data/validation_exception_summary_updated.csv')
View(review_sheet)
View(duplicate_review)
# Complete final_decision as Include or Exclude for every review row,
# then save a COPY named Data/validation_manual_review_sheet_completed.csv.
