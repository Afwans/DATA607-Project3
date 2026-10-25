# Run on YOUR computer, from the Dashboard_Online_Updated folder.
library(DBI)
library(RPostgres)
library(rstudioapi)
if (!dir.exists('data')) dir.create('data')
con <- dbConnect(RPostgres::Postgres(), dbname='data607_project3',
                 host='localhost',port=5432,user='postgres',
                 password=rstudioapi::askForPassword('Enter your PostgreSQL password'))
tables <- c('company','job_posting','salary','skill','job_skill','data_science_classification','job_sector_classification')
# Read and validate all tables before replacing any CSVs.
exports <- tryCatch(setNames(lapply(tables,function(n) dbReadTable(con,Id(schema='public',table=n))),tables), finally=dbDisconnect(con))
stopifnot(nrow(exports$job_posting)>1000,nrow(exports$data_science_classification)>200,
          nrow(exports$skill)>0,nrow(exports$job_skill)>0,
           nrow(exports$job_sector_classification)==nrow(exports$job_posting))
stopifnot(!anyDuplicated(exports$job_posting$job_id),
          !anyDuplicated(exports$data_science_classification$job_id),
           !anyDuplicated(exports$job_sector_classification$job_id),
           setequal(exports$job_sector_classification$job_id,exports$job_posting$job_id),
          all(exports$data_science_classification$job_id %in% exports$job_posting$job_id))
# Backup existing CSV files in a timestamped folder before updating.
old <- list.files('data',pattern='\\.csv$',full.names=TRUE)
if(length(old)) {
  backup <- file.path('data_backups',format(Sys.time(),'%Y%m%d_%H%M%S'))
  dir.create(backup,recursive=TRUE,showWarnings=FALSE)
  if(!all(file.copy(old,backup,overwrite=FALSE))) stop('Backup failed; CSV files were not replaced.')
  cat('Backed up existing CSVs to:',backup,'\n')
}
for(n in tables) {
  write.csv(exports[[n]],file.path('data',paste0(n,'.csv')),row.names=FALSE,na='')
  cat(n,':',nrow(exports[[n]]),'rows\n')
}
cat('Export complete. Run 02_prepare_dashboard_data.R next.\n')
