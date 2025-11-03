# dashboard.R
#
# An interactive dashboard to explore the results of the NESO Frequency Analysis pipeline.
# To run:
# 1. Open R/RStudio in this project directory.
# 2. Run the command: shiny::runApp('dashboard.R')

# --- 1. Load Dependencies ---
suppressPackageStartupMessages({
  library(shiny)
  library(shinydashboard)
  library(data.table)
  library(plotly)
  library(ggplot2)
  library(DT)
  library(lubridate)
  library(shinyjs)
  library(scales)
  library(yaml)
})

# --- 2. Load Configuration ---
config <- read_yaml("config/config.yml")

# --- Helper function for styling value boxes ---
valueBoxSpark <- function(value, title, subtitle, icon, color) {
  div(class = "col-sm-4",
      div(class = paste0("small-box bg-", color)),
      div(class = "inner",
          h3(value),
          p(title)
      ),
      div(class = "icon", icon(icon, lib = "font-awesome"))
  )
}


# ===================================================================
# UI (User Interface)
# Defines the layout and appearance of the dashboard.
# ===================================================================
ui <- dashboardPage(
  skin = "red",
  dashboardHeader(title = "NESO Frequency Analysis"),
  
  # --- Sidebar Navigation ---
  dashboardSidebar(
    sidebarMenu(
      menuItem("Overview", tabName = "overview", icon = icon("dashboard")),
      menuItem("SP Boundary Events", tabName = "explorer", icon = icon("search")),
      menuItem("Frequency & ROCOF", tabName = "frequency", icon = icon("wave-square")),
      menuItem("Frequency KPI", tabName = "kpi", icon = icon("clipboard-check")),
      menuItem("Frequency Excursion", tabName = "excursion", icon = icon("bolt")),
      menuItem("Monthly Red Ratio", tabName = "plots", icon = icon("chart-line"))
    )
  ),
  
  # --- Main Body Content ---
  dashboardBody(
    useShinyjs(), # Enable shinyjs for loading indicators
    tabItems(
      # -- Overview Tab --
      tabItem(tabName = "overview",
              # Key Settings Panel
              fluidRow(
                box(
                  title = "Configuration Parameters", status = "primary", solidHeader = TRUE, width = 12,
                  collapsible = TRUE, collapsed = FALSE,
                  fluidRow(
                    column(6,
                           tags$h4(style = "margin-top: 0; color: #3c8dbc;", "Event Detection Thresholds"),
                           tags$div(
                             style = "padding: 10px; background-color: #f9f9f9; border-radius: 5px;",
                             tags$table(
                               style = "width: 100%; border-collapse: collapse;",
                               tags$tr(
                                 tags$td(style = "padding: 5px; font-weight: bold;", "Analysis Window:"),
                                 tags$td(style = "padding: 5px;", uiOutput("configWindowSeconds"))
                               ),
                               tags$tr(
                                 tags$td(style = "padding: 5px; font-weight: bold; color: #d62728;", "RED Criteria:"),
                                 tags$td(style = "padding: 5px;", uiOutput("configRedCriteria"))
                               ),
                               tags$tr(
                                 tags$td(style = "padding: 5px; font-weight: bold; color: #ff7f0e;", "TUNING Criteria:"),
                                 tags$td(style = "padding: 5px;", "Mean |ROCOF| < 0.005 Hz/s AND SD(ROCOF) < 0.003 Hz/s")
                               ),
                               tags$tr(
                                 tags$td(style = "padding: 5px; font-weight: bold; color: #2ca02c;", "GREEN Criteria:"),
                                 tags$td(style = "padding: 5px;", "All other events")
                               )
                             )
                           )
                    ),
                    column(6,
                           tags$h4(style = "margin-top: 0; color: #3c8dbc;", "Frequency KPI Thresholds"),
                           tags$div(
                             style = "padding: 10px; background-color: #f9f9f9; border-radius: 5px;",
                             tags$table(
                               style = "width: 100%; border-collapse: collapse;",
                               tags$tr(
                                 tags$td(style = "padding: 5px; font-weight: bold; color: #d62728;", "RED:"),
                                 tags$td(style = "padding: 5px;", uiOutput("configKpiRed"))
                               ),
                               tags$tr(
                                 tags$td(style = "padding: 5px; font-weight: bold; color: #ff7f0e;", "AMBER:"),
                                 tags$td(style = "padding: 5px;", uiOutput("configKpiAmber"))
                               ),
                               tags$tr(
                                 tags$td(style = "padding: 5px; font-weight: bold; color: #1f77b4;", "BLUE:"),
                                 tags$td(style = "padding: 5px;", uiOutput("configKpiBlue"))
                               ),
                               tags$tr(
                                 tags$td(style = "padding: 5px; font-weight: bold; color: #2ca02c;", "GREEN:"),
                                 tags$td(style = "padding: 5px;", "All other readings (acceptable performance)")
                               )
                             )
                           )
                    )
                  )
                )
              ),

              # Time Filter Section
              fluidRow(
                box(
                  title = "Filter Summary Period", status = "warning", solidHeader = TRUE, width = 12,
                  fluidRow(
                    column(3,
                           radioButtons("overviewFilterMode", "Filter By:",
                                        choices = c("Date Range" = "date_range", "Month" = "month"),
                                        selected = "date_range")
                    ),
                    column(4,
                           conditionalPanel(
                             condition = "input.overviewFilterMode == 'date_range'",
                             dateInput("overviewStartDate", "Start Date:", value = Sys.Date() - 90),
                             dateInput("overviewEndDate", "End Date:", value = Sys.Date())
                           ),
                           conditionalPanel(
                             condition = "input.overviewFilterMode == 'month'",
                             selectInput("overviewMonthFilter", "Select Month:", choices = NULL, multiple = FALSE)
                           )
                    ),
                    column(2,
                           br(),
                           actionButton("updateOverview", "Update Summary", icon = icon("refresh"),
                                        style = "margin-top: 5px; width: 100%;")
                    )
                  )
                )
              ),

              # Summary Statistics Row
              fluidRow(
                # Event Detection Summary
                column(4,
                       box(
                         title = "SP Boundary Events Summary", status = "danger", solidHeader = TRUE, width = NULL,
                         uiOutput("eventSummaryUI")
                       )
                ),
                # Frequency KPI Summary
                column(4,
                       box(
                         title = "Frequency KPI Summary", status = "info", solidHeader = TRUE, width = NULL,
                         uiOutput("kpiSummaryUI")
                       )
                ),
                # Data Coverage Summary
                column(4,
                       box(
                         title = "Data Coverage", status = "success", solidHeader = TRUE, width = NULL,
                         uiOutput("dataCoverageUI")
                       )
                )
              )
      ),
      
      # -- SP Boundary Events Tab --
      tabItem(tabName = "explorer",
              fluidRow(
                box(
                  title = "Event Category Definitions", status = "info", solidHeader = TRUE, width = 12,
                  collapsible = TRUE, collapsed = TRUE,
                  tags$div(
                    style = "padding: 10px;",
                    tags$p(strong("Each 30-minute Settlement Period (SP) boundary is analyzed for frequency disturbances:")),
                    tags$hr(),
                    tags$div(
                      style = "margin-bottom: 10px;",
                      tags$span(style = "color: #d62728; font-weight: bold;", "RED:"),
                      " Significant frequency disturbance",
                      tags$ul(
                        tags$li(strong("Criteria:"), " |Δf| > 0.1 Hz ", strong("AND"), " p99|ROCOF| > 0.01 Hz/s"),
                        tags$li("Indicates unexpected/problematic events requiring investigation")
                      )
                    ),
                    tags$div(
                      style = "margin-bottom: 10px;",
                      tags$span(style = "color: #ff7f0e; font-weight: bold;", "TUNING:"),
                      " Strategic frequency adjustment",
                      tags$ul(
                        tags$li(strong("Criteria:"), " Mean |ROCOF| < 0.005 Hz/s ", strong("AND"), " SD(ROCOF) < 0.003 Hz/s"),
                        tags$li("Slow, controlled frequency changes - intentional system tuning")
                      )
                    ),
                    tags$div(
                      style = "margin-bottom: 5px;",
                      tags$span(style = "color: #2ca02c; font-weight: bold;", "GREEN:"),
                      " Normal operation",
                      tags$ul(
                        tags$li(strong("Criteria:"), " All other events (below Red thresholds and not Tuning)"),
                        tags$li("Stable system behavior with acceptable frequency variations")
                      )
                    ),
                    tags$hr(),
                    tags$p(
                      style = "font-size: 12px; color: #666;",
                      strong("Note:"), " Analysis window = ±15 seconds around each SP boundary. ",
                      "Δf = max frequency - min frequency in window. ",
                      "p99|ROCOF| = 99th percentile of absolute Rate of Change of Frequency."
                    )
                  )
                )
              ),
              # Subtabs for Event Table and Event Plots
              fluidRow(
                box(
                  title = NULL, status = "primary", solidHeader = FALSE, width = 12,
                  tabsetPanel(
                    id = "eventExploreTabs",
                    # Subtab 1: Event Table
                    tabPanel(
                      title = "Event Table",
                      value = "event_table",
                      br(),
                      fluidRow(
                        column(12,
                               box(
                                 title = "Filters", status = "warning", solidHeader = TRUE, width = NULL,
                                 fluidRow(
                                   column(4, selectInput("categoryFilter", "Filter by Category:",
                                                         choices = c("All", "Red", "Tuning", "Green"), selected = "Red")),
                                   column(8, uiOutput("dateFilterUI"))
                                 )
                               )
                        )
                      ),
                      fluidRow(
                        column(12,
                               box(
                                 title = "Boundary Event Details", status = "primary", solidHeader = TRUE, width = NULL,
                                 DT::dataTableOutput("eventsTable")
                               )
                        )
                      )
                    ),
                    # Subtab 2: Event Plots
                    tabPanel(
                      title = "Event Plots",
                      value = "event_plots",
                      br(),
                      fluidRow(
                        column(12,
                               box(
                                 title = "Plot Selection Options", status = "warning", solidHeader = TRUE, width = NULL,
                                 fluidRow(
                                   column(3,
                                          selectInput("plotStrategy", "Selection Strategy:",
                                                    choices = c("All Red Events" = "all",
                                                              "Top N Events" = "top_N",
                                                              "Worst N (by Severity)" = "worst_N",
                                                              "Best N (by Severity)" = "best_N",
                                                              "Random N Events" = "random_N"),
                                                    selected = "worst_N")
                                   ),
                                   column(3,
                                          numericInput("plotCount", "Number of Events (N):",
                                                     value = 10, min = 1, max = 100, step = 1)
                                   ),
                                   column(3,
                                          selectInput("plotSortBy", "Sort By:",
                                                    choices = c("Severity Score" = "severity",
                                                              "Frequency Change" = "abs_freq_change",
                                                              "ROCOF p99" = "rocof_p99",
                                                              "Chronological" = "chronological"),
                                                    selected = "severity")
                                   ),
                                   column(3,
                                          div(style = "margin-top: 25px;",
                                              actionButton("updateEventPlots", "Load Plots",
                                                         class = "btn-primary",
                                                         style = "width: 100%;")
                                          )
                                   )
                                 )
                               )
                        )
                      ),
                      fluidRow(
                        column(12,
                               box(
                                 title = "Verification Plots Gallery", status = "primary", solidHeader = TRUE, width = NULL,
                                 uiOutput("eventPlotsGalleryUI")
                               )
                        )
                      )
                    )
                  )
                )
              )
      ),

      # -- Frequency & ROCOF Tab --
      tabItem(tabName = "frequency",
              fluidRow(
                box(
                  title = "Time Range & Granularity Controls", status = "warning", solidHeader = TRUE, width = 12,
                  fluidRow(
                    column(4,
                           uiOutput("freqDateRangeUI")
                    ),
                    column(4,
                           selectInput("timeGranularity", "Time Granularity:",
                                      choices = list(
                                        "1 Day" = "1 day",
                                        "12 Hours" = "12 hours",
                                        "6 Hours" = "6 hours",
                                        "1 Hour" = "1 hour",
                                        "5 Minutes" = "5 mins",
                                        "1 Minute" = "1 min"
                                      ),
                                      selected = "1 hour")
                    ),
                    column(4,
                           div(style = "margin-top: 25px;",
                               actionButton("updateFreqPlot", "Update Plot",
                                          class = "btn-primary",
                                          style = "width: 100%;")
                           ),
                           br(),
                           div(style = "margin-top: 10px;",
                               checkboxInput("syncZoom", "Synchronized Zooming",
                                           value = TRUE,
                                           width = "100%"),
                               helpText("When enabled, zooming in one plot automatically zooms the other plot to the same time range.")
                           )
                    )
                  ),
                  br(),
                  div(id = "freq-loading", style = "display: none; text-align: center;",
                      h4("Loading data...", style = "color: #3c8dbc;"),
                      div(class = "progress progress-striped active",
                          div(class = "progress-bar", style = "width: 100%"))
                  )
                )
              ),
              # Time Series Plots
              fluidRow(
                column(12,
                  box(
                    title = "Frequency Time Series", status = "primary", solidHeader = TRUE, width = NULL,
                    plotlyOutput("frequencyPlot", height = "300px")
                  )
                )
              ),
              fluidRow(
                column(12,
                  box(
                    title = "ROCOF Time Series", status = "primary", solidHeader = TRUE, width = NULL,
                    plotlyOutput("rocofPlot", height = "300px")
                  )
                )
              )
      ),

      # -- Frequency KPI Tab --
      tabItem(tabName = "kpi",
              fluidRow(
                box(
                  title = "Filter Options", status = "warning", solidHeader = TRUE, width = 12,
                  fluidRow(
                    column(3,
                           radioButtons("kpiFilterMode", "Filter By:",
                                      choices = c("Date Range" = "date_range",
                                                "Month" = "month"),
                                      selected = "date_range")
                    ),
                    column(5,
                           # Date Range Filter (shown when mode = date_range)
                           conditionalPanel(
                             condition = "input.kpiFilterMode == 'date_range'",
                             uiOutput("kpiDateRangeUI")
                           ),
                           # Month Filter (shown when mode = month)
                           conditionalPanel(
                             condition = "input.kpiFilterMode == 'month'",
                             div(style = "margin-top: 25px;",
                                 selectInput("kpiMonthFilter", "Select Month:",
                                           choices = NULL,
                                           selected = NULL,
                                           multiple = FALSE)
                             )
                           )
                    ),
                    column(4,
                           div(style = "margin-top: 25px;",
                               actionButton("updateKPIPlots", "Update Plots",
                                          class = "btn-primary",
                                          style = "width: 100%;")
                           ),
                           br(),
                           helpText("Select filter mode and click 'Update Plots' to refresh visualizations.")
                    )
                  )
                )
              ),
              fluidRow(
                box(
                  title = "Quality Distribution by Settlement Period (Stacked Bar Chart)",
                  status = "primary", solidHeader = TRUE, width = 12,
                  plotlyOutput("kpiStackedBarPlot", height = "500px")
                )
              ),
              fluidRow(
                box(
                  title = "Red Percentage Heatmap (Date × Settlement Period)",
                  status = "danger", solidHeader = TRUE, width = 12,
                  plotlyOutput("kpiHeatmapPlot", height = "600px")
                )
              ),
              fluidRow(
                box(
                  title = "Daily Quality Metrics Time Series",
                  status = "info", solidHeader = TRUE, width = 12,
                  plotlyOutput("kpiTimeSeriesPlot", height = "500px")
                )
              )
      ),

      # -- Frequency Excursion Tab --
      tabItem(tabName = "excursion",
              fluidRow(
                box(
                  title = "Frequency Excursion Analysis", status = "info", solidHeader = TRUE, width = 12,
                  collapsible = TRUE, collapsed = TRUE,
                  tags$div(
                    style = "padding: 10px;",
                    tags$p("This tab tracks frequency excursions at multiple deviation thresholds from the nominal 50 Hz."),
                    tags$p(strong("Thresholds analyzed:"), " 0.1, 0.15, and 0.2 Hz"),
                    tags$p("An excursion occurs when the absolute deviation from 50 Hz (|f - 50|) exceeds the threshold, regardless of direction.")
                  )
                )
              ),

              # Filter Options
              fluidRow(
                box(
                  title = "Filter by Date Range", status = "warning", solidHeader = TRUE, width = 12,
                  fluidRow(
                    column(3,
                           dateInput("excursionStartDate", "Start Date:",
                                     value = as.Date("2025-05-01"),
                                     min = as.Date("2025-05-01"),
                                     max = as.Date("2025-08-31"))
                    ),
                    column(3,
                           dateInput("excursionEndDate", "End Date:",
                                     value = as.Date("2025-08-31"),
                                     min = as.Date("2025-05-01"),
                                     max = as.Date("2025-08-31"))
                    ),
                    column(3,
                           br(),
                           actionButton("updateExcursionPlots", "Update Plots",
                                        class = "btn-primary",
                                        style = "width: 100%;")
                    ),
                    column(3,
                           br(),
                           helpText("Select date range and click 'Update Plots' to refresh visualizations.")
                    )
                  )
                )
              ),

              # Plots
              fluidRow(
                box(
                  title = "Number of Excursions",
                  status = "primary", solidHeader = TRUE, width = 12,
                  plotlyOutput("excursionCountPlot", height = "450px")
                )
              ),
              fluidRow(
                box(
                  title = "Total Duration of Excursions",
                  status = "info", solidHeader = TRUE, width = 12,
                  plotlyOutput("excursionDailyDurationPlot", height = "500px")
                )
              )
      ),

      # -- Monthly Red Ratio Tab --
      tabItem(tabName = "plots",
              fluidRow(
                box(
                  title = "Monthly Red Event Ratio Plots", status = "info", solidHeader = TRUE, width = 12,
                  p("This section displays static plots showing the monthly Red event ratio trends - the percentage of SP boundaries that were classified as Red events each month."),
                  uiOutput("plotGalleryUI")
                )
              )
      )
    )
  )
)


