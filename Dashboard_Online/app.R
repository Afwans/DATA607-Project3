# DATA 607 Project 3 - Online Shiny dashboard (updated copy)
library(shiny)
library(bslib)
library(dplyr)
library(ggplot2)
library(plotly)
library(scales)
overview <- read.csv('data/overview.csv')
skill_demand <- read.csv('data/skill_demand.csv')
category_salary <- read.csv('data/category_salary.csv')
posting_dates <- read.csv('data/posting_dates.csv',stringsAsFactors=FALSE)
required <- c('posting_date','job_category_updated','job_count')
if (!all(required %in% names(posting_dates))) stop('posting_dates.csv has incorrect columns; run updated preparation script.')
posting_dates$posting_date <- as.Date(posting_dates$posting_date)
if (anyNA(posting_dates$posting_date) || sum(posting_dates$job_count) != overview$total_jobs[1]) stop('Posting date data does not match overview. Check CSV snapshot versions.')
job_categories <- sort(unique(na.omit(skill_demand$job_category_updated)))
ui <- page_fluid(
  theme=bs_theme(version=5,bootswatch='flatly'),
  titlePanel('Data Science Job Market Dashboard'),
  p('Exploring in-demand data science skills and their relationship with advertised salaries.'),
  layout_columns(
    value_box(title='Total Job Postings',value=comma(overview$total_jobs[1]),theme='primary'),
    value_box(title='Jobs with Eligible USD Salaries',value=comma(overview$salary_jobs[1]),theme='info'),
    value_box(title='Skills Tracked',value=comma(overview$total_skills[1]),theme='success'),
    value_box(title='Median Advertised Salary',value=dollar(overview$median_salary[1]),theme='warning')
  ),br(),
  card(card_header('Most In-Demand Data Science Skills'),selectInput('category_filter','Select Job Category',choices=c('All Categories',job_categories),selected='All Categories'),plotlyOutput('skill_plot',height='450px')),
  br(),card(card_header('Median Advertised Salary by Job Category'),plotlyOutput('salary_plot',height='450px')),
  br(),layout_columns(
    card(card_header('Daily Job Postings'),plotlyOutput('daily_plot',height='400px')),
    card(card_header('Daily Job Postings by Category'),plotlyOutput('date_category_plot',height='400px')),
    col_widths=c(6,6)
  ),br(),
  p('Source: DATA 607 Project 3 job-posting dataset. Salaries represent eligible annual USD advertised midpoints, not actual employee earnings. Skill and posting-date charts respond to the category filter; salary and summary charts represent the overall sample. Posting dates cover a short collection window.')
)
server <- function(input,output,session) {
  filtered_skills <- reactive({
    if (input$category_filter=='All Categories') {
      skill_demand %>% group_by(skill_name) %>% summarise(job_count=sum(job_count),.groups='drop') %>% arrange(desc(job_count),skill_name) %>% slice_head(n=10)
    } else {
      skill_demand %>% filter(job_category_updated==input$category_filter) %>% select(skill_name,job_count) %>% arrange(desc(job_count),skill_name) %>% slice_head(n=10)
    }
  })
  filtered_dates <- reactive({
    if (input$category_filter=='All Categories') posting_dates else posting_dates %>% filter(job_category_updated==input$category_filter)
  })
  output$skill_plot <- renderPlotly({
    data <- filtered_skills()
    validate(need(nrow(data)>0,'No skills for this category.'))
    p <- ggplot(data,aes(x=reorder(skill_name,job_count),y=job_count,text=paste0('Skill: ',skill_name,'<br>Job Postings: ',job_count))) + geom_col(fill='#2874A6') + coord_flip() + labs(x=NULL,y='Number of Job Postings') + theme_minimal(base_size=13)
    ggplotly(p,tooltip='text')
  })
  output$salary_plot <- renderPlotly({
    data <- category_salary %>% filter(!is.na(median_salary)) %>% arrange(median_salary)
    validate(need(nrow(data)>0,'No eligible salaries found.'))
    p <- ggplot(data,aes(x=reorder(job_category_updated,median_salary),y=median_salary,text=paste0('Category: ',job_category_updated,'<br>Median Salary: ',dollar(median_salary),'<br>Total Jobs: ',total_jobs))) + geom_col(fill='#17A589') + coord_flip() + scale_y_continuous(labels=label_dollar()) + labs(x=NULL,y='Median Annual Salary (USD)') + theme_minimal(base_size=13)
    ggplotly(p,tooltip='text')
  })
  output$daily_plot <- renderPlotly({
    data <- filtered_dates() %>% group_by(posting_date) %>% summarise(job_count=sum(job_count),.groups='drop')
    validate(need(nrow(data)>0,'No posting dates for this category.'))
    p <- ggplot(data,aes(x=posting_date,y=job_count,text=paste0(format(posting_date,'%b %d, %Y'),': ',job_count,' postings'))) + geom_col(fill='#2874A6') + scale_x_date(date_breaks='1 day',date_labels='%b %d') + labs(x='Date Posted',y='Job Postings') + theme_minimal(base_size=13)
    ggplotly(p,tooltip='text')
  })
  output$date_category_plot <- renderPlotly({
    data <- filtered_dates()
    validate(need(nrow(data)>0,'No posting dates for this category.'))
    p <- ggplot(data,aes(x=posting_date,y=job_count,fill=job_category_updated,text=paste0(format(posting_date,'%b %d, %Y'),'<br>',job_category_updated,': ',job_count))) + geom_col() + scale_x_date(date_breaks='1 day',date_labels='%b %d') + labs(x='Date Posted',y='Job Postings',fill='Category') + theme_minimal(base_size=13)
    ggplotly(p,tooltip='text')
  })
}
shinyApp(ui=ui,server=server)
