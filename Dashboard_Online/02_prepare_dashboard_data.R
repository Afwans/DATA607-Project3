# Run from Dashboard_Online_Updated folder, after 01_export_data.R.
required <- c('company','job_posting','salary','skill','job_skill','data_science_classification','job_sector_classification')
read_export <- function(n) {
  p <- file.path('data',paste0(n,'.csv'))
  if(!file.exists(p)) stop('Missing ',p)
  read.csv(p,stringsAsFactors=FALSE,na.strings=c('','NA'))
}
d <- setNames(lapply(required,read_export),required)
stopifnot(nrow(d$job_posting)>1000,nrow(d$data_science_classification)>200,
          !anyDuplicated(d$job_posting$job_id),!anyDuplicated(d$salary$job_id),
          !anyDuplicated(d$data_science_classification$job_id),
           !anyDuplicated(d$job_sector_classification$job_id),
          !anyDuplicated(d$job_skill[c('job_id','skill_id')]),
          setequal(d$job_posting$job_id,d$salary$job_id),
           setequal(d$job_posting$job_id,d$job_sector_classification$job_id),
          all(d$data_science_classification$job_id %in% d$job_posting$job_id),
          all(d$job_skill$job_id %in% d$job_posting$job_id),
          all(d$job_skill$skill_id %in% d$skill$skill_id))
stopifnot(all(c('sector_name','classification_method','needs_review') %in% names(d$job_sector_classification)))
stopifnot(all(!is.na(d$job_sector_classification$sector_name) & nzchar(d$job_sector_classification$sector_name)))
stopifnot(all(c('job_category_updated','classification_updated') %in% names(d$data_science_classification)))
stopifnot(all(c('salary_usd_eligible','salary_midpoint_annual') %in% names(d$salary)))
stopifnot(all(!is.na(as.Date(substr(d$job_posting$posted_at,1,10)))))
cat('Validation successful\n')
for(n in required) cat(sprintf('%s: %s rows\n',n,nrow(d[[n]])))
cat('Eligible salaries:',sum(d$salary$salary_usd_eligible %in% TRUE & !is.na(d$salary$salary_midpoint_annual)),'\n')
cat('Ready to test app.R locally and deploy.\n')
