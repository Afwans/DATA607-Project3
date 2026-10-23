# DATA 607 Project 3 — Job category classification (15 categories)

library(DBI)
library(RPostgres)
library(dplyr)
library(stringr)
library(readr)
library(tibble)

DB_NAME <- 'data607_project3'
DB_HOST <- 'localhost'
DB_PORT <- 5432
DB_USER <- 'postgres'
OUTPUT_DIR <- file.path('Data', 'SectorClassification')
WRITE_TO_POSTGRES <- TRUE

if (!dir.exists(OUTPUT_DIR)) dir.create(OUTPUT_DIR, recursive = TRUE)
password <- if (interactive() && requireNamespace('rstudioapi', quietly = TRUE) && rstudioapi::isAvailable()) {
  rstudioapi::askForPassword('Enter your PostgreSQL password')
} else Sys.getenv('PGPASSWORD', unset = '')
if (!nzchar(password)) stop('No PostgreSQL password supplied. Run in RStudio or set PGPASSWORD.')

con <- dbConnect(RPostgres::Postgres(), dbname = DB_NAME, host = DB_HOST,
                 port = DB_PORT, user = DB_USER, password = password)

tryCatch({
  jobs <- dbGetQuery(con, '
    SELECT jp.job_id, jp.title, jp.department, jp.description,
           dc.job_category_updated
    FROM public.job_posting jp
    LEFT JOIN public.data_science_classification dc ON dc.job_id = jp.job_id
  ')
  stopifnot(!anyDuplicated(jobs$job_id))


  title_rules <- tibble::tribble(
    ~sector, ~pattern,
    'Healthcare', 'board.certified.behavior.analyst|\\bbcba\\b|behavior analyst|nurs(e|ing)|physician|doctor|dentist|dental hygienist|pharmacist|pharmacy|therapist|occupational therapy|physical therapy|mental health|clinical|patient care|caregiver|home health|medical bill|medical cod|radiolog|paramedic|health economics|microbiolog',
    'Education', 'teacher|teaching|professor|faculty|instructor|school counselor|academic advisor|curriculum|school principal|education specialist|tutor|instructional design|special education|childcare|child care|early childhood|learning facilitator',
    'Finance & Accounting', 'accounts payable|accounts receivable|\\bfinance\\b|financial|\\bfp&a\\b|accountant|accounting|audit(or|ing)?|investment|investor relations|banking|\\bbank\\b|underwrit|actuar|\\btax\\b|bookkeep|credit risk|credit rating|credit analyst|treasury|loan officer|mortgage|payroll|billing|budget analyst|pricing analyst|revenue finance|insurance|portfolio analyst|wealth planning|fraud analyst|payment integrity|equity administration|trade support',
    'Legal & Government', 'attorney|lawyer|paralegal|legal counsel|litigation|compliance|regulatory|policy analyst|public safety|intelligence analyst|signals analyst|all.source analyst|government affairs|public facilities|public works|social work|social services|law enforcement|military police|contract analyst',
    'Business & Administration', 'human resources|\\bhris\\b|\\bhr\\b|recruiter|recruiting|talent acquisition|people operations|people insights|compensation analyst|benefits analyst|workforce management|\\bwfm\\b',
    'Real Estate & Property', 'real estate|property manag|leasing|appraisal|facilities analyst|facilities manager|realtor|realpoint',
    'Transportation & Logistics', 'truck driver|\\bcdl\\b|delivery driver|dispatcher|logistics|supply chain|warehouse|shipping|fleet|freight|forklift|transportation|inventory operations|inventory coordinator|materials analyst|material handler|demand planning|procurement|supply planning',
    'Construction & Skilled Trades', 'construction|electrician|plumb(er|ing)|\\bhvac\\b|carpenter|weld(er|ing)|maintenance technician|maintenance mechanic|building inspector|field service technician|equipment technician|housekeeper|seismic imaging',
    'Engineering & Manufacturing', 'mechanical engineer|civil engineer|electrical engineer|industrial engineer|manufactur|production engineer|quality control|quality engineer|machinist|assembly operator|structural engineer|vibration analyst|hardware engineer|semiconductor|robotics engineer|\\bqc failure\\b',
    'Technology', 'software engineer|software developer|software development|programmer|\\bcobol\\b|\\bdb2\\b|frontend|front.end|back.end|full.stack|web developer|devops|site reliability|cloud engineer|cyber|information assurance|incident response|it support|\\bi\\.?t\\.?\\b|systems administrator|systems analyst|business systems analyst|network engineer|\\bqa analyst\\b|applications development|application developer|application analyst|technical support|service desk|technical solutions|infrastructure operations|systems test|technology support|technology advisory|\\bservice(now)?\\b|platform engineer|data governance|data processing|\\berp\\b',
    'Science & Research', 'laboratory|\\blab\\b|biotech|biolog|chemist|chemistry|clinical research|research scientist|research analyst|research associate|agricultur|scientific|industry analyst|operations research',
    'Energy & Environment', 'solar|wind energy|renewable|utilities|\\butility\\b|energy policy|environment|sustainab|conservation|pollution control|oil and gas|power grid|energy analyst|energy market',
    'Creative & Media', 'graphic design|creative director|copywriter|video produc|journalis|photograph|animat|game design|content editor|content writer|content valuation|\\bux\\b|\\bui\\b|user experience design|media production',
    'Sales & Marketing', 'sales|marketing|account manager|account executive|business development|brand|public relations|social media|seo|sem|advertis|commerce analyst|ecommerce|growth analyst|growth strategy|revenue growth|customer success|client relationship|client service|client success|customer experience|customer behavior|programmatic',
    'Retail & Hospitality', 'retail|store manager|cashier|merchandis|chef|cook|restaurant|bartender|waiter|waitress|hotel|hospitality|food service|catering|barista|tourism|travel agent|customer service|customer support|customer care',
    'Business & Administration', 'business analyst|business operations|business process|operations analyst|operations manager|project analyst|project manager|project coordinator|program manager|program analyst|\\bpmo\\b|chief of staff|general manager|business consultant|consulting analyst|management consultant|strategy analyst|strategic initiatives|administrative|executive assistant|receptionist|office manager|operations coordinator|revenue operations|\\brevops\\b|go.to.market|\\bgtm\\b|business performance|change management|client operations|delivery analyst|performance analyst|acquisition support|contract management'
  )

  
  department_rules <- tibble::tribble(
    ~sector, ~pattern,
    'Healthcare', 'clinical|patient|healthcare|health care|nursing|pharmacy|medical|life sciences',
    'Education', 'education|academic|school|curriculum|instruction',
    'Finance & Accounting', 'finance|accounting|treasury|investment|capital formation|actuarial|credit|banking',
    'Legal & Government', 'legal|compliance|regulatory|government affairs|public safety|intelligence',
    'Business & Administration', 'human resources|people operations|talent|recruiting|compensation',
    'Real Estate & Property', 'real estate|property|facilities',
    'Transportation & Logistics', 'logistics|supply chain|warehouse|shipping|fleet|inventory|procurement',
    'Construction & Skilled Trades', 'construction|maintenance|skilled trades',
    'Engineering & Manufacturing', 'manufacturing|engineering|quality assurance|quality control',
    'Technology', 'information technology|\\bi\\.?t\\.?\\b|cyber|software|technical support|business technology|infrastructure|data engineering',
    'Science & Research', 'research|laboratory|biotech|\\br&d\\b',
    'Energy & Environment', 'energy|sustainability|environment|utilities',
    'Creative & Media', 'creative|design|media|editorial',
    'Sales & Marketing', 'marketing|sales|growth|commercial|brand|ecommerce',
    'Retail & Hospitality', 'retail|hospitality|restaurant|customer service',
    'Business & Administration', 'operations|strategy|business services|administration|consulting|project management'
  )


  description_rules <- tibble::tribble(
    ~sector, ~pattern,
    'Healthcare', 'direct patient care|clinical patient care|licensed registered nurse',
    'Education', 'classroom instruction|teach k.12 students|special education classroom',
    'Finance & Accounting', 'prepare financial statements|accounts payable and receivable|financial reporting and accounting',
    'Legal & Government', 'provide legal advice|regulatory compliance investigations',
    'Business & Administration', 'employee benefits administration|recruitment and onboarding',
    'Real Estate & Property', 'manage commercial properties|residential property management',
    'Transportation & Logistics', 'warehouse distribution operations|freight transportation management',
    'Construction & Skilled Trades', 'install and repair hvac|commercial plumbing installation',
    'Engineering & Manufacturing', 'manufacturing production line|mechanical engineering design',
    'Technology', 'develop and maintain software applications|network security operations',
    'Science & Research', 'laboratory research experiments|conduct scientific experiments',
    'Energy & Environment', 'renewable energy development|environmental impact assessment',
    'Creative & Media', 'video production and editing|graphic design assets',
    'Sales & Marketing', 'develop marketing campaigns|manage sales pipeline',
    'Retail & Hospitality', 'restaurant guest service|retail store operations',
    'Business & Administration', 'business process improvement|project management office'
  )

  
  compile_rules <- function(tbl) {
    tbl %>% mutate(pattern = paste0('(?i)(?:', pattern, ')'))
  }

  priority_rules <- tibble::tribble(
    ~sector, ~pattern,
    'Technology', 'servicenow business analyst|information security analyst|technical infrastructure analyst|financial systems analyst(?=.{0,35}technology)|erp functional analyst|applications analyst|analyst, applications|systems analyst, hr and payroll|product analyst \\(systems\\)|qa laboratory systems analyst',
    'Finance & Accounting', 'financial systems analyst|accounting systems analyst|senior financial analyst|financial analyst senior|equity trade|credit ratings|enterprise risk|third.party risk|risk & audit|material cost analyst|customer economics|rating analyst|etf analyst',
    'Healthcare', 'health economics|clinical trial budget analyst',
    'Science & Research', 'microbiological analyst|baseball analytics|operations research',
    'Energy & Environment', 'gas scheduling analyst|energy industry data|pollution control analyst|market analyst, modeling \\(caiso|market analyst, research \\(us\\)',
    'Engineering & Manufacturing', 'manufacturing operations analyst|business analyst, manufacturing',
    'Sales & Marketing', 'marketing operations analyst|sales operations analyst|customer success operations analyst|client success strategy and operations analyst',
    'Real Estate & Property', 'realpoint project analyst',
    'Business & Administration', 'operations analytics|business controls analyst|senior agile analyst|product analyst co.op|business analyst \\(sales contracts\\)'
  )
  priority_rules <- compile_rules(priority_rules)
  title_rules <- compile_rules(title_rules)
  department_rules <- compile_rules(department_rules)
  description_rules <- compile_rules(description_rules)

  find_matches <- function(value, rules) {
    if (length(value) != 1 || is.na(value) || !nzchar(trimws(value))) return(character())
    unique(rules$sector[vapply(rules$pattern, function(p) str_detect(value, p), logical(1))])
  }
  classify_one <- function(title, department, description, curated_ds) {
    result <- function(sector, method, review, matches) {
      list(sector_name = sector, classification_method = method,
           needs_review = review, matched_sectors = paste(matches, collapse = ' | '))
    }
    if (!is.na(curated_ds) && nzchar(trimws(curated_ds))) {
      return(result('Technology', 'curated_data_science', FALSE, 'Data Science & AI'))
    }
    pm <- find_matches(title, priority_rules)
    if (length(pm) == 1) return(result(pm[1], 'priority_title_rule', TRUE, pm))
    if (length(pm) > 1) return(result('Other / Needs Review', 'ambiguous_priority_rule', TRUE, pm))
    tm <- find_matches(title, title_rules)
    dm <- find_matches(department, department_rules)
    if (length(tm) == 1) return(result(tm[1], 'title_rule', FALSE, tm))
    if (length(tm) > 1) {
      overlap <- intersect(tm, dm)
      if (length(overlap) == 1) return(result(overlap[1], 'title_department_disambiguated', TRUE, tm))
      return(result('Other / Needs Review', 'ambiguous_title_rule', TRUE, tm))
    }
    if (length(dm) == 1) return(result(dm[1], 'department_rule', TRUE, dm))
    if (length(dm) > 1) return(result('Other / Needs Review', 'ambiguous_department', TRUE, dm))
    sm <- find_matches(description, description_rules)
    if (length(sm) == 1) return(result(sm[1], 'description_fallback', TRUE, sm))
    if (length(sm) > 1) return(result('Other / Needs Review', 'ambiguous_description', TRUE, sm))
    result('Other / Needs Review', 'no_rule_match', TRUE, character())
  }

  classified_list <- lapply(seq_len(nrow(jobs)), function(i) {
    classify_one(jobs$title[i], jobs$department[i], jobs$description[i], jobs$job_category_updated[i])
  })
  classified <- bind_cols(jobs, bind_rows(classified_list)) %>%
    mutate(needs_review = as.logical(needs_review))
  curated_count <- sum(!is.na(jobs$job_category_updated) & nzchar(trimws(jobs$job_category_updated)))
  stopifnot(nrow(classified) == nrow(jobs), !anyDuplicated(classified$job_id),
            sum(classified$classification_method == 'curated_data_science') == curated_count,
            all(classified$sector_name[classified$classification_method == 'curated_data_science'] == 'Technology'))

  summary_tbl <- classified %>% count(sector_name, sort = TRUE, name = 'job_count') %>%
    mutate(share_percent = round(100 * job_count / sum(job_count), 2))
  method_tbl <- classified %>% count(classification_method, needs_review, sort = TRUE)
  review_tbl <- classified %>% filter(needs_review) %>%
    select(job_id, title, department, sector_name, classification_method, matched_sectors)
  analyst_review_tbl <- classified %>%
    filter(str_detect(coalesce(title, ''), regex('analyst|analyste', ignore_case = TRUE))) %>%
    select(job_id, title, department, sector_name, classification_method, needs_review, matched_sectors)
  # Candidate screening is NOT a change to the curated 229-job DS cohort.
  ds_candidate_tbl <- classified %>%
    filter(classification_method != 'curated_data_science') %>%
    filter(str_detect(coalesce(title, ''), regex(
      'data analy(st|tics)|data scientist|machine learning|artificial intelligence|\\bai\\b|data integrity|analytics engineer|statistical analyst|operations analytics|data governance',
      ignore_case = TRUE))) %>%
    mutate(ds_candidate_reason = 'Title keyword: review description and required skills') %>%
    select(job_id, title, department, sector_name, classification_method,
           needs_review, ds_candidate_reason)
  export_data <- classified %>% select(job_id, sector_name, classification_method, needs_review)

  # Save a V2 snapshot for direct V2 vs V3 comparison if present.
  previous_path <- file.path(OUTPUT_DIR, 'job_sector_classification.csv')
  if (file.exists(previous_path)) {
    previous <- read_csv(previous_path, show_col_types = FALSE) %>%
      select(job_id, old_sector = sector_name)
    comparison_tbl <- export_data %>%
      left_join(previous, by = 'job_id') %>%
      filter(!is.na(old_sector), old_sector != sector_name) %>%
      count(old_sector, sector_name, sort = TRUE, name = 'changed_jobs')
    write_csv(comparison_tbl, file.path(OUTPUT_DIR, 'v2_to_v3_category_changes.csv'))
    cat('Changed categories vs prior CSV:', sum(comparison_tbl$changed_jobs), '\n')
  }
  write_csv(export_data, file.path(OUTPUT_DIR, 'job_sector_classification.csv'))
  write_csv(summary_tbl, file.path(OUTPUT_DIR, 'sector_summary.csv'))
  write_csv(method_tbl, file.path(OUTPUT_DIR, 'classification_methods.csv'))
  write_csv(review_tbl, file.path(OUTPUT_DIR, 'sector_review_queue.csv'))
  write_csv(analyst_review_tbl, file.path(OUTPUT_DIR, 'analyst_classification_review.csv'))
  write_csv(ds_candidate_tbl, file.path(OUTPUT_DIR, 'data_science_candidate_review.csv'))

  cat('\nTotal jobs:', nrow(classified), '\nCurated Data Science jobs:', curated_count,
      '\nNeeds review:', sum(classified$needs_review),
      '\nPotential additional DS candidates (review only):', nrow(ds_candidate_tbl),
      '\nAnalyst titles still Other:', sum(analyst_review_tbl$sector_name == 'Other / Needs Review'), '\n\n')
  print(as.data.frame(summary_tbl))
  print(as.data.frame(method_tbl))

  if (isTRUE(WRITE_TO_POSTGRES)) {
    id_type <- dbGetQuery(con, "
      SELECT format_type(a.atttypid, a.atttypmod) AS sql_type
      FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = 'job_posting'
        AND a.attname = 'job_id' AND a.attnum > 0 AND NOT a.attisdropped
    ")$sql_type
    if (length(id_type) != 1 || !grepl('^(character varying|character|text|uuid|bigint|integer|smallint)', id_type)) {
      stop('Cannot safely determine job_posting.job_id SQL type; database not changed.')
    }
    dbWithTransaction(con, {
      dbExecute(con, paste0('
        CREATE TABLE IF NOT EXISTS public.job_sector_classification (
          job_id ', id_type, ' PRIMARY KEY REFERENCES public.job_posting(job_id),
          sector_name TEXT NOT NULL,
          classification_method TEXT NOT NULL,
          needs_review BOOLEAN NOT NULL DEFAULT FALSE
        )'))
      dbExecute(con, 'DELETE FROM public.job_sector_classification')
      dbWriteTable(con, Id(schema = 'public', table = 'job_sector_classification'),
                   export_data, append = TRUE, row.names = FALSE)
      actual <- dbGetQuery(con, 'SELECT COUNT(*) AS n FROM public.job_sector_classification')$n[1]
      if (as.numeric(actual) != nrow(jobs)) stop('Row-count mismatch; transaction rolled back.')
    })
    message('PostgreSQL classification table refreshed successfully.')
  } else {
    message('PREVIEW ONLY: CSV files created; PostgreSQL was NOT modified.')
  }
}, finally = {
  if (dbIsValid(con)) dbDisconnect(con)
})
