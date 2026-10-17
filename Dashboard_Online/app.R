
library(shiny)
library(bslib)
library(dplyr)
library(ggplot2)
library(plotly)
library(scales)

# Read dashboard data from the app's data folder
overview <- read.csv("data/overview.csv")
skill_demand <- read.csv("data/skill_demand.csv")
category_salary <- read.csv("data/category_salary.csv")

# Available job categories
job_categories <- sort(
  unique(na.omit(skill_demand$job_category_updated))
)

# User interface
ui <- page_fluid(
  theme = bs_theme(
    version = 5,
    bootswatch = "flatly"
  ),
  
  titlePanel("Data Science Job Market Dashboard"),
  
  p(
    "Exploring in-demand data science skills and",
    "their relationship with advertised salaries."
  ),
  
  layout_columns(
    value_box(
      title = "Total Job Postings",
      value = comma(overview$total_jobs[1]),
      theme = "primary"
    ),
    
    value_box(
      title = "Jobs with Eligible USD Salaries",
      value = comma(overview$salary_jobs[1]),
      theme = "info"
    ),
    
    value_box(
      title = "Skills Tracked",
      value = comma(overview$total_skills[1]),
      theme = "success"
    ),
    
    value_box(
      title = "Median Advertised Salary",
      value = dollar(overview$median_salary[1]),
      theme = "warning"
    )
  ),
  
  br(),
  
  card(
    card_header("Most In-Demand Data Science Skills"),
    
    selectInput(
      inputId = "category_filter",
      label = "Select Job Category",
      choices = c("All Categories", job_categories),
      selected = "All Categories"
    ),
    
    plotlyOutput("skill_plot", height = "450px")
  ),
  
  br(),
  
  card(
    card_header("Median Advertised Salary by Job Category"),
    plotlyOutput("salary_plot", height = "450px")
  ),
  
  br(),
  
  p(
    "Source: DATA 607 Project 3 job-posting dataset.",
    "Salaries represent eligible annual USD advertised",
    "midpoints, not actual employee earnings."
  )
)

# Server
server <- function(input, output, session) {
  
  filtered_skills <- reactive({
    
    if (input$category_filter == "All Categories") {
      
      # Count each skill across all categories
      skill_demand %>%
        group_by(skill_name) %>%
        summarise(
          job_count = sum(job_count),
          .groups = "drop"
        ) %>%
        arrange(desc(job_count), skill_name) %>%
        slice_head(n = 10)
      
    } else {
      
      skill_demand %>%
        filter(
          job_category_updated == input$category_filter
        ) %>%
        select(skill_name, job_count) %>%
        arrange(desc(job_count), skill_name) %>%
        slice_head(n = 10)
    }
  })
  
  output$skill_plot <- renderPlotly({
    
    plot_data <- filtered_skills()
    
    p <- ggplot(
      plot_data,
      aes(
        x = reorder(skill_name, job_count),
        y = job_count,
        text = paste0(
          "Skill: ", skill_name,
          "<br>Job Postings: ", job_count
        )
      )
    ) +
      geom_col(fill = "#2874A6") +
      coord_flip() +
      labs(
        x = NULL,
        y = "Number of Job Postings"
      ) +
      theme_minimal(base_size = 13)
    
    ggplotly(p, tooltip = "text")
  })
  
  output$salary_plot <- renderPlotly({
    
    plot_data <- category_salary %>%
      filter(!is.na(median_salary)) %>%
      arrange(median_salary)
    
    p <- ggplot(
      plot_data,
      aes(
        x = reorder(
          job_category_updated,
          median_salary
        ),
        y = median_salary,
        text = paste0(
          "Category: ", job_category_updated,
          "<br>Median Salary: ",
          dollar(median_salary),
          "<br>Total Jobs: ", total_jobs
        )
      )
    ) +
      geom_col(fill = "#17A589") +
      coord_flip() +
      scale_y_continuous(labels = dollar) +
      labs(
        x = NULL,
        y = "Median Annual Salary (USD)"
      ) +
      theme_minimal(base_size = 13)
    
    ggplotly(p, tooltip = "text")
  })
}

shinyApp(ui = ui, server = server)
