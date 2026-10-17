
library(readr)
library(dplyr)

jobs <- read_csv(
  "data/job_postings_refined_all.csv",
  show_col_types = FALSE
)

# Jobs included based on responsibilities,
# but without a core data-related job title
possible_false_positives <- jobs %>%
  filter(
    relevance_status == "Likely Relevant",
    !core_title_match
  ) %>%
  select(
    job_id,
    title,
    company,
    skill_count,
    responsibility_count,
    description
  ) %>%
  arrange(desc(responsibility_count))

# Jobs with potentially relevant titles
# that the script could not confidently classify
possible_false_negatives <- jobs %>%
  filter(relevance_status == "Needs Review") %>%
  select(
    job_id,
    title,
    company,
    skill_count,
    responsibility_count,
    description
  ) %>%
  arrange(desc(responsibility_count))

cat(
  "Possible false positives:",
  nrow(possible_false_positives), "\n"
)

cat(
  "Jobs requiring additional review:",
  nrow(possible_false_negatives), "\n"
)

# Export both review groups
write_csv(
  possible_false_positives,
  "data/possible_false_positives.csv"
)

write_csv(
  possible_false_negatives,
  "data/possible_false_negatives.csv"
)

# Display titles without lengthy descriptions
possible_false_positives %>%
  select(title, company, skill_count,
         responsibility_count) %>%
  print(n = 50)
