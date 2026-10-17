# DATA 607 Project 3 - Dataset 1
# Data Science Job Market Insights Dashboard

library(shiny)
library(bslib)
library(DBI)
library(RPostgres)
library(dplyr)
library(ggplot2)
library(plotly)
library(scales)
library(rstudioapi)

# Ask for password once when the app starts.
db_password <- rstudioapi::askForPassword("Enter your PostgreSQL password")

connect_db <- function() {
  dbConnect(
    RPostgres::Postgres(),
    dbname = "data607_project3",
    host = "localhost",
    port = 5432,
    user = "postgres",
    password = db_password
  )
}

# Load overall summary data once at startup.
con <- connect_db()

tryCatch({
  overview <- dbGetQuery(con, "
    SELECT
      (SELECT COUNT(*) FROM public.job_posting) AS total_jobs,
      (SELECT COUNT(*) FROM public.salary
       WHERE salary_usd_eligible = TRUE
         AND salary_midpoint_annual IS NOT NULL) AS salary_jobs,
      (SELECT COUNT(*) FROM public.skill) AS total_skills,
      (SELECT PERCENTILE_CONT(0.5)
         WITHIN GROUP (ORDER BY salary_midpoint_annual)
       FROM public.salary
       WHERE salary_usd_eligible = TRUE
         AND salary_midpoint_annual IS NOT NULL) AS median_salary
  ")
  
  skill_demand <- dbGetQuery(con, "
    SELECT sk.skill_name,
           COUNT(DISTINCT js.job_id) AS job_count
    FROM public.skill sk
    LEFT JOIN public.job_skill js ON sk.skill_id = js.skill_id
    GROUP BY sk.skill_id, sk.skill_name
    ORDER BY job_count DESC, sk.skill_name
    LIMIT 10
  ")
  
  category_salary <- dbGetQuery(con, "
    SELECT jp.job_category_updated AS job_category,
           COUNT(*) AS total_jobs,
           PERCENTILE_CONT(0.5) WITHIN GROUP (
             ORDER BY sa.salary_midpoint_annual
           ) FILTER (
             WHERE sa.salary_usd_eligible = TRUE
               AND sa.salary_midpoint_annual IS NOT NULL
           ) AS median_salary
    FROM public.job_posting jp
    LEFT JOIN public.salary sa ON jp.job_id = sa.job_id
    GROUP BY jp.job_category_updated
    ORDER BY median_salary DESC NULLS LAST
  ")
  
  job_categories <- dbGetQuery(con, "
    SELECT DISTINCT job_category_updated
    FROM public.job_posting
    WHERE job_category_updated IS NOT NULL
    ORDER BY job_category_updated
  ")$job_category_updated
}, finally = {
  dbDisconnect(con)
})

# PostgreSQL COUNT(*) is BIGINT, which RPostgres may return as integer64.
overview$total_jobs <- as.numeric(overview$total_jobs)
overview$salary_jobs <- as.numeric(overview$salary_jobs)
overview$total_skills <- as.numeric(overview$total_skills)
overview$median_salary <- as.numeric(overview$median_salary)
skill_demand$job_count <- as.numeric(skill_demand$job_count)
category_salary$total_jobs <- as.numeric(category_salary$total_jobs)
category_salary$median_salary <- as.numeric(category_salary$median_salary)

ui <- page_fluid(
  theme = bs_theme(version = 5, bootswatch = "flatly", primary = "#635BFF"),
  
  titlePanel("Data Science Job Market Insights"),
  p("DATA 607 Project 3 | Dataset 1 | PostgreSQL + R Shiny"),
  
  layout_columns(
    value_box(title = "Job Postings", value = comma(overview$total_jobs)),
    value_box(title = "Eligible Salaries", value = comma(overview$salary_jobs)),
    value_box(title = "Tracked Skills", value = comma(overview$total_skills)),
    value_box(title = "Median Annual Salary", value = dollar(overview$median_salary)),
    col_widths = c(3, 3, 3, 3)
  ),
  
  hr(),
  
  card(
    card_header("Dashboard Filters"),
    selectInput(
      inputId = "category_filter",
      label = "Select Job Category",
      choices = c("All Categories", job_categories),
      selected = "All Categories",
      width = "100%"
    )
  ),
  
  br(),
  
  layout_columns(
    card(
      card_header("Top 10 Most In-Demand Skills"),
      plotlyOutput("skill_chart", height = "430px")
    ),
    card(
      card_header("Median Salary by Job Category (Overall)"),
      plotlyOutput("salary_chart", height = "430px")
    ),
    col_widths = c(6, 6)
  ),
  
  p(
    "Note: Skill counts update with the job category filter. ",
    "Summary metrics and category salary chart show the overall sample. ",
    "Salaries are advertised annual USD midpoints; associations do not imply causation."
  )
)

server <- function(input, output, session) {
  
  # Parameterized query: the category is passed separately from SQL text.
  filtered_skill_demand <- reactive({
    if (identical(input$category_filter, "All Categories")) {
      return(skill_demand)
    }
    
    con_filter <- connect_db()
    on.exit(dbDisconnect(con_filter), add = TRUE)
    
    result <- dbGetQuery(
      con_filter,
      "
      SELECT sk.skill_name,
             COUNT(DISTINCT js.job_id) AS job_count
      FROM public.skill sk
      JOIN public.job_skill js ON sk.skill_id = js.skill_id
      JOIN public.job_posting jp ON js.job_id = jp.job_id
      WHERE jp.job_category_updated = $1
      GROUP BY sk.skill_id, sk.skill_name
      ORDER BY job_count DESC, sk.skill_name
      LIMIT 10
      ",
      params = list(input$category_filter)
    )
    
    result$job_count <- as.numeric(result$job_count)
    result
  })
  
  output$skill_chart <- renderPlotly({
    data <- filtered_skill_demand()
    validate(need(nrow(data) > 0, "No tracked skills found for this category."))
    
    p <- ggplot(
      data,
      aes(
        x = reorder(skill_name, job_count),
        y = job_count,
        text = paste0(skill_name, ": ", job_count, " postings")
      )
    ) +
      geom_col(fill = "#635BFF") +
      coord_flip() +
      labs(x = NULL, y = "Number of Job Postings") +
      theme_minimal()
    
    ggplotly(p, tooltip = "text")
  })
  
  output$salary_chart <- renderPlotly({
    data <- category_salary %>% filter(!is.na(job_category), !is.na(median_salary))
    validate(need(nrow(data) > 0, "No eligible salary records found."))
    
    p <- ggplot(
      data,
      aes(
        x = reorder(job_category, median_salary),
        y = median_salary,
        text = paste0(job_category, ": ", dollar(median_salary))
      )
    ) +
      geom_col(fill = "#20BFA9") +
      coord_flip() +
      scale_y_continuous(labels = label_dollar()) +
      labs(x = NULL, y = "Median Annual Salary (USD)") +
      theme_minimal()
    
    ggplotly(p, tooltip = "text")
  })
}

shinyApp(ui = ui, server = server)
