# DATA 607 — Project 3: Data Science Skills and Salaries

## Research Question

**Which data science skills are most in demand, and how do those skills relate to advertised salaries?**

This project analyzes job postings to identify commonly requested data science skills and explore their relationships with advertised compensation.

Data cleaning, classification, transformation, skill extraction, and exploratory analysis were performed in **R**. The cleaned data was organized into a normalized **PostgreSQL relational database** and used to develop interactive dashboards with **R Shiny**.

The project examines both the broader job market and a selected group of Data Science-related positions.

## Dataset 1 Overview

The dataset was obtained from the Kaggle dataset [Job Postings with Salaries](https://www.kaggle.com/datasets/minmaxer/job-postings-with-salaries).

The analyzed snapshot covers job postings dated **October 5–12, 2026**.

| Measure | Result |
|---|---:|
| Cleaned job postings | 9,173 |
| Companies | 3,969 |
| Data Science-related postings | 229 |
| Individual skills tracked | 30 |
| Job–skill relationships across all postings | 7,140 |
| Jobs with at least one tracked skill | 3,428 |
| Eligible annual USD salaries — full market | 7,590 |
| Eligible annual USD salaries — Data Science | 180 |
| Median annual salary midpoint — full market | $110,000 |
| Median annual salary midpoint — Data Science | $165,000 |

The 229 Data Science-related postings are a subset of the 9,173 cleaned job postings.

Salary results are based only on records that passed the project's salary validation rules. The reported salary values represent advertised annual USD salary midpoints, not actual employee earnings.

## Interactive Data Science Job Market Dashboard

**Dashboard URL:** https://mohdafwan.shinyapps.io/data607-project3/

The project includes two versions of the dashboard:

- **Local Dashboard:** Connects directly to the PostgreSQL database.
- **Online Dashboard:** Reads CSV files exported from the finalized PostgreSQL database.

Both versions are designed to explore the same cleaned dataset and analysis results.

### Dashboard Features

The dashboard is organized into five sections:

**1. Overview**

Provides a summary of the broader job market, including total job postings, companies, Data Science-related jobs, and eligible salary records.

**2. Data Science Analysis**

Examines the 229 Data Science-related postings, including frequently requested technical skills and job category comparisons.

**3. Salary Insights**

Compares advertised annual USD salary midpoints across Data Science job categories and technical skills.

**4. Posting Trends**

Explores daily job posting counts during the dataset's eight-day observation period.

**5. Explore All Jobs**

Provides a searchable interface for exploring job postings and their associated information.

The dashboard uses interactive charts, hover information, and filters to help users explore the results.

### Technology Stack

| Technology | Purpose |
|---|---|
| R | Data cleaning, classification, transformation, and exploratory analysis |
| PostgreSQL | Storage of the six normalized relational tables |
| SQL | Data retrieval, joins, and validation |
| R Shiny | Interactive dashboard development |
| bslib | Dashboard layout and styling |
| ggplot2 | Statistical visualizations |
| Plotly | Interactive charts |
| DT | Searchable job tables |
| shinyapps.io | Online dashboard hosting |
| GitHub | Version control and project collaboration |

### Dashboard Data

The PostgreSQL database contains six normalized tables:

| Table | Records |
|---|---:|
| `company` | 3,969 |
| `job_posting` | 9,173 |
| `salary` | 9,173 |
| `skill` | 30 |
| `job_skill` | 7,140 |
| `data_science_classification` | 229 |

The `data_science_classification` table identifies the selected Data Science-related postings and stores their reviewed classifications.

The local dashboard queries PostgreSQL directly. The online dashboard uses exported CSV files, allowing visitors to explore the data without accessing the local database or requiring database credentials.

## Running the Dashboard Locally

### PostgreSQL-Connected Dashboard

The local dashboard is located at:

`Dashboard/app.R`

Requirements:

- R and RStudio
- PostgreSQL running locally
- Database named `data607_project3`
- Required R packages installed

To launch the dashboard:

```r
shiny::runApp("Dashboard")
```

The application prompts for the local PostgreSQL password.

### Online Dashboard

The standalone dashboard is located at:

`Dashboard_Online/app.R`

The online version uses prepared CSV files stored in:

`Dashboard_Online/data/`

To refresh the dashboard data, run the following scripts from the `Dashboard_Online` folder:

```r
source("01_export_data.R")
source("02_prepare_dashboard_data.R")
```

The first script exports the six PostgreSQL tables. The second prepares or validates the data required by the dashboard.

To launch the standalone dashboard:

```r
shiny::runApp("Dashboard_Online")
```

The online dashboard can be deployed to shinyapps.io after the exported data and dashboard functionality have been verified.

**Published dashboard URL:** https://mohdafwan.shinyapps.io/data607-project3/

*The URL is the project's existing published address. Updated results will appear there only after the revised dashboard is successfully redeployed.*

## Selected Findings

### Most In-Demand Data Science Skills

Among the **229 Data Science-related job postings**, the ten most frequently detected skills were:

| Skill | Job postings | Share of Data Science jobs |
|---|---:|---:|
| Python | 163 | 71.18% |
| SQL | 133 | 58.08% |
| Machine Learning | 74 | 32.31% |
| Large Language Models (LLMs) | 60 | 26.20% |
| Statistics | 55 | 24.02% |
| Data Pipelines | 54 | 23.58% |
| dbt | 51 | 22.27% |
| AWS | 47 | 20.52% |
| Snowflake | 38 | 16.59% |
| Databricks | 33 | 14.41% |

Python and SQL were the most frequently mentioned technical skills among the selected Data Science-related positions.

Skills were identified using keyword and regular-expression matching in job descriptions. Multiple skills may appear in one posting, so percentages do not add up to 100%.

### Salary Comparison

| Job population | Eligible salary records | Median annual USD salary midpoint |
|---|---:|---:|
| Full job market | 7,590 | $110,000 |
| Data Science-related jobs | 180 | $165,000 |

The median advertised salary midpoint for the Data Science-related subgroup was **$55,000 higher**, or **50% higher**, than the full-market median.

This is a descriptive comparison, not evidence that working in Data Science causes higher compensation.

### Salary by Data Science Job Category

| Job category | Total postings | Eligible salary records | Median annual salary |
|---|---:|---:|---:|
| AI / Machine Learning | 60 | 51 | $190,000 |
| Data Science | 41 | 28 | $188,250 |
| Statistics | 10 | 10 | $179,500 |
| Data Engineering | 55 | 40 | $170,000 |
| Database | 8 | 7 | $152,500 |
| Data Analytics | 49 | 40 | $118,750 |
| Business Intelligence | 6 | 4 | $114,213.25 |

AI / Machine Learning and Data Science categories had the highest median advertised salaries in the selected subgroup.

However, the number of eligible salary records differs across categories, and smaller categories should be interpreted cautiously.

### Skills and Advertised Salaries

Selected skill-level median salary midpoints among eligible Data Science-related postings were:

| Skill | Eligible postings mentioning skill | Median annual salary |
|---|---:|---:|
| PyTorch | 23 | $195,050 |
| Deep Learning | 13 | $193,300 |
| LLM | 51 | $190,900 |
| Machine Learning | 59 | $182,200 |
| Data Pipelines | 42 | $182,025 |
| Python | 131 | $165,000 |
| SQL | 105 | $152,500 |

Among the skills shown, specialized AI and machine learning skills were associated with higher median advertised salary midpoints.

These comparisons are descriptive. They do not control for seniority, location, employer, job category, or overlapping skills.

## Entity–Relationship (ER) Diagram

![Normalized Dataset 1 ER Diagram](ER_Diagram/Dataset1_ER_Diagram.png)

The project uses an implemented relational database containing six normalized tables.

| Entity | Purpose | Primary and foreign keys |
|---|---|---|
| `COMPANY` | Stores organizations advertising jobs | `company_id` (PK) |
| `JOB_POSTING` | Stores job descriptions and related attributes | `job_id` (PK), `company_id` (FK) |
| `SALARY` | Stores advertised compensation and validation fields | `job_id` (PK and FK) |
| `SKILL` | Stores the 30 tracked technical skills | `skill_id` (PK) |
| `JOB_SKILL` | Connects postings to detected skills | (`job_id`, `skill_id`) composite PK and FKs |
| `DATA_SCIENCE_CLASSIFICATION` | Stores reviewed Data Science classifications | `job_id` (PK and FK) |

### Database Relationships

- One company can advertise multiple job postings.
- Each job posting has one corresponding salary record in the current database.
- A job posting can reference multiple technical skills.
- A technical skill can appear in multiple job postings.
- The `JOB_SKILL` table resolves the many-to-many relationship between postings and skills.
- A posting may have a corresponding record in `DATA_SCIENCE_CLASSIFICATION` when it belongs to the selected Data Science-related subgroup.

The relational database was validated using foreign-key checks. No orphaned records were found in the five tested foreign-key relationships.

See [ER diagram documentation](Dataset1_ER_Diagram_Documentation.Rmd) for additional details.

## Project Files

```text
DATA607-Project3/
│
├── Data/
│   └── Normalized/
│
├── Dashboard/
│   ├── app.R
│   └── 01_test_connection.R
│
├── Dashboard_Online/
│   ├── 01_export_data.R
│   ├── 02_prepare_dashboard_data.R
│   ├── app.R
│   ├── data/
│   └── rsconnect/
│
├── ER_Diagram/
│   ├── Dataset1_ER_Diagram.png
│   ├── Dataset1_ER_Diagram.dot
│   ├── Dataset1_ER_Diagram.R
│   └── Dataset1_ER_Diagram.html
│
├── 01_explore_jobs.R
├── 02_clean_jobs.R
├── ...
├── 13_normalize_data.R
│
├── DATA607_Project3_Dataset1_Documentation.Rmd
├── Dataset1_ER_Diagram_Documentation.Rmd
└── README.md
```

The project scripts cover source exploration, cleaning, Data Science classification, manual review, skill extraction, salary analysis, validation, and relational normalization.

## Reproducing the ER Diagram

Open the project in RStudio and run the following commands from the repository root:

```r
install.packages(c("DiagrammeR", "DiagrammeRsvg", "rsvg"))

source("ER_Diagram/Dataset1_ER_Diagram.R")
```

The script uses the Graphviz `.dot` file stored in the `ER_Diagram` folder.

To render the ER documentation, open `Dataset1_ER_Diagram_Documentation.Rmd` in RStudio and knit it to HTML.

## Limitations

- **Short observation period:** The job postings cover October 5–12, 2026, so the data cannot establish long-term hiring trends.
- **Dataset representativeness:** The selected postings may not represent the full labor market.
- **Skill detection:** Keyword and regular-expression matching can miss relevant skills or identify mentions that are not actual job requirements.
- **Limited skill catalog:** The analysis tracks 30 technical skills rather than every skill employers may request.
- **Salary availability:** Not every posting contains a usable annual USD salary range.
- **Salary exclusions:** Invalid, non-USD, incomplete, and flagged outlier salary records were excluded from the eligible salary comparisons.
- **Confounding factors:** Salary differences may reflect job seniority, location, employer, and other characteristics rather than the listed skill itself.
- **Classification uncertainty:** Data Science job categories are based on rule-based classification and review rather than verified employer-provided labels.

The findings describe patterns in the selected dataset and should not be interpreted as causal relationships.

## Conclusion

The analysis found that **Python and SQL were the most frequently requested skills** among the selected Data Science-related postings.

Machine Learning and Large Language Models were also commonly mentioned, suggesting that AI-related capabilities are important within this sample.

Specialized AI skills, including PyTorch and LLM-related skills, were associated with relatively high advertised salary midpoints. However, these relationships may also reflect differences in job type, seniority, and employer.

Overall, the project demonstrates how R, PostgreSQL, SQL, and interactive dashboards can be combined to explore skill demand and advertised compensation in job-posting data.

## Data Source

[Job Postings with Salaries — Kaggle](https://www.kaggle.com/datasets/minmaxer/job-postings-with-salaries)

## Repository

[Afwans/DATA607-Project3](https://github.com/Afwans/DATA607-Project3)

Working branch: `Afwans-patch-1`
