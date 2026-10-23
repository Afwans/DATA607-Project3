# DATA 607 Project 3 — Local PostgreSQL Shiny dashboard
library(shiny)
library(bslib)
library(DBI)
library(RPostgres)
library(dplyr)
library(ggplot2)
library(plotly)
library(scales)
library(DT)
library(rstudioapi)

password <- if (interactive() && rstudioapi::isAvailable()) rstudioapi::askForPassword('Enter your local PostgreSQL password') else Sys.getenv('PGPASSWORD', '')
if (!nzchar(password)) stop('A PostgreSQL password is required.')
con <- dbConnect(RPostgres::Postgres(), dbname='data607_project3', host='localhost',port=5432,user='postgres',password=password)
jobs <- dbGetQuery(con, "
 SELECT jp.job_id, jp.title, COALESCE(c.company_name,'Unknown') AS company,
        jp.location, jp.employment_type, jp.workplace_type, jp.posted_at::date AS posting_date,
        jp.apply_url, sa.salary_currency, sa.salary_min_annual, sa.salary_max_annual,
        sa.salary_midpoint_annual, sa.salary_usd_eligible,
        COALESCE(dc.job_category_updated,'Other / Unclassified') AS category,
        COALESCE(jsc.sector_name,'Other / Needs Review') AS job_category,
        (dc.job_id IS NOT NULL) AS is_ds
 FROM public.job_posting jp
 LEFT JOIN public.company c ON c.company_id=jp.company_id
 LEFT JOIN public.salary sa ON sa.job_id=jp.job_id
 LEFT JOIN public.data_science_classification dc ON dc.job_id=jp.job_id
 LEFT JOIN public.job_sector_classification jsc ON jsc.job_id=jp.job_id")
skills <- dbGetQuery(con, "SELECT DISTINCT js.job_id, sk.skill_name FROM public.job_skill js JOIN public.skill sk ON sk.skill_id=js.skill_id")
dbDisconnect(con)

jobs$job_id <- as.character(jobs$job_id)
skills$job_id <- as.character(skills$job_id)
jobs$posting_date <- as.Date(jobs$posting_date)
jobs$is_ds <- as.logical(jobs$is_ds)
jobs$salary_usd_eligible <- !is.na(jobs$salary_usd_eligible) & as.logical(jobs$salary_usd_eligible)
jobs$salary_midpoint_annual <- as.numeric(jobs$salary_midpoint_annual)
for (nm in c('salary_min_annual','salary_max_annual')) jobs[[nm]] <- as.numeric(jobs[[nm]])
stopifnot(!anyDuplicated(jobs$job_id), nrow(jobs)>0)
if (any(is.na(jobs$job_category))) stop('Missing job categories.')
valid_salary <- function(d) d %>% filter(salary_usd_eligible, is.finite(salary_midpoint_annual))
med <- function(x) if(length(x)) median(x,na.rm=TRUE) else NA_real_
fmt <- function(x) comma(x)
fmt_pct <- function(x) paste0(round(x, 1), '%')
ds_n <- sum(jobs$is_ds)
ds_salary <- valid_salary(jobs %>% filter(is_ds))
market_salary <- valid_salary(jobs)
category_counts <- jobs %>% count(job_category,name='job_count') %>% arrange(desc(job_count))
category_salary <- valid_salary(jobs %>% filter(is_ds)) %>% group_by(category) %>% summarise(salary_jobs=n(),median_salary=median(salary_midpoint_annual),.groups='drop')
all_skill_counts <- skills %>% count(skill_name,name='job_count',sort=TRUE)
ds_skills <- skills %>% semi_join(jobs %>% filter(is_ds) %>% select(job_id),by='job_id') %>% count(skill_name,name='job_count',sort=TRUE) %>% mutate(demand_pct=100*job_count/ds_n)
skill_salary_data <- skills %>% semi_join(jobs %>% filter(is_ds) %>% select(job_id),by='job_id') %>% inner_join(ds_salary %>% select(job_id,salary_midpoint_annual),by='job_id') %>% group_by(skill_name) %>% summarise(salary_jobs=n_distinct(job_id),median_salary=median(salary_midpoint_annual),.groups='drop') %>% inner_join(ds_skills,by='skill_name')
ds_categories <- jobs %>% filter(is_ds) %>% count(category,name='job_count',sort=TRUE)
currencies <- jobs %>% mutate(salary_currency=ifelse(is.na(salary_currency)|salary_currency=='','Unknown',salary_currency)) %>% count(salary_currency,name='job_count',sort=TRUE)
all_salary <- market_salary

graph_theme <- theme_minimal(base_size=12) + theme(plot.title=element_text(face='bold'), axis.text.y=element_text(size=11), plot.margin=margin(12,24,12,16))
# Fixed-height KPI cards prevent the default large empty space and clipped values.
kpi <- function(label, value, color='primary') {
  div(class='compact-kpi', value_box(label, value, theme=color, height='145px'))
}
chart_widget <- function(id, height='390px') plotlyOutput(id, height=height)

ui <- page_navbar(
  title='DATA 607 | Job Market Explorer',
  theme=bs_theme(version=5,bootswatch='flatly'),
  header=tags$head(tags$style(HTML("
    .compact-kpi .bslib-value-box { min-height:145px !important; height:auto !important; overflow:visible !important; }
    .compact-kpi .value-box-area { padding: 18px 20px !important; }
    .compact-kpi .value-box-title { font-size: 0.9rem !important; }
    .compact-kpi .value-box-value { font-size: 1.8rem !important; line-height:1.2 !important; white-space:nowrap; }
    .card { margin-bottom: 14px; }
    .card-header { font-weight:600; }
    .job-filter-panel .shiny-input-container { margin-bottom: 8px !important; }
    .job-filter-panel { margin-bottom: 0 !important; }
    .job-search-panel { margin-top: 0 !important; }
    .job-search-panel .shiny-input-container { width:100%; max-width:520px; }
  "))),
  nav_panel('Overview',
            h2('Data Science in the Broader Job Market'),
            p('All cleaned job postings are included in the overview. Data Science & AI remains the research focus.'),
            layout_columns(
              kpi('All Cleaned Jobs',fmt(nrow(jobs)),color='primary'),
              kpi('Companies',fmt(n_distinct(jobs$company[jobs$company!='Unknown'])),color='info'),
              kpi('Curated Data Science-Related Jobs',fmt(sum(jobs$is_ds)),color='success'),
              kpi('Comparable Annual USD Salaries',fmt(nrow(all_salary)),color='warning')
            ),
            card(card_header('Job Categories Across All Postings'),plotlyOutput('sectors_plot',height='460px')),
            p('Job categories are rule-based estimates from job_sector_classification. Other / Needs Review indicates postings without a confident category. The curated Data Science subset is analyzed separately.')
  ),
  nav_panel('Data Science Analysis',
            h2('Data Science & AI'),
            p('Curated Data Science-related postings, including Data Analytics, Data Engineering, AI/ML and related categories.'),
            layout_columns(kpi('Data Science-Related Postings',fmt(sum(jobs$is_ds))),kpi('Skills Mentioned in DS Jobs',fmt(nrow(ds_skills)))),
            card(card_header('Top Skills in Data Science Postings — Count and Share'),plotlyOutput('ds_skills_plot',height='480px')),
            card(card_header('Data Science Job Categories'),plotlyOutput('ds_sub_plot',height='360px')),
            p('Skill mentions are keyword matches in descriptions, not verified job requirements. One posting can mention multiple skills.')
  ),
  nav_panel('Salary Insights',
            h2('Annual USD Salary Comparisons'),
            layout_columns(kpi('All-Market Salary-Eligible Jobs',fmt(nrow(all_salary))),kpi('Data Science Salary-Eligible Jobs',fmt(nrow(ds_salary))),kpi('Overall Market Median',dollar(med(all_salary$salary_midpoint_annual))),kpi('Data Science Median',dollar(med(ds_salary$salary_midpoint_annual)))),
            card(card_header('Median Eligible Annual USD Salary by Data Science Job Category'),plotlyOutput('salary_plot',height='590px')),
            card(card_header('Median Annual USD Salary by Skill — Data Science Jobs'),plotlyOutput('skill_salary_plot',height='590px')),
            p('Annual USD salaries use eligible salary-range midpoints; no currency conversion is performed. The overall-market group includes Data Science jobs. Each skill is counted once per posting. Explore salary distributions, skill-demand relationships, and original currencies in their own tabs.')
  ),
  nav_panel('Salary Distribution',
            h2('Annual USD Salary Distribution — Data Science vs. All Jobs'),
            p('Compare the distribution of eligible annual USD salary midpoints for the overall market and the curated Data Science subset.'),
            card(card_header('Annual USD Salary Distribution — Data Science vs. All Jobs'),
                 plotlyOutput('salary_compare_plot', height='650px')),
            p('All jobs includes Data Science postings. Only eligible annual USD salary midpoints are used; no currency conversion is performed.')
  ),
  nav_panel('Skill Demand & Salary',
            h2('Skill Demand vs. Median Advertised Annual USD Salary'),
            p('Each point represents a skill. Hover to see its demand, median advertised salary, and number of salary-eligible Data Science postings.'),
            card(card_header('Skill Demand and Median Salary — Curated Data Science Jobs'),
                 plotlyOutput('skill_demand_salary_plot',height='620px')),
            p('Only skills with at least 10 salary-eligible postings are shown. Salary comparisons are descriptive, not causal.')
  ),
  nav_panel('Salary Currencies',
            h2('Job Postings by Original Salary Currency'),
            p('Currency codes reflect the original advertised salary currency. These counts include all cleaned postings and do not represent converted salaries.'),
            card(card_header('Original Salary Currency Distribution'),
                 plotlyOutput('currency_plot',height='560px'))
  ),
  nav_panel('Posting Trends',
            h2('Posting Date Trends'),
            card(card_header('Daily Postings from Cleaned Dataset'),plotlyOutput('dates_plot',height='430px')),
            card(card_header('Daily Data Science-Related Postings'),plotlyOutput('ds_dates_plot',height='430px')),
            p('Posting dates cover October 5–12, 2026 only. These counts describe the collected snapshot, not long-term hiring trends.')
  ),
  nav_panel('Explore All Jobs',
            h2('Search All Cleaned Job Postings'),
            div(class='job-filter-panel', layout_columns(
              selectInput('ds_only','Research Group',choices=c('All job postings'='all','Curated Data Science only'='ds'),selected='all'),
              selectInput('category','Job Category',choices=c('All categories',sort(unique(jobs$job_category))),selected='All categories'),
              selectInput('workplace','Workplace Type',choices=c('All workplaces',sort(unique(na.omit(jobs$workplace_type)))),selected='All workplaces'),
              selectInput('currency','Salary Currency',choices=c('All currencies',sort(unique(na.omit(jobs$salary_currency)))),selected='All currencies'),
              col_widths=c(3,3,3,3)
            )),
            div(class='job-search-panel', textInput('query','Search title, company, or location',placeholder='e.g. data analyst, New York')),
            textOutput('result_count'),DTOutput('jobs_table'),
            p('Apply links open the source job posting when available; some may no longer be active.')
  )
)
server <- function(input,output,session){
  output$sectors_plot <- renderPlotly({
    d <- category_counts
    ggplotly(ggplot(d,aes(x=reorder(job_category,job_count),y=job_count,text=paste0(job_category,': ',comma(job_count))))+
               geom_col(fill='#6750a4')+coord_flip()+labs(x=NULL,y='Job postings')+graph_theme,tooltip='text')
  })
  output$ds_skills_plot <- renderPlotly({
    d <- ds_skills %>% slice_head(n=15)
    validate(need(nrow(d)>0,'No tracked skills found.'))
    ggplotly(ggplot(d,aes(x=reorder(skill_name,demand_pct),y=demand_pct,text=paste0(skill_name,'<br>',job_count,' of ',ds_n,' jobs (',round(demand_pct,1),'%)')))+
               geom_col(fill='#2874a6')+coord_flip()+scale_y_continuous(labels=function(x) paste0(x,'%'))+labs(x=NULL,y='Share of curated Data Science jobs')+graph_theme,tooltip='text')
  })
  output$ds_sub_plot <- renderPlotly({
    d <- ds_categories
    ggplotly(ggplot(d,aes(x=reorder(category,job_count),y=job_count,text=paste0(category,': ',job_count)))+
               geom_col(fill='#17a589')+coord_flip()+labs(x=NULL,y='Job postings')+graph_theme,tooltip='text')
  })
  output$salary_plot <- renderPlotly({
    d <- category_salary %>% filter(category!='Other / Unclassified')
    validate(need(nrow(d)>0,'No eligible Data Science salaries.'))
    ggplotly(ggplot(d,aes(x=reorder(category,median_salary),y=median_salary,text=paste0(category,'<br>Median: ',dollar(median_salary),'<br>Eligible jobs: ',salary_jobs)))+
               geom_col(fill='#17a589',width=0.65)+coord_flip()+scale_y_continuous(labels=label_dollar())+labs(x=NULL,y='Annual USD median')+graph_theme+theme(axis.text.y=element_text(size=11),plot.margin=margin(18,30,18,125)),tooltip='text')
  })
  output$salary_compare_plot <- renderPlotly({
    d <- bind_rows(
      all_salary %>% transmute(group='All jobs (including DS)',salary=salary_midpoint_annual),
      ds_salary %>% transmute(group='Curated Data Science',salary=salary_midpoint_annual)
    )
    validate(need(nrow(d)>0,'No comparable salary records available.'))
    ggplotly(ggplot(d,aes(x=group,y=salary,fill=group))+
      geom_boxplot(outlier.alpha=0.15)+scale_y_continuous(labels=label_dollar())+
      labs(x=NULL,y='Eligible annual USD salary midpoint')+graph_theme+
      theme(legend.position='none'))
  })
  output$skill_demand_salary_plot <- renderPlotly({
    d <- skill_salary_data %>% filter(salary_jobs>=10) %>% arrange(desc(job_count)) %>% slice_head(n=20)
    validate(need(nrow(d)>0,'No skills meet the minimum 10 salary-eligible postings.'))
    ggplotly(ggplot(d,aes(x=demand_pct,y=median_salary,size=salary_jobs,
      text=paste0(skill_name,'<br>Demand: ',job_count,'/',ds_n,' (',round(demand_pct,1),'%)',
                  '<br>Median salary: ',dollar(median_salary),'<br>Salary-eligible jobs: ',salary_jobs)))+
      geom_point(color='#2874a6',alpha=0.75)+
      scale_x_continuous(labels=function(x) paste0(x,'%'))+
      scale_y_continuous(labels=label_dollar())+
      labs(x='Share of curated Data Science postings mentioning skill',y='Median eligible annual USD salary',size='Salary jobs')+
      graph_theme,tooltip='text')
  })
  output$skill_salary_plot <- renderPlotly({
    d <- skill_salary_data %>% filter(salary_jobs>=10) %>% arrange(desc(median_salary)) %>% slice_head(n=12)
    validate(need(nrow(d)>0,'No eligible salary comparisons.'))
    ggplotly(ggplot(d,aes(x=reorder(skill_name,median_salary),y=median_salary,text=paste0(skill_name,'<br>Median: ',dollar(median_salary),'<br>Eligible jobs: ',salary_jobs)))+
               geom_col(fill='#2874a6',width=0.65)+coord_flip()+scale_y_continuous(labels=label_dollar())+labs(x=NULL,y='Annual USD median (minimum 10 postings)')+graph_theme+theme(axis.text.y=element_text(size=11),plot.margin=margin(18,30,18,125)),tooltip='text')
  })
  output$currency_plot <- renderPlotly({
    ggplotly(ggplot(currencies,aes(x=reorder(salary_currency,job_count),y=job_count,text=paste0(salary_currency,': ',job_count)))+
               geom_col(fill='#6750a4',width=0.65)+coord_flip()+labs(x=NULL,y='Job postings')+graph_theme+theme(plot.margin=margin(15,25,15,60)),tooltip='text')
  })
  daily_chart <- function(d){
    d <- d %>% filter(!is.na(posting_date)) %>% count(posting_date,name='job_count')
    validate(need(nrow(d)>0,'No posting dates found.'))
    ggplotly(ggplot(d,aes(x=posting_date,y=job_count,text=paste0(posting_date,': ',job_count,' jobs')))+
               geom_col(fill='#2874a6')+scale_x_date(date_breaks='1 day',date_labels='%b %d')+
               labs(x='Posting date',y='Jobs posted')+graph_theme+theme(axis.text.x=element_text(angle=35,hjust=1)),tooltip='text')
  }
  output$dates_plot <- renderPlotly(daily_chart(jobs))
  output$ds_dates_plot <- renderPlotly(daily_chart(jobs %>% filter(is_ds)))
  selected_jobs <- reactive({
    d <- jobs
    if (identical(input$ds_only,'ds')) d <- d %>% filter(is_ds)
    if(!identical(input$category,'All categories')) d <- d %>% filter(job_category==input$category)
    if(!identical(input$workplace,'All workplaces')) d <- d %>% filter(workplace_type==input$workplace)
    if(!identical(input$currency,'All currencies')) d <- d %>% filter(salary_currency==input$currency)
    q <- trimws(input$query %||% '')
    if(nzchar(q)){
      hit <- grepl(q,coalesce(d$title,''),ignore.case=TRUE,fixed=TRUE) |
        grepl(q,coalesce(d$company,''),ignore.case=TRUE,fixed=TRUE) |
        grepl(q,coalesce(d$location,''),ignore.case=TRUE,fixed=TRUE)
      d <- d[hit, ,drop=FALSE]
    }
    d
  })
  output$result_count <- renderText(paste(format(nrow(selected_jobs()),big.mark=','),'matching job postings'))
  output$jobs_table <- renderDT({
    d <- selected_jobs() %>% select(title,company,location,job_category,workplace_type,employment_type,salary_currency,salary_min_annual,salary_max_annual,apply_url)
    names(d) <- c('Title','Company','Location','Category','Workplace','Employment','Currency','Annual Min','Annual Max','Apply')
    d$Apply <- ifelse(!is.na(d$Apply)&grepl('^https?://',d$Apply),paste0('<a href="',htmltools::htmlEscape(coalesce(d$Apply,''),attribute=TRUE),'" target="_blank" rel="noopener noreferrer">Apply</a>'),'')
    datatable(d,escape=setdiff(seq_along(d),10),rownames=FALSE,options=list(pageLength=15,scrollX=TRUE,searching=FALSE,order=list()),filter='none')
  },server=TRUE)
}
shinyApp(ui,server)
