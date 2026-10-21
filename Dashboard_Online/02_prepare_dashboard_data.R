# DATA 607 Project 3 - Safe online dashboard preparation (updated copy)
# Run from DATA607-Project3 project root. Never overwrite existing CSVs.
library(dplyr)
folder <- 'Dashboard_Online/data'
if (!dir.exists(folder)) stop('Run from DATA607-Project3 project root; missing Dashboard_Online/data.')
read_table <- function(name) {
  path <- file.path(folder,paste0(name,'.csv'))
  if (!file.exists(path)) stop('Missing ',path,'; run export script first.')
  read.csv(path,stringsAsFactors=FALSE,na.strings=c('','NA'))
}
safe_write <- function(data,name) {
  path <- file.path(folder,paste0(name,'.csv'))
  if (file.exists(path)) {
    cat('PRESERVED existing:',path,'\n')
    return(invisible(FALSE))
  }
  write.csv(data,path,row.names=FALSE,na='')
  cat('CREATED:',path,'-',nrow(data),'rows\n')
  invisible(TRUE)
}
jobs <- read_table('job_posting')
salaries <- read_table('salary')
skills <- read_table('skill')
job_skills <- read_table('job_skill')
if (anyDuplicated(jobs$job_id) || anyDuplicated(salaries$job_id) || anyNA(jobs$posted_at)) stop('Source CSV has duplicate IDs or missing posting dates.')
if (!setequal(jobs$job_id,salaries$job_id)) stop('Job and salary CSV job IDs differ.')
if (!all(job_skills$job_id %in% jobs$job_id) || !all(job_skills$skill_id %in% skills$skill_id)) stop('Invalid job-skill references.')
posting_date <- as.Date(substr(jobs$posted_at,1,10),format='%Y-%m-%d')
if (anyNA(posting_date)) stop('Could not parse posted_at in job_posting.csv.')
# Check known final snapshot totals before writing anything new.
expected_jobs <- 226L
expected_skills <- 30L
expected_links <- 1142L
if (nrow(jobs)!=expected_jobs || nrow(skills)!=expected_skills || nrow(job_skills)!=expected_links) stop('Source snapshots do not match verified 226 jobs / 30 skills / 1142 job-skill links. No files created.')
expected_daily <- c('2026-10-05'=43,'2026-10-06'=62,'2026-10-07'=50,'2026-10-08'=34,'2026-10-09'=33,'2026-10-10'=3,'2026-10-11'=1)
actual_daily <- table(as.character(posting_date))
if (!identical(as.integer(actual_daily[names(expected_daily)]),as.integer(expected_daily)) || length(actual_daily)!=length(expected_daily)) stop('Posting-date counts do not match verified PostgreSQL results. No files created.')
# Prevent a mixed-version dashboard: check existing overview if present.
overview_path <- file.path(folder,'overview.csv')
if (file.exists(overview_path)) {
  old_overview <- read.csv(overview_path)
  if (nrow(old_overview)!=1 || old_overview$total_jobs[1]!=nrow(jobs) || old_overview$total_skills[1]!=nrow(skills)) stop('Existing overview.csv does not match source snapshots. Resolve manually; nothing overwritten.')
}
eligible_salaries <- salaries %>% filter(salary_usd_eligible %in% TRUE,!is.na(salary_midpoint_annual))
if (!nrow(eligible_salaries)) stop('No eligible salaries found.')
overview <- data.frame(total_jobs=nrow(jobs),salary_jobs=nrow(eligible_salaries),total_skills=nrow(skills),median_salary=median(eligible_salaries$salary_midpoint_annual))
skill_demand <- job_skills %>% inner_join(skills %>% select(skill_id,skill_name),by='skill_id') %>% inner_join(jobs %>% select(job_id,job_category_updated),by='job_id') %>% group_by(job_category_updated,skill_name) %>% summarise(job_count=n_distinct(job_id),.groups='drop')
category_salary <- jobs %>% select(job_id,job_category_updated) %>% left_join(salaries %>% select(job_id,salary_usd_eligible,salary_midpoint_annual),by='job_id') %>% group_by(job_category_updated) %>% summarise(total_jobs=n(),median_salary={v <- salary_midpoint_annual[salary_usd_eligible %in% TRUE & !is.na(salary_midpoint_annual)]; if(length(v)) median(v) else NA_real_},.groups='drop')
posting_dates <- jobs %>% mutate(posting_date=posting_date) %>% group_by(posting_date,job_category_updated) %>% summarise(job_count=n(),.groups='drop') %>% arrange(posting_date,job_category_updated)
stopifnot(sum(posting_dates$job_count)==nrow(jobs))
# Verify existing summary snapshots before preserving them, to avoid silent inconsistency.
for (name in c('skill_demand','category_salary')) {
  path <- file.path(folder,paste0(name,'.csv'))
  if (file.exists(path)) {
    existing <- read.csv(path,stringsAsFactors=FALSE)
    current <- get(name)
    if (!isTRUE(all.equal(existing,current,check.attributes=FALSE))) {
      stop('Existing ',name,'.csv differs from recalculated data. Preserve it; review versions manually before generating new date data.')
    }
  }
}
# Check existing date snapshot as well if present.
date_path <- file.path(folder,'posting_dates.csv')
if (file.exists(date_path)) {
  existing_dates <- read.csv(date_path,stringsAsFactors=FALSE)
  if (!isTRUE(all.equal(existing_dates,transform(posting_dates,posting_date=as.character(posting_date)),check.attributes=FALSE))) stop('Existing posting_dates.csv differs. Preserved; investigate manually.')
}
safe_write(overview,'overview')
safe_write(skill_demand,'skill_demand')
safe_write(category_salary,'category_salary')
safe_write(posting_dates,'posting_dates')
cat('Dashboard snapshots checked. Total jobs:',nrow(jobs),' | Date rows:',nrow(posting_dates),'\n')