# ===================================================================
# Server
# Defines the logic that powers the dashboard.
# ===================================================================
server <- function(input, output, session) {

  # --- Setup Resource Paths for Verification Plots ---
  addResourcePath("verification_plots", "data/verification")

  # --- Reactive Data Loading ---
  # This section reads the output files from your pipeline.
  
  # Reactive expression to load event data
  eventData <- reactive({
    fread("data/output/reports/sp_boundary_events.csv")
  })
  
  # Reactive expression to load monthly summary data
  monthlyData <- reactive({
    fread("data/output/reports/monthly_red_ratio_summary.csv")
  })
  
  # Reactive expression to load processed frequency data (lazy loading)
  frequencyData <- reactive({
    # Only load when needed and cache the result
    if (!exists("freq_data_cache", envir = .GlobalEnv)) {
      cat("Loading frequency data...\n")
      .GlobalEnv$freq_data_cache <- fread("data/processed/frequency_per_second_with_rocof.csv")
      .GlobalEnv$freq_data_cache[, dtm_sec := as.POSIXct(dtm_sec, tz = "UTC")]
      cat("Frequency data loaded:", nrow(.GlobalEnv$freq_data_cache), "rows\n")
    }
    return(.GlobalEnv$freq_data_cache)
  })

  # Reactive expression to load KPI monitoring data
  kpiData <- reactive({
    req(file.exists("data/output/reports/sp_category_percentages.csv"))
    dt <- fread("data/output/reports/sp_category_percentages.csv")
    dt[, date := as.Date(date)]
    return(dt)
  })

  # Reactive values for synchronized zooming
  plot_zoom <- reactiveValues(
    xmin = NULL,
    xmax = NULL,
    updating_from_frequency = FALSE,
    updating_from_rocof = FALSE
  )

  # --- Dynamic UI Elements ---
  output$dateFilterUI <- renderUI({
    df <- eventData()
    min_date <- min(as.Date(df$date), na.rm = TRUE)
    max_date <- max(as.Date(df$date), na.rm = TRUE)
    sliderInput("dateFilter", "Filter by Date Range:",
                min = min_date, max = max_date,
                value = c(min_date, max_date),
                width = "100%")
  })
  
  # Dynamic date range UI for frequency plots
  output$freqDateRangeUI <- renderUI({
    df <- frequencyData()
    min_datetime <- min(as.POSIXct(df$dtm_sec), na.rm = TRUE)
    max_datetime <- max(as.POSIXct(df$dtm_sec), na.rm = TRUE)
    
    # Default to last 24 hours for better performance
    default_start <- max(min_datetime, max_datetime - days(1))
    
    div(
      dateInput("freqStartDate", "Start Date:", 
                value = as.Date(default_start),
                min = as.Date(min_datetime),
                max = as.Date(max_datetime)),
      br(),
      dateInput("freqEndDate", "End Date:",
                value = as.Date(max_datetime),
                min = as.Date(min_datetime),
                max = as.Date(max_datetime))
    )
  })

  # Dynamic date range UI for KPI plots
  output$kpiDateRangeUI <- renderUI({
    df <- kpiData()
    min_date <- min(df$date, na.rm = TRUE)
    max_date <- max(df$date, na.rm = TRUE)

    # Default to last 30 days
    default_start <- max(min_date, max_date - days(30))

    div(
      dateInput("kpiStartDate", "Start Date:",
                value = default_start,
                min = min_date,
                max = max_date),
      br(),
      dateInput("kpiEndDate", "End Date:",
                value = max_date,
                min = min_date,
                max = max_date)
    )
  })

  # Populate month filter choices dynamically
  observe({
    df <- kpiData()
    # Extract unique months from the data
    df[, month_label := format(date, "%b %Y")]
    month_choices <- unique(df$month_label)
    # Sort by date
    month_order <- df[, .(first_date = min(date)), by = month_label][order(first_date)]
    month_choices_sorted <- month_order$month_label

    updateSelectInput(session, "kpiMonthFilter",
                     choices = month_choices_sorted,
                     selected = NULL)
  })

  # --- Overview Tab Logic ---

  # Display configuration parameters from config.yml
  output$configWindowSeconds <- renderUI({
    tags$span(paste0("±", config$parameters$event_detection$window_seconds, " seconds around SP boundary"))
  })

  output$configRedCriteria <- renderUI({
    delta_f <- config$parameters$event_detection$delta_f_hz
    rocof_p99 <- config$parameters$event_detection$rocof_p99_hz_s
    tags$span(paste0("|Δf| > ", delta_f, " Hz AND p99|ROCOF| > ", rocof_p99, " Hz/s"))
  })

  output$configKpiRed <- renderUI({
    freq_dev <- config$parameters$kpi_monitoring$freq_dev_red
    rocof_ref <- config$parameters$kpi_monitoring$rocof_ref_hz_s
    tags$span(paste0("Freq deviation > ", freq_dev, " Hz OR |ROCOF| > ", rocof_ref, " Hz/s"))
  })

  output$configKpiAmber <- renderUI({
    freq_dev <- config$parameters$kpi_monitoring$freq_dev_amber
    tags$span(paste0("Freq deviation > ", freq_dev, " Hz"))
  })

  output$configKpiBlue <- renderUI({
    freq_dev <- config$parameters$kpi_monitoring$freq_dev_blue
    tags$span(paste0("Freq deviation > ", freq_dev, " Hz"))
  })

  # Populate month filter choices for Overview
  observe({
    req(kpiData())
    df <- kpiData()
    df[, month_label := format(date, "%b %Y")]
    month_choices <- sort(unique(df$month_label), decreasing = TRUE)
    updateSelectInput(session, "overviewMonthFilter", choices = month_choices, selected = month_choices[1])
  })

  # Filtered data for Overview summaries
  filteredOverviewData <- eventReactive(input$updateOverview, {
    req(input$overviewFilterMode)

    # Get both event and KPI data
    event_df <- eventData()
    kpi_df <- kpiData()

    if (input$overviewFilterMode == "date_range") {
      req(input$overviewStartDate, input$overviewEndDate)
      event_filtered <- event_df[as.Date(date) >= input$overviewStartDate & as.Date(date) <= input$overviewEndDate]
      kpi_filtered <- kpi_df[date >= input$overviewStartDate & date <= input$overviewEndDate]
    } else if (input$overviewFilterMode == "month") {
      req(input$overviewMonthFilter)
      kpi_df[, month_label := format(date, "%b %Y")]
      kpi_filtered <- kpi_df[month_label == input$overviewMonthFilter]

      # For events, filter by the same month
      event_df[, month_label := format(date, "%b %Y")]
      event_filtered <- event_df[month_label == input$overviewMonthFilter]

      kpi_filtered[, month_label := NULL]
      event_filtered[, month_label := NULL]
    }

    list(events = event_filtered, kpi = kpi_filtered)
  }, ignoreNULL = FALSE)

  # Event Detection Summary
  output$eventSummaryUI <- renderUI({
    data <- filteredOverviewData()
    df <- data$events

    if (nrow(df) == 0) {
      return(tags$p("No event data available for selected period.", style = "color: #999; font-style: italic;"))
    }

    total <- nrow(df)
    red_count <- df[category == "Red", .N]
    tuning_count <- df[category == "Tuning", .N]
    green_count <- df[category == "Green", .N]

    red_pct <- red_count / total * 100
    tuning_pct <- tuning_count / total * 100
    green_pct <- green_count / total * 100

    tags$div(
      style = "padding: 10px;",
      tags$table(
        style = "width: 100%; border-collapse: collapse;",
        tags$tr(
          tags$td(style = "padding: 8px; font-weight: bold; border-bottom: 1px solid #ddd;", "Total Events:"),
          tags$td(style = "padding: 8px; text-align: right; border-bottom: 1px solid #ddd;", format(total, big.mark = ","))
        ),
        tags$tr(
          tags$td(style = "padding: 8px; color: #d62728; font-weight: bold;", "RED:"),
          tags$td(style = "padding: 8px; text-align: right;",
                  HTML(paste0(format(red_count, big.mark = ","), " (", sprintf("%.1f%%", red_pct), ")")))
        ),
        tags$tr(
          tags$td(style = "padding: 8px; color: #ff7f0e; font-weight: bold;", "TUNING:"),
          tags$td(style = "padding: 8px; text-align: right;",
                  HTML(paste0(format(tuning_count, big.mark = ","), " (", sprintf("%.1f%%", tuning_pct), ")")))
        ),
        tags$tr(
          tags$td(style = "padding: 8px; color: #2ca02c; font-weight: bold;", "GREEN:"),
          tags$td(style = "padding: 8px; text-align: right;",
                  HTML(paste0(format(green_count, big.mark = ","), " (", sprintf("%.1f%%", green_pct), ")")))
        )
      )
    )
  })

  # Frequency KPI Summary
  output$kpiSummaryUI <- renderUI({
    data <- filteredOverviewData()
    df <- data$kpi

    if (nrow(df) == 0) {
      return(tags$p("No KPI data available for selected period.", style = "color: #999; font-style: italic;"))
    }

    # KPI data structure: each row is a settlement period with percentage columns
    # Calculate average percentages across all settlement periods
    total_sps <- nrow(df)
    avg_red_pct <- mean(df$percentage_red, na.rm = TRUE)
    avg_amber_pct <- mean(df$percentage_amber, na.rm = TRUE)
    avg_blue_pct <- mean(df$percentage_blue, na.rm = TRUE)
    avg_green_pct <- mean(df$percentage_green, na.rm = TRUE)

    tags$div(
      style = "padding: 10px;",
      tags$table(
        style = "width: 100%; border-collapse: collapse;",
        tags$tr(
          tags$td(style = "padding: 8px; font-weight: bold; border-bottom: 1px solid #ddd;", "Settlement Periods:"),
          tags$td(style = "padding: 8px; text-align: right; border-bottom: 1px solid #ddd;", format(total_sps, big.mark = ","))
        ),
        tags$tr(
          tags$td(style = "padding: 8px; font-weight: bold; border-bottom: 1px solid #ddd;", colspan = "2", "Average Quality Distribution:")
        ),
        tags$tr(
          tags$td(style = "padding: 8px; color: #d62728; font-weight: bold;", "RED:"),
          tags$td(style = "padding: 8px; text-align: right;",
                  HTML(sprintf("%.2f%%", avg_red_pct)))
        ),
        tags$tr(
          tags$td(style = "padding: 8px; color: #ff7f0e; font-weight: bold;", "AMBER:"),
          tags$td(style = "padding: 8px; text-align: right;",
                  HTML(sprintf("%.2f%%", avg_amber_pct)))
        ),
        tags$tr(
          tags$td(style = "padding: 8px; color: #1f77b4; font-weight: bold;", "BLUE:"),
          tags$td(style = "padding: 8px; text-align: right;",
                  HTML(sprintf("%.2f%%", avg_blue_pct)))
        ),
        tags$tr(
          tags$td(style = "padding: 8px; color: #2ca02c; font-weight: bold;", "GREEN:"),
          tags$td(style = "padding: 8px; text-align: right;",
                  HTML(sprintf("%.2f%%", avg_green_pct)))
        )
      )
    )
  })

  # Data Coverage Summary
  output$dataCoverageUI <- renderUI({
    data <- filteredOverviewData()
    event_df <- data$events
    kpi_df <- data$kpi

    if (nrow(event_df) == 0 && nrow(kpi_df) == 0) {
      return(tags$p("No data available for selected period.", style = "color: #999; font-style: italic;"))
    }

    # Calculate date range
    all_dates <- c(event_df$date, as.POSIXct(kpi_df$date))
    date_min <- min(all_dates, na.rm = TRUE)
    date_max <- max(all_dates, na.rm = TRUE)
    date_range_days <- as.numeric(difftime(date_max, date_min, units = "days"))

    # Count unique days with data
    unique_days <- length(unique(as.Date(all_dates)))

    tags$div(
      style = "padding: 10px;",
      tags$table(
        style = "width: 100%; border-collapse: collapse;",
        tags$tr(
          tags$td(style = "padding: 8px; font-weight: bold;", "Date Range:"),
          tags$td(style = "padding: 8px; text-align: right;",
                  paste0(format(as.Date(date_min), "%d %b %Y"), " to ", format(as.Date(date_max), "%d %b %Y")))
        ),
        tags$tr(
          tags$td(style = "padding: 8px; font-weight: bold;", "Duration:"),
          tags$td(style = "padding: 8px; text-align: right;", paste(ceiling(date_range_days), "days"))
        ),
        tags$tr(
          tags$td(style = "padding: 8px; font-weight: bold;", "Days with Data:"),
          tags$td(style = "padding: 8px; text-align: right;", format(unique_days, big.mark = ","))
        ),
        tags$tr(
          tags$td(style = "padding: 8px; font-weight: bold; border-top: 1px solid #ddd;", "SP Boundaries:"),
          tags$td(style = "padding: 8px; text-align: right; border-top: 1px solid #ddd;", format(nrow(event_df), big.mark = ","))
        ),
        tags$tr(
          tags$td(style = "padding: 8px; font-weight: bold;", "Frequency Readings:"),
          tags$td(style = "padding: 8px; text-align: right;", format(nrow(kpi_df), big.mark = ","))
        )
      )
    )
  })

  # --- Event Explorer Tab Logic ---
  filteredEvents <- reactive({
    df <- eventData()
    
    # Apply category filter
    if (input$categoryFilter != "All") {
      df <- df[category == input$categoryFilter]
    }
    
    # Apply date filter (requires the UI to be ready)
    req(input$dateFilter)
    df <- df[as.Date(date) >= input$dateFilter[1] & as.Date(date) <= input$dateFilter[2]]
    
    return(df)
  })
  
  output$eventsTable <- DT::renderDataTable({
    datatable(filteredEvents(),
              options = list(pageLength = 10, scrollX = TRUE),
              rownames = FALSE,
              filter = 'top')
  })

  # --- Event Plots Logic ---

  # Select events for plotting based on user inputs
  selectedEventsForPlots <- eventReactive(input$updateEventPlots, {
    req(input$plotStrategy, input$plotSortBy)

    # Get Red events only (like the verification plots function)
    df <- eventData()
    red_events <- df[category == "Red"]

    if (nrow(red_events) == 0) {
      return(data.table())
    }

    # Apply sorting based on sort_by parameter
    if (input$plotSortBy == "severity") {
      setorder(red_events, -severity)
    } else if (input$plotSortBy == "abs_freq_change") {
      setorder(red_events, -abs_freq_change)
    } else if (input$plotSortBy == "rocof_p99") {
      setorder(red_events, -rocof_p99)
    } else if (input$plotSortBy == "chronological") {
      setorder(red_events, date, starting_sp)
    }

    # Apply selection strategy
    selected_events <- if (input$plotStrategy == "all") {
      red_events
    } else if (input$plotStrategy == "top_N") {
      head(red_events, input$plotCount)
    } else if (input$plotStrategy == "worst_N") {
      setorder(red_events, -severity)
      head(red_events, input$plotCount)
    } else if (input$plotStrategy == "best_N") {
      setorder(red_events, severity)
      head(red_events, input$plotCount)
    } else if (input$plotStrategy == "random_N") {
      if (nrow(red_events) <= input$plotCount) {
        red_events
      } else {
        sample_indices <- sample(nrow(red_events), input$plotCount)
        red_events[sample_indices]
      }
    } else {
      head(red_events, input$plotCount)
    }

    return(selected_events)
  }, ignoreNULL = FALSE)

  # Generate plots gallery UI
  output$eventPlotsGalleryUI <- renderUI({
    events <- selectedEventsForPlots()

    if (is.null(events) || nrow(events) == 0) {
      return(div(
        style = "text-align: center; margin: 50px;",
        h4("No Red events available", style = "color: #666;"),
        p("Either no Red events exist in the data, or plots haven't been generated yet."),
        p("Run the analysis pipeline to generate verification plots.")
      ))
    }

    # Create plot elements
    plot_ui_elements <- list()
    verification_dir <- "data/verification"

    for (i in seq_len(nrow(events))) {
      event <- events[i]

      # Create plot filename (matching the format from generate_verification_plots)
      # Note: boundary_time in CSV is UTC, but plots are saved with local time
      boundary_dt <- as.POSIXct(event$boundary_time, tz = "UTC")
      # Convert to local time (system timezone) to match plot filenames
      boundary_local <- format(boundary_dt, "%Y%m%d_%H%M", tz = Sys.timezone())
      plot_tag <- paste0(boundary_local, "_SP", event$starting_sp)
      plot_filename <- paste0("red_event_", plot_tag, ".png")
      plot_path <- file.path(verification_dir, plot_filename)

      # Create event title with metrics (using local time to match plot)
      event_title <- paste0(
        "Event #", i, ": ",
        format(boundary_dt, "%Y-%m-%d %H:%M", tz = Sys.timezone()),
        " (SP ", event$starting_sp, ")"
      )

      event_metrics <- paste0(
        "Δf = ", sprintf("%.3f", event$abs_freq_change), " Hz  |  ",
        "p99|ROCOF| = ", sprintf("%.6f", event$rocof_p99), " Hz/s  |  ",
        "Trend: ", event$trend, "  |  ",
        "Severity: ", sprintf("%.2f", event$severity)
      )

      if (file.exists(plot_path)) {
        # Plot exists - display it
        plot_ui_elements[[i]] <- div(
          style = "margin-bottom: 30px; border: 2px solid #ddd; border-radius: 5px; padding: 15px; background-color: #f9f9f9;",
          h4(event_title, style = "margin-top: 0; color: #d62728;"),
          p(event_metrics, style = "font-size: 13px; color: #555; font-family: monospace;"),
          tags$img(src = paste0("verification_plots/", plot_filename),
                  width = "100%",
                  style = "border: 1px solid #ccc; border-radius: 3px;")
        )
      } else {
        # Plot doesn't exist - show message
        plot_ui_elements[[i]] <- div(
          style = "margin-bottom: 20px; border: 2px solid #f0ad4e; border-radius: 5px; padding: 15px; background-color: #fcf8e3;",
          h4(event_title, style = "margin-top: 0; color: #8a6d3b;"),
          p(event_metrics, style = "font-size: 13px; color: #555; font-family: monospace;"),
          div(
            style = "text-align: center; padding: 20px;",
            icon("exclamation-triangle", class = "fa-2x", style = "color: #f0ad4e;"),
            p(strong("Plot not found"), style = "margin-top: 10px; color: #8a6d3b;"),
            p(paste("Expected file:", plot_filename), style = "font-size: 11px; color: #999;")
          )
        )
      }
    }

    if (length(plot_ui_elements) == 0) {
      return(div(
        style = "text-align: center; margin: 50px;",
        h4("No plots selected", style = "color: #666;"),
        p("Adjust your selection criteria and click 'Load Plots'.")
      ))
    }

    # Add summary at the top
    summary_box <- div(
      style = "padding: 15px; background-color: #d9edf7; border: 1px solid #bce8f1; border-radius: 4px; margin-bottom: 20px;",
      strong(icon("info-circle"), " Summary:"),
      " Displaying ", strong(length(plot_ui_elements)), " verification plots",
      " (Strategy: ", strong(input$plotStrategy), ", Sort by: ", strong(input$plotSortBy), ")"
    )

    do.call(tagList, c(list(summary_box), plot_ui_elements))
  })

  # --- Frequency Excursion Tab Logic ---

  # Load excursion data
  excursionSummaryData <- reactive({
    req(file.exists("data/output/reports/frequency_excursion_summary.csv"))
    fread("data/output/reports/frequency_excursion_summary.csv")
  })

  # Load daily excursion data
  excursionDailyData <- reactive({
    req(file.exists("data/output/reports/frequency_excursion_daily.csv"))
    dt <- fread("data/output/reports/frequency_excursion_daily.csv")
    dt[, date := as.Date(date)]
    return(dt)
  })

  # Filtered data for Excursion plots
  filteredExcursionData <- eventReactive(input$updateExcursionPlots, {
    req(input$excursionStartDate, input$excursionEndDate)

    daily_df <- excursionDailyData()

    # Filter by date range
    daily_filtered <- daily_df[date >= input$excursionStartDate & date <= input$excursionEndDate]

    list(daily = daily_filtered)
  }, ignoreNULL = FALSE)

  # Plot 1: Number of Excursions - Daily Time Series
  output$excursionCountPlot <- renderPlotly({
    data <- filteredExcursionData()
    df <- data$daily

    if (nrow(df) == 0) {
      return(plotly_empty(type = "scatter", mode = "markers") %>%
               layout(title = "No data available for selected date range"))
    }

    # Split data by threshold
    df_01 <- df[threshold == 0.1]
    df_015 <- df[threshold == 0.15]
    df_02 <- df[threshold == 0.2]

    # Create plotly with single Y-axis
    p <- plot_ly()

    # Add 0.1 Hz line
    p <- p %>% add_trace(
      data = df_01,
      x = ~date,
      y = ~num_excursions,
      name = "0.1 Hz",
      type = "scatter",
      mode = "lines+markers",
      line = list(color = "#ff7f0e", width = 2),
      marker = list(size = 4),
      hovertemplate = paste0(
        "Date: %{x|%b %d, %Y}<br>",
        "0.1 Hz: %{y}<br>",
        "<extra></extra>"
      )
    )

    # Add 0.15 Hz line
    p <- p %>% add_trace(
      data = df_015,
      x = ~date,
      y = ~num_excursions,
      name = "0.15 Hz",
      type = "scatter",
      mode = "lines+markers",
      line = list(color = "#2ca02c", width = 2),
      marker = list(size = 4),
      hovertemplate = paste0(
        "Date: %{x|%b %d, %Y}<br>",
        "0.15 Hz: %{y}<br>",
        "<extra></extra>"
      )
    )

    # Add 0.2 Hz line
    p <- p %>% add_trace(
      data = df_02,
      x = ~date,
      y = ~num_excursions,
      name = "0.2 Hz",
      type = "scatter",
      mode = "lines+markers",
      line = list(color = "#1f77b4", width = 2),
      marker = list(size = 4),
      hovertemplate = paste0(
        "Date: %{x|%b %d, %Y}<br>",
        "0.2 Hz: %{y}<br>",
        "<extra></extra>"
      )
    )

    # Configure layout with single Y-axis
    p <- p %>% layout(
      title = "Number of Excursions",
      xaxis = list(title = "Date"),
      yaxis = list(title = "Number of Excursions"),
      legend = list(x = 0.5, y = -0.2, orientation = "h", xanchor = "center"),
      hovermode = "x unified"
    )

    return(p)
  })

  # Plot 2: Total Duration - Daily Time Series
  output$excursionDailyDurationPlot <- renderPlotly({
    data <- filteredExcursionData()
    df <- data$daily

    if (nrow(df) == 0) {
      return(plotly_empty(type = "scatter", mode = "markers") %>%
               layout(title = "No data available for selected date range"))
    }

    # Split data by threshold
    df_01 <- df[threshold == 0.1]
    df_015 <- df[threshold == 0.15]
    df_02 <- df[threshold == 0.2]

    # Create plotly with single Y-axis
    p <- plot_ly()

    # Add 0.1 Hz line
    p <- p %>% add_trace(
      data = df_01,
      x = ~date,
      y = ~total_duration_sec,
      name = "0.1 Hz",
      type = "scatter",
      mode = "lines+markers",
      line = list(color = "#ff7f0e", width = 2),
      marker = list(size = 4),
      hovertemplate = paste0(
        "Date: %{x|%b %d, %Y}<br>",
        "0.1 Hz: %{y} sec<br>",
        "<extra></extra>"
      )
    )

    # Add 0.15 Hz line
    p <- p %>% add_trace(
      data = df_015,
      x = ~date,
      y = ~total_duration_sec,
      name = "0.15 Hz",
      type = "scatter",
      mode = "lines+markers",
      line = list(color = "#2ca02c", width = 2),
      marker = list(size = 4),
      hovertemplate = paste0(
        "Date: %{x|%b %d, %Y}<br>",
        "0.15 Hz: %{y} sec<br>",
        "<extra></extra>"
      )
    )

    # Add 0.2 Hz line
    p <- p %>% add_trace(
      data = df_02,
      x = ~date,
      y = ~total_duration_sec,
      name = "0.2 Hz",
      type = "scatter",
      mode = "lines+markers",
      line = list(color = "#1f77b4", width = 2),
      marker = list(size = 4),
      hovertemplate = paste0(
        "Date: %{x|%b %d, %Y}<br>",
        "0.2 Hz: %{y} sec<br>",
        "<extra></extra>"
      )
    )

    # Configure layout with single Y-axis
    p <- p %>% layout(
      title = "Total Duration of Excursions",
      xaxis = list(title = "Date"),
      yaxis = list(title = "Duration (seconds)"),
      legend = list(x = 0.5, y = -0.2, orientation = "h", xanchor = "center"),
      hovermode = "x unified"
    )

    return(p)
  })

  # --- Monthly Red Ratio Tab Logic ---
  output$plotGalleryUI <- renderUI({
    # Define the expected plot files
    plot_files <- c(
      "red_ratio_monthly_all_years_faceted.png",
      "red_ratio_monthly_overlay.png"
    )
    
    # Add individual year plots dynamically
    df <- monthlyData()
    years <- unique(df$year)
    for (yr in years) {
      plot_files <- c(plot_files, paste0("red_ratio_monthly_", yr, ".png"))
    }
    
    # Create UI elements for each existing plot
    plot_ui_elements <- list()
    
    for (i in seq_along(plot_files)) {
      plot_path <- file.path("data/output/plots", plot_files[i])
      if (file.exists(plot_path)) {
        plot_title <- switch(
          plot_files[i],
          "red_ratio_monthly_all_years_faceted.png" = "All Years (Faceted View)",
          "red_ratio_monthly_overlay.png" = "All Years (Overlay View)",
          paste("Individual Year:", gsub("red_ratio_monthly_(\\d+)\\.png", "\\1", plot_files[i]))
        )
        
        # Create plot display using alternative approach for Shiny
        tryCatch({
          # Try to use base64 encoding if available
          if (requireNamespace("base64enc", quietly = TRUE)) {
            plot_base64 <- base64enc::base64encode(plot_path)
            plot_ui_elements[[i]] <- div(
              style = "margin-bottom: 30px;",
              h4(plot_title),
              img(src = paste0("data:image/png;base64,", plot_base64), 
                  width = "100%", 
                  style = "border: 1px solid #ddd; border-radius: 5px; max-width: 800px;")
            )
          } else {
            # Fallback: Create plotly version or download link
            plot_ui_elements[[i]] <- div(
              style = "margin-bottom: 30px; text-align: center; padding: 20px; border: 1px solid #ddd; border-radius: 5px;",
              h4(plot_title),
              p("Static plot generated successfully", style = "color: #2c5aa0; font-size: 16px;"),
              p(paste("File:", basename(plot_path)), style = "color: #666; font-style: italic;"),
              p("View plot files in: data/output/plots/", style = "color: #666; font-size: 14px;"),
              br(),
              div(
                style = "background: #f8f9fa; padding: 10px; border-radius: 3px; margin-top: 10px;",
                strong("Plot Details:"),
                br(),
                "• File location: ", code(plot_path),
                br(),
                "• File exists: Yes",
                br(),
                "• Plot type: Monthly Red Ratio Analysis"
              )
            )
          }
        }, error = function(e) {
          # Error fallback
          plot_ui_elements[[i]] <- div(
            style = "margin-bottom: 30px;",
            h4(plot_title),
            div(
              style = "padding: 20px; background: #f8f9fa; border: 1px solid #ddd; border-radius: 5px;",
              p("Plot file generated: ", strong(basename(plot_path))),
              p("Location: ", code("data/output/plots/")),
              p("Open the file directly to view the plot.")
            )
          )
        })
      }
    }
    
    if (length(plot_ui_elements) == 0) {
      return(div(
        style = "text-align: center; margin: 50px;",
        h4("No plots available", style = "color: #666;"),
        p("Please run the analysis first to generate monthly red ratio plots."),
        p("Expected plots will appear here after running the pipeline.")
      ))
    }
    
    do.call(tagList, plot_ui_elements)
  })
  
  # --- Frequency & ROCOF Tab Logic ---
  
  # Helper function to intelligently sample data based on time range and granularity
  sampleFrequencyData <- function(df, start_time, end_time, granularity) {
    # Ensure datetime columns are properly formatted
    if (!"POSIXct" %in% class(df$dtm_sec)) {
      df[, dtm_sec := as.POSIXct(dtm_sec, tz = "UTC")]
    }
    
    # Filter by time range first
    filtered_df <- df[dtm_sec >= start_time & dtm_sec <= end_time]
    
    if (nrow(filtered_df) == 0) return(data.table())
    
    # Determine sampling strategy based on granularity and data size
    total_hours <- as.numeric(difftime(end_time, start_time, units = "hours"))
    
    if (granularity %in% c("1 min", "5 mins") && total_hours <= 2) {
      # For short periods and fine granularity, use all data
      return(filtered_df)
    } else if (granularity %in% c("1 hour", "6 hours") && total_hours <= 24) {
      # For medium periods, sample every 10-30 seconds
      sample_every <- max(1, round(nrow(filtered_df) / 5000))
      return(filtered_df[seq(1, nrow(filtered_df), by = sample_every)])
    } else {
      # For longer periods, aggregate to minutes or sample more aggressively
      sample_every <- max(1, round(nrow(filtered_df) / 3000))
      return(filtered_df[seq(1, nrow(filtered_df), by = sample_every)])
    }
  }
  
  # Reactive expression for filtered and sampled frequency data
  filteredFreqData <- eventReactive(input$updateFreqPlot, {
    req(input$freqStartDate, input$freqEndDate, input$timeGranularity)
    
    # Show loading indicator
    shinyjs::show("freq-loading")
    
    df <- frequencyData()
    
    # Create datetime range
    start_datetime <- as.POSIXct(paste(input$freqStartDate, "00:00:00"), tz = "UTC")
    end_datetime <- as.POSIXct(paste(input$freqEndDate, "23:59:59"), tz = "UTC")
    
    # Validate date range
    if (start_datetime >= end_datetime) {
      shinyjs::hide("freq-loading")
      return(data.table())
    }
    
    # Sample data intelligently
    sampled_data <- sampleFrequencyData(df, start_datetime, end_datetime, input$timeGranularity)
    
    # Hide loading indicator
    shinyjs::hide("freq-loading")
    
    return(sampled_data)
  }, ignoreNULL = FALSE)
  
  # Frequency plot
  output$frequencyPlot <- renderPlotly({
    df <- filteredFreqData()
    
    if (nrow(df) == 0) {
      p <- ggplot() + 
        annotate("text", x = 0.5, y = 0.5, label = "No data available for selected range", size = 6) +
        theme_void()
      return(ggplotly(p))
    }
    
    # Convert to proper datetime if needed
    df[, dtm_plot := as.POSIXct(dtm_sec)]
    
    p <- ggplot(df, aes(x = dtm_plot, y = f)) +
      geom_line(color = "#1f77b4", linewidth = 0.5) +
      scale_y_continuous(
        name = "Frequency (Hz)",
        limits = c(min(df$f, na.rm = TRUE) - 0.01, max(df$f, na.rm = TRUE) + 0.01)
      ) +
      scale_x_datetime(
        name = "Time",
        date_labels = "%H:%M",
        date_breaks = "2 hours"
      ) +
      theme_minimal(base_size = 11) +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1),
        panel.grid.minor.x = element_blank()
      ) +
      labs(title = NULL)
    
    freq_plot <- ggplotly(p, tooltip = c("x", "y"), source = "frequency_plot") %>%
      layout(
        xaxis = list(
          title = "Time",
          type = "date",
          tickformat = "%H:%M"
        ),
        yaxis = list(title = "Frequency (Hz)"),
        showlegend = FALSE
      )

    return(freq_plot)
  })
  
  # ROCOF plot  
  output$rocofPlot <- renderPlotly({
    df <- filteredFreqData()
    
    if (nrow(df) == 0) {
      p <- ggplot() + 
        annotate("text", x = 0.5, y = 0.5, label = "No data available for selected range", size = 6) +
        theme_void()
      return(ggplotly(p))
    }
    
    # Convert to proper datetime and handle missing ROCOF
    df[, dtm_plot := as.POSIXct(dtm_sec)]
    df_clean <- df[!is.na(rocof)]
    
    if (nrow(df_clean) == 0) {
      p <- ggplot() + 
        annotate("text", x = 0.5, y = 0.5, label = "No ROCOF data available", size = 6) +
        theme_void()
      return(ggplotly(p))
    }
    
    p <- ggplot(df_clean, aes(x = dtm_plot, y = rocof)) +
      geom_line(color = "#ff7f0e", linewidth = 0.5) +
      geom_hline(yintercept = 0, linetype = "dashed", color = "gray50", alpha = 0.7) +
      scale_y_continuous(
        name = "ROCOF (Hz/s)",
        limits = c(min(df_clean$rocof, na.rm = TRUE) - 0.001, 
                   max(df_clean$rocof, na.rm = TRUE) + 0.001)
      ) +
      scale_x_datetime(
        name = "Time",
        date_labels = "%H:%M", 
        date_breaks = "2 hours"
      ) +
      theme_minimal(base_size = 11) +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1),
        panel.grid.minor.x = element_blank()
      ) +
      labs(title = NULL)
    
    rocof_plot <- ggplotly(p, tooltip = c("x", "y"), source = "rocof_plot") %>%
      layout(
        xaxis = list(
          title = "Time",
          type = "date",
          tickformat = "%H:%M"
        ),
        yaxis = list(title = "ROCOF (Hz/s)"),
        showlegend = FALSE
      )

    return(rocof_plot)
  })

  # --- Synchronized Zooming Event Observers ---

  # Observe frequency plot zoom events and sync to ROCOF
  observe({
    if (!isTRUE(input$syncZoom)) return()  # Exit early if sync disabled

    freq_event <- event_data("plotly_relayout", source = "frequency_plot")

    if (!is.null(freq_event) && !plot_zoom$updating_from_rocof) {
      # Check if this is a zoom event (has xaxis.range)
      if ("xaxis.range[0]" %in% names(freq_event) && "xaxis.range[1]" %in% names(freq_event)) {
        plot_zoom$updating_from_frequency <- TRUE

        # Get range values - plotly returns them as strings
        xmin_raw <- freq_event[["xaxis.range[0]"]]
        xmax_raw <- freq_event[["xaxis.range[1]"]]

        # Try to parse as datetime string first, then as numeric milliseconds
        tryCatch({
          # Attempt to parse as ISO datetime string
          xmin_dt <- as.POSIXct(xmin_raw, tz = "UTC", format = "%Y-%m-%d %H:%M:%OS")
          xmax_dt <- as.POSIXct(xmax_raw, tz = "UTC", format = "%Y-%m-%d %H:%M:%OS")

          # If that fails (produces NA), try parsing as numeric milliseconds
          if (is.na(xmin_dt) || is.na(xmax_dt)) {
            xmin_dt <- as.POSIXct(as.numeric(xmin_raw) / 1000, origin = "1970-01-01", tz = "UTC")
            xmax_dt <- as.POSIXct(as.numeric(xmax_raw) / 1000, origin = "1970-01-01", tz = "UTC")
          }

          # Update ROCOF plot to match - just pass the datetime strings
          plotlyProxy("rocofPlot", session) %>%
            plotlyProxyInvoke("relayout", list(
              "xaxis.range" = c(xmin_raw, xmax_raw)
            ))

        }, error = function(e) {
          cat("Error in zoom sync:", e$message, "\n")
        })

        # Small delay before resetting flag
        later::later(function() {
          plot_zoom$updating_from_frequency <- FALSE
        }, delay = 0.1)
      }
      # Check for zoom reset (autoscale)
      else if ("xaxis.autorange" %in% names(freq_event) && freq_event[["xaxis.autorange"]]) {
        plot_zoom$updating_from_frequency <- TRUE

        # Reset ROCOF plot to autoscale
        plotlyProxy("rocofPlot", session) %>%
          plotlyProxyInvoke("relayout", list("xaxis.autorange" = TRUE))

        later::later(function() {
          plot_zoom$updating_from_frequency <- FALSE
        }, delay = 0.1)
      }
    }
  })

  # Observe ROCOF plot zoom events and sync to Frequency
  observe({
    if (!isTRUE(input$syncZoom)) return()  # Exit early if sync disabled

    rocof_event <- event_data("plotly_relayout", source = "rocof_plot")

    if (!is.null(rocof_event) && !plot_zoom$updating_from_frequency) {
      # Check if this is a zoom event
      if ("xaxis.range[0]" %in% names(rocof_event) && "xaxis.range[1]" %in% names(rocof_event)) {
        plot_zoom$updating_from_rocof <- TRUE

        # Get range values - plotly returns them as strings
        xmin_raw <- rocof_event[["xaxis.range[0]"]]
        xmax_raw <- rocof_event[["xaxis.range[1]"]]

        # Try to parse as datetime string first, then as numeric milliseconds
        tryCatch({
          # Attempt to parse as ISO datetime string
          xmin_dt <- as.POSIXct(xmin_raw, tz = "UTC", format = "%Y-%m-%d %H:%M:%OS")
          xmax_dt <- as.POSIXct(xmax_raw, tz = "UTC", format = "%Y-%m-%d %H:%M:%OS")

          # If that fails (produces NA), try parsing as numeric milliseconds
          if (is.na(xmin_dt) || is.na(xmax_dt)) {
            xmin_dt <- as.POSIXct(as.numeric(xmin_raw) / 1000, origin = "1970-01-01", tz = "UTC")
            xmax_dt <- as.POSIXct(as.numeric(xmax_raw) / 1000, origin = "1970-01-01", tz = "UTC")
          }

          # Update Frequency plot to match - just pass the datetime strings
          plotlyProxy("frequencyPlot", session) %>%
            plotlyProxyInvoke("relayout", list(
              "xaxis.range" = c(xmin_raw, xmax_raw)
            ))

        }, error = function(e) {
          cat("Error in zoom sync:", e$message, "\n")
        })

        later::later(function() {
          plot_zoom$updating_from_rocof <- FALSE
        }, delay = 0.1)
      }
      # Check for zoom reset
      else if ("xaxis.autorange" %in% names(rocof_event) && rocof_event[["xaxis.autorange"]]) {
        plot_zoom$updating_from_rocof <- TRUE

        # Reset Frequency plot to autoscale
        plotlyProxy("frequencyPlot", session) %>%
          plotlyProxyInvoke("relayout", list("xaxis.autorange" = TRUE))

        later::later(function() {
          plot_zoom$updating_from_rocof <- FALSE
        }, delay = 0.1)
      }
    }
  })

  # --- KPI Tab Logic ---

  # Filtered KPI data based on selected filter mode
  filteredKPIData <- eventReactive(input$updateKPIPlots, {
    req(input$kpiFilterMode)
    df <- kpiData()
    df_filtered <- df

    # Apply filter based on selected mode
    if (input$kpiFilterMode == "date_range") {
      # Date Range Mode
      req(input$kpiStartDate, input$kpiEndDate)
      df_filtered <- df[date >= input$kpiStartDate & date <= input$kpiEndDate]

    } else if (input$kpiFilterMode == "month") {
      # Month Mode
      req(input$kpiMonthFilter)
      df[, month_label := format(date, "%b %Y")]
      df_filtered <- df[month_label == input$kpiMonthFilter]
      df_filtered[, month_label := NULL]  # Remove temporary column
    }

    return(df_filtered)
  }, ignoreNULL = FALSE)

  # 1. Stacked Bar Chart - Quality Distribution by Settlement Period
  output$kpiStackedBarPlot <- renderPlotly({
    df <- filteredKPIData()

    if (nrow(df) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "No data available for selected range", size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Aggregate across all dates for each SP
    df_agg <- df[, .(
      avg_red = mean(percentage_red, na.rm = TRUE),
      avg_amber = mean(percentage_amber, na.rm = TRUE),
      avg_blue = mean(percentage_blue, na.rm = TRUE),
      avg_green = mean(percentage_green, na.rm = TRUE)
    ), by = settlement_period]

    # Reshape to long format
    df_long <- melt(df_agg, id.vars = "settlement_period",
                    variable.name = "category", value.name = "percentage")

    # Create labels for categories
    df_long[, category_label := fcase(
      category == "avg_red", "Red",
      category == "avg_amber", "Amber",
      category == "avg_blue", "Blue",
      category == "avg_green", "Green"
    )]

    # Create stacked bar chart
    p <- ggplot(df_long, aes(x = settlement_period, y = percentage, fill = category_label)) +
      geom_bar(stat = "identity") +
      scale_fill_manual(
        name = "Quality Category",
        values = c("Red" = "#d62728", "Amber" = "#ff7f0e", "Blue" = "#1f77b4", "Green" = "#2ca02c")
      ) +
      scale_x_continuous(breaks = seq(1, 48, by = 4)) +
      labs(
        title = NULL,
        x = "Settlement Period",
        y = "Average Percentage (%)"
      ) +
      theme_minimal(base_size = 11) +
      theme(legend.position = "bottom")

    ggplotly(p, tooltip = c("x", "y", "fill")) %>%
      layout(
        xaxis = list(title = "Settlement Period"),
        yaxis = list(title = "Average Percentage (%)"),
        legend = list(orientation = "h", x = 0.2, y = -0.15)
      )
  })

  # 2. Heatmap - Red Percentage by Date and Settlement Period
  output$kpiHeatmapPlot <- renderPlotly({
    df <- filteredKPIData()

    if (nrow(df) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "No data available for selected range", size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Create heatmap
    plot_ly(
      data = df,
      x = ~settlement_period,
      y = ~date,
      z = ~percentage_red,
      type = "heatmap",
      colors = colorRamp(c("#ffffcc", "#ffeda0", "#feb24c", "#fc4e2a", "#e31a1c", "#bd0026", "#800026")),
      colorbar = list(title = "Red %")
    ) %>%
      layout(
        title = NULL,
        xaxis = list(
          title = "Settlement Period",
          dtick = 4
        ),
        yaxis = list(
          title = "Date",
          autorange = "reversed"
        ),
        hovermode = "closest"
      )
  })

  # 3. Time Series - Daily Quality Metrics
  output$kpiTimeSeriesPlot <- renderPlotly({
    df <- filteredKPIData()

    if (nrow(df) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "No data available for selected range", size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Aggregate by date
    df_daily <- df[, .(
      avg_red = mean(percentage_red, na.rm = TRUE),
      avg_amber = mean(percentage_amber, na.rm = TRUE),
      avg_blue = mean(percentage_blue, na.rm = TRUE),
      avg_green = mean(percentage_green, na.rm = TRUE)
    ), by = date]

    # Reshape to long format
    df_long <- melt(df_daily, id.vars = "date",
                    variable.name = "category", value.name = "percentage")

    # Create labels
    df_long[, category_label := fcase(
      category == "avg_red", "Red",
      category == "avg_amber", "Amber",
      category == "avg_blue", "Blue",
      category == "avg_green", "Green"
    )]

    # Create time series plot
    p <- ggplot(df_long, aes(x = date, y = percentage, color = category_label, group = category_label)) +
      geom_line(linewidth = 1) +
      geom_point(size = 2, alpha = 0.6) +
      scale_color_manual(
        name = "Quality Category",
        values = c("Red" = "#d62728", "Amber" = "#ff7f0e", "Blue" = "#1f77b4", "Green" = "#2ca02c")
      ) +
      labs(
        title = NULL,
        x = "Date",
        y = "Average Daily Percentage (%)"
      ) +
      theme_minimal(base_size = 11) +
      theme(
        legend.position = "bottom",
        axis.text.x = element_text(angle = 45, hjust = 1)
      )

    ggplotly(p, tooltip = c("x", "y", "colour")) %>%
      layout(
        xaxis = list(title = "Date"),
        yaxis = list(title = "Average Daily Percentage (%)"),
        legend = list(orientation = "h", x = 0.2, y = -0.15)
      )
  })
}

# ===================================================================
# Run the Application
# ===================================================================
shinyApp(ui, server)