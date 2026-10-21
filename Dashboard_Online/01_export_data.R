# DATA 607 Project 3 - Safe export (updated copy)
# Run from project root: DATA607-Project3
library(DBI)
library(RPostgres)
library(rstudioapi)
output_dir <- 'Dashboard_Online/data'
if (!dir.exists('Dashboard_Online')) stop('Run from DATA607-Project3 project root (Dashboard_Online folder not found).')
dir.create(output_dir,recursive=TRUE,showWarnings=FALSE)
con <- dbConnect(RPostgres::Postgres(),dbname='data607_project3',host='localhost',port=5432,user='postgres',password=rstudioapi::askForPassword('Enter your PostgreSQL password'))
tables <- c('company','job_posting','salary','skill','job_skill')
for (table_name in tables) {
  output_file <- file.path(output_dir,paste0(table_name,'.csv'))
  if (file.exists(output_file)) {
    cat('PRESERVED existing:',output_file,'\n')
    next
  }
  data <- dbReadTable(con,Id(schema='public',table=table_name))
  write.csv(data,output_file,row.names=FALSE,na='')
  cat('CREATED:',output_file,'-',nrow(data),'rows\n')
}
dbDisconnect(con)
cat('Export finished. Existing files were not overwritten.\n')
