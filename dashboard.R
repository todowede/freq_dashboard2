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
  dashboardHeader(title = "Frequency KPI Dashboard"),

  # --- Sidebar Navigation ---
  dashboardSidebar(
    sidebarMenu(
      menuItem("Overview", tabName = "overview"),
      menuItem("SP Boundary Events", tabName = "explorer"),
      menuItem("Frequency & ROCOF", tabName = "frequency"),
      menuItem("Frequency KPI", tabName = "kpi"),
      menuItem("Frequency Excursion", tabName = "excursion"),
      menuItem("Response Holding", tabName = "response"),
      menuItem("Monthly Trends", tabName = "monthly_trends")
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
                    column(4,
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
                    column(4,
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
                    ),
                    column(4,
                           tags$h4(style = "margin-top: 0; color: #3c8dbc;", "Data Coverage"),
                           tags$div(
                             style = "padding: 10px; background-color: #f9f9f9; border-radius: 5px;",
                             tags$table(
                               style = "width: 100%; border-collapse: collapse;",
                               tags$tr(
                                 tags$td(style = "padding: 5px; font-weight: bold;", "Data Source:"),
                                 tags$td(style = "padding: 5px;", "data/input/fnew-*.csv")
                               ),
                               tags$tr(
                                 tags$td(style = "padding: 5px; font-weight: bold;", "Start Date:"),
                                 tags$td(style = "padding: 5px;", uiOutput("configDataStartDate"))
                               ),
                               tags$tr(
                                 tags$td(style = "padding: 5px; font-weight: bold;", "End Date:"),
                                 tags$td(style = "padding: 5px;", uiOutput("configDataEndDate"))
                               ),
                               tags$tr(
                                 tags$td(style = "padding: 5px; font-weight: bold;", "Total Months:"),
                                 tags$td(style = "padding: 5px;", uiOutput("configDataMonths"))
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
                  # Add style to prevent clipping of date picker dropdown
                  tags$style(HTML("
                    .box-body { overflow: visible !important; }
                    .datepicker { z-index: 9999 !important; }
                  ")),
                  fluidRow(
                    column(3,
                           radioButtons("overviewFilterMode", "Filter By:",
                                        choices = c("Date Range" = "date_range", "Month" = "month"),
                                        selected = "date_range")
                    ),
                    column(4,
                           conditionalPanel(
                             condition = "input.overviewFilterMode == 'date_range'",
                             dateInput("overviewStartDate", "Start Date:",
                                       value = as.Date("2025-01-01"),
                                       min = as.Date("2025-01-01"),
                                       max = as.Date("2025-09-30")),
                             dateInput("overviewEndDate", "End Date:",
                                       value = as.Date("2025-01-01"),
                                       min = as.Date("2025-01-01"),
                                       max = as.Date("2025-09-30"))
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
                column(6,
                       box(
                         title = "SP Boundary Events Summary", status = "danger", solidHeader = TRUE, width = NULL,
                         uiOutput("eventSummaryUI")
                       )
                ),
                column(6,
                       box(
                         title = "Frequency KPI Summary", status = "info", solidHeader = TRUE, width = NULL,
                         uiOutput("kpiSummaryUI")
                       )
                )
              )
      ),
      
      # -- SP Boundary Events Tab --
      tabItem(tabName = "explorer",
              fluidRow(
                box(
                  title = "Event Category Definitions", status = "info", solidHeader = TRUE, width = 12,
                  collapsible = TRUE, collapsed = FALSE,
                  tags$div(
                    style = "padding: 10px;",
                    tags$p(strong("Detects and classifies frequency disturbances at 30-minute settlement period boundaries.")),
                    tags$hr(),
                    tags$p("Analysis window = ±15 seconds around each SP boundary (configurable)."),
                    tags$p("Red criteria: Δf > 0.1 Hz AND p99|ROCOF| > 0.01 Hz/s; otherwise the event is labelled Green."),
                    tags$hr(),
                    tags$p(strong("Steps:")),
                    tags$ol(
                      tags$li("Load processed per-second dataset containing `dtm_sec`, `f`, and `rocof`."),
                      tags$li("Construct all SP boundaries covering the data range and add ±window (e.g. ±15 s) to define analysis windows."),
                      tags$li("Use a non-equi join to pull the per-second frequency/ROCOF samples inside each window."),
                      tags$li("For every boundary compute min_f, max_f, Δf = |max - min|, p99 of |ROCOF|, and severity inputs."),
                      tags$li("Compute severity for ranking/sorting = ((Δf / Δf threshold) + (p99|ROCOF| / ROCOF threshold))."),
                      tags$li("Classify events: Red if both Δf and p99 thresholds are exceeded; otherwise mark Green."),
                      tags$li("Save the output to `sp_boundary_events.csv` for downstream tabs.")
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
                      # Subtab 2b: Events Analysis
                      tabPanel(
                        title = "Imbalance",
                        value = "imbalance",
                      br(),
                      fluidRow(
                        column(12,
                                box(
                                  title = "Power Imbalance from Frequency Events", status = "info", solidHeader = TRUE, width = NULL,
                                  collapsible = TRUE, collapsed = FALSE,
                                  tags$div(
                                    style = "padding: 10px;",
                                    tags$p(strong("Inverse calculation of system imbalance from frequency deviations at SP boundaries.")),
                                    tags$p(strong("Formula: "), "Imbalance = -LF_response + Demand_damping + HF_response + RoCoF_component"),
                                    tags$hr(),
                                    tags$p(strong("Where:")),
                                    tags$ul(
                                      tags$li(strong("LF_response:"), " Low frequency response (Primary, Secondary, High, DR, DM)."),
                                      tags$li(strong("Demand_damping:"), " Natural demand change due to frequency (2.5% per Hz)."),
                                      tags$li(strong("HF_response:"), " High frequency response (for f > 50 Hz)."),
                                      tags$li(strong("RoCoF_component:"), " Rate-of-change contribution, e.g. 2H × df/dt.")
                                    ),
                                    tags$hr()
                                  )
                                )
                        )
                      ),
                      # Event Selection
                      fluidRow(
                        column(12,
                               box(
                                 title = "Select Event to Analyze", status = "warning", solidHeader = TRUE, width = NULL,
                                 fluidRow(
                                   column(4,
                                          selectInput("imbalanceEventFilter", "Filter Events:",
                                                      choices = c("All Red Events" = "all", "Top 10 Severity" = "top10", "Latest 10" = "latest10"),
                                                      selected = "top10")
                                   ),
                                   column(
                                     4,
                                     div(
                                       style = "display: flex; gap: 10px; padding-top: 25px;",
                                       actionButton("imbalancePrev", label = NULL, icon = icon("chevron-left"), class = "btn-default", width = "50%"),
                                       actionButton("imbalanceNext", label = NULL, icon = icon("chevron-right"), class = "btn-default", width = "50%")
                                     )
                                   ),
                                   column(
                                     4,
                                     uiOutput("imbalanceEventLabel")
                                   )
                                 )
                               )
                        )
                      ),
                      # Frequency & Imbalance Plots
                      fluidRow(
                        column(
                          6,
                          box(
                            title = "Frequency Event (±window around SP boundary)",
                            status = "warning",
                            solidHeader = TRUE,
                            width = NULL,
                            plotlyOutput("imbalanceFrequencyPlot", height = "380px")
                          )
                        ),
                        column(
                          6,
                          box(
                            title = "Power Imbalance Time Series",
                            status = "primary",
                            solidHeader = TRUE,
                            width = NULL,
                            plotlyOutput("imbalanceTimeSeriesPlot", height = "380px")
                          )
                        )
                      )
                    ),
                      tabPanel(
                        title = "Events Analysis",
                        value = "event_analysis",
                        br(),
                        fluidRow(
                          column(
                            12,
                            box(
                              title = "Analysis Controls",
                              status = "warning",
                              solidHeader = TRUE,
                              width = NULL,
                              fluidRow(
                                column(
                                  6,
                                  radioButtons(
                                    "eventAnalysisGranularity",
                                    "View",
                                    choices = c("SP" = "Daily",
                                                "Daily" = "MonthlyCalendar",
                                                "Weekly" = "Weekly",
                                                "Monthly Overview" = "Monthly"),
                                    inline = TRUE,
                                    selected = "Daily"
                                  )
                                ),
                                column(
                                  6,
                                  uiOutput("eventAnalysisSelector")
                                )
                              ),
                              helpText("Visualisations consider Red events only; SP axes show all 48 periods even when counts are zero.")
                            )
                          )
                        ),
                        conditionalPanel(
                          condition = "input.eventAnalysisGranularity == 'Weekly'",
                          fluidRow(
                            column(
                              6,
                              selectInput("eventWeeklyRangeStart", "Start Week:", choices = NULL)
                            ),
                            column(
                              6,
                              selectInput("eventWeeklyRangeEnd", "End Week:", choices = NULL)
                            )
                          )
                        ),
                        conditionalPanel(
                          condition = "input.eventAnalysisGranularity == 'MonthlyCalendar'",
                          fluidRow(
                            column(
                              12,
                              div(style = "margin-bottom: 10px;",
                                  checkboxInput("toggleRemitDiamonds", "Show REMIT trip markers", TRUE))
                            )
                          )
                        ),
                        conditionalPanel(
                          condition = "input.eventAnalysisGranularity != 'Daily'",
                          fluidRow(
                            column(
                              12,
                              box(
                                title = "",
                                status = "info",
                                solidHeader = TRUE,
                                width = NULL,
                                plotlyOutput("eventAnalysisPrimaryPlot", height = "320px")
                              )
                            )
                          )
                        ),
                        conditionalPanel(
                          condition = "input.eventAnalysisGranularity == 'Weekly'",
                          fluidRow(
                            column(
                              12,
                              box(
                                title = "Weekly Avg |Imbalance| (MW)",
                                status = "info",
                                solidHeader = TRUE,
                                width = NULL,
                                plotlyOutput("eventWeeklyImbalancePlot", height = "320px")
                              )
                            )
                          )
                        ),
                        conditionalPanel(
                          condition = "input.eventAnalysisGranularity == 'Daily'",
                          fluidRow(
                            column(
                              12,
                              box(
                                title = "SP Distribution",
                                status = "danger",
                                solidHeader = TRUE,
                                width = NULL,
                                plotlyOutput("eventAnalysisDailyPlot", height = "350px")
                              )
                            )
                          ),
                          fluidRow(
                            column(
                              12,
                              box(
                                title = "Forecast Absolute Error by Settlement Period",
                                status = "primary",
                                solidHeader = TRUE,
                                width = NULL,
                                plotlyOutput("eventAnalysisDailyDemandPlot", height = "320px")
                              )
                            )
                          )
                        ),
                        conditionalPanel(
                          condition = "input.eventAnalysisGranularity == 'Monthly'",
                          fluidRow(
                            column(
                              12,
                              box(
                                title = "Monthly Average Severity (Freq Deviation + ROCOF)",
                                status = "danger",
                                solidHeader = TRUE,
                                width = NULL,
                                plotlyOutput("eventAnalysisMonthlyMetricsPlot", height = "350px")
                              )
                            )
                            )
                          )
                        ),
                  )
                )
              )
      ),

      # -- Frequency & ROCOF Tab --
      tabItem(tabName = "frequency",
              fluidRow(
                box(
                  title = "Time Range & Granularity Controls", status = "warning", solidHeader = TRUE, width = 12,
                  # Add style to prevent clipping of date picker dropdown
                  tags$style(HTML("
                    .box-body { overflow: visible !important; }
                    .datepicker { z-index: 9999 !important; }
                  ")),
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
              # Subtabs for KPI Analysis and Static Monthly Red Ratio
              fluidRow(
                box(
                  title = NULL, status = "primary", solidHeader = FALSE, width = 12,
                  tabsetPanel(
                    id = "kpiTabs",
                    # Subtab 1: KPI Analysis
                    tabPanel(
                      title = "KPI Analysis",
                      value = "kpi_analysis",
                      br(),
                      fluidRow(
                        column(12,
                               box(
                                 title = "Filter Options", status = "warning", solidHeader = TRUE, width = NULL,
                                 # Add style to prevent clipping of date picker dropdown
                                 tags$style(HTML("
                                   .box-body { overflow: visible !important; }
                                   .datepicker { z-index: 9999 !important; }
                                 ")),
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
                        )
                      ),
                      fluidRow(
                        column(12,
                               box(
                                 title = "KPI Metrics",
                                 status = "info", solidHeader = TRUE, width = NULL,
                                 collapsible = TRUE, collapsed = FALSE,
                                 tags$div(
                                   style = "padding: 10px;",
                                   tags$p("Classifies frequency quality performance into four categories (RED, AMBER, BLUE, GREEN) based on deviation and ROCOF thresholds."),
                                   tags$hr(),
                                   tags$p(strong("KPI thresholds (from config.yml):")),
                                   tags$ul(
                                     tags$li(strong("Red:"), " |Δf| > ", config$parameters$kpi_monitoring$freq_dev_red,
                                             " Hz OR |ROCOF| > ", config$parameters$kpi_monitoring$rocof_ref_hz_s, " Hz/s"),
                                     tags$li(strong("Amber:"), " |Δf| > ", config$parameters$kpi_monitoring$freq_dev_amber,
                                             " Hz (when Red criteria not met)"),
                                     tags$li(strong("Blue:"), " |Δf| > ", config$parameters$kpi_monitoring$freq_dev_blue,
                                             " Hz (when Amber/Red criteria not met)"),
                                     tags$li(strong("Green:"), " Remaining seconds with |Δf| ≤ ", config$parameters$kpi_monitoring$freq_dev_blue,
                                             " Hz and |ROCOF| ≤ ", config$parameters$kpi_monitoring$rocof_ref_hz_s, " Hz/s")
                                   ),
                                   tags$hr(),
                                   tags$p(strong("Steps:")),
                                   tags$ol(
                                     tags$li("Load processed per-second dataset (`frequency_processor` output with `dtm_sec`, `f`, `rocof`)."),
                                     tags$li("Compute per-second frequency deviation |f−50| and classify each second using the thresholds above."),
                                     tags$li("Assign each timestamp to a date and settlement period (SP01–SP48)."),
                                     tags$li("Count seconds per category and convert to percentages for every SP."),
                                     tags$li("Save the SP-level percentages to `data/output/reports/sp_category_percentages.csv` for use in the KPI tab.")
                                   )
                                 )
                               )
                        )
                      ),
                      fluidRow(
                        column(12,
                               box(
                                 title = "Quality Distribution by Settlement Period (Stacked Bar Chart)",
                                 status = "primary", solidHeader = TRUE, width = NULL,
                                 plotlyOutput("kpiStackedBarPlot", height = "500px")
                               )
                        )
                      ),
                      fluidRow(
                        column(12,
                               box(
                                 title = "Daily Quality Metrics Time Series",
                                 status = "info", solidHeader = TRUE, width = NULL,
                                 plotlyOutput("kpiTimeSeriesPlot", height = "500px")
                               )
                        )
                      )
                    ),
                    # Subtab 2: Static Monthly Red Ratio
                    tabPanel(
                      title = "Static Monthly Red Ratio",
                      value = "static_monthly_red_ratio",
                      br(),
                      fluidRow(
                        column(12,
                               box(
                                 title = "Monthly Red Event Ratio Plots", status = "info", solidHeader = TRUE, width = NULL,
                                 p("This section displays static plots showing the monthly Red event ratio trends - the percentage of SP boundaries that were classified as Red events each month."),
                                 uiOutput("plotGalleryUI")
                               )
                        )
                      )
                    ),
                    tabPanel(
                      title = "Weekly",
                      value = "kpi_weekly",
                      br(),
                      fluidRow(
                        box(
                          title = "Weekly KPI Filters",
                          status = "warning",
                          solidHeader = TRUE,
                          width = 12,
                          tags$style(HTML("
                            .box-body { overflow: visible !important; }
                            .datepicker { z-index: 9999 !important; }
                          ")),
                          fluidRow(
                            column(4, uiOutput("kpiWeeklyDateRangeUI")),
                            column(4,
                                   br(),
                                   actionButton(
                                     "updateKpiWeeklyPlot",
                                     "Update Plot",
                                     class = "btn-primary",
                                     style = "width: 100%;"
                                   )
                            ),
                            column(4,
                                   checkboxGroupInput(
                                     "kpiWeeklyCategories",
                                     "Quality Categories:",
                                     choices = c("Red", "Amber", "Blue", "Green"),
                                     selected = c("Red", "Amber", "Blue", "Green"),
                                     inline = TRUE
                                   ),
                                   helpText("Choose which categories to display.")
                            )
                          )
                        )
                      ),
                      fluidRow(
                        box(
                          title = "Weekly Frequency KPI",
                          status = "primary",
                          solidHeader = TRUE,
                          width = 12,
                          plotlyOutput("weeklyQualityMetrics", height = "450px")
                        )
                      )
                    ),
                    tabPanel(
                      title = "Monthly",
                      value = "kpi_monthly",
                      br(),
                      fluidRow(
                        box(
                          title = "Monthly KPI Filters",
                          status = "warning",
                          solidHeader = TRUE,
                          width = 12,
                          tags$style(HTML("
                            .box-body { overflow: visible !important; }
                            .datepicker { z-index: 9999 !important; }
                          ")),
                          fluidRow(
                            column(4, uiOutput("kpiMonthlyDateRangeUI")),
                            column(4,
                                   br(),
                                   actionButton(
                                     "updateKpiMonthlyPlot",
                                     "Update Plot",
                                     class = "btn-primary",
                                     style = "width: 100%;"
                                   )
                            ),
                            column(4,
                                   checkboxGroupInput(
                                     "kpiMonthlyCategories",
                                     "Quality Categories:",
                                     choices = c("Red", "Amber", "Blue", "Green"),
                                     selected = c("Red", "Amber", "Blue", "Green"),
                                     inline = TRUE
                                   ),
                                   helpText("Use the checkboxes to show or hide specific categories.")
                            )
                          )
                        )
                      ),
                      fluidRow(
                        box(
                          title = "Monthly Frequency KPI",
                          status = "primary",
                          solidHeader = TRUE,
                          width = 12,
                          plotlyOutput("monthlyQualityMetrics", height = "450px")
                        )
                      )
                    ) 
                  )
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
              tabsetPanel(
                id = "excursionTabs",
                tabPanel(
                  title = "Daily View",
                  br(),
                  fluidRow(
                    box(
                      title = "Filter by Date Range", status = "warning", solidHeader = TRUE, width = 12,
                      tags$style(HTML("
                        .box-body { overflow: visible !important; }
                        .datepicker { z-index: 9999 !important; }
                      ")),
                      fluidRow(
                        column(3,
                               dateInput("excursionStartDate", "Start Date:",
                                         value = as.Date("2025-01-01"),
                                         min = as.Date("2025-01-01"),
                                         max = as.Date("2025-09-30"))
                        ),
                        column(3,
                               dateInput("excursionEndDate", "End Date:",
                                         value = as.Date("2025-01-01"),
                                         min = as.Date("2025-01-01"),
                                         max = as.Date("2025-09-30"))
                        ),
                        column(3,
                               checkboxGroupInput(
                                 "excursionThresholds",
                                 "Thresholds (Hz):",
                                 choices = c("0.10" = "0.1", "0.15" = "0.15", "0.20" = "0.2"),
                                 selected = c("0.1", "0.15", "0.2")
                               )
                        ),
                        column(3,
                               br(),
                               actionButton("updateExcursionPlots", "Update Plots",
                                            class = "btn-primary",
                                            style = "width: 100%;"),
                               br(),
                               helpText("Adjust date range or thresholds, then click 'Update Plots'.")
                        )
                      )
                    )
                  ),
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
                  ),
                  fluidRow(
                    box(
                      title = "Percentage of Time in Excursion",
                      status = "warning", solidHeader = TRUE, width = 12,
                      plotlyOutput("excursionPercentagePlot", height = "450px")
                    )
                  ),
                  fluidRow(
                    box(
                      title = "Frequency Deviation by Settlement Period",
                      status = "success", solidHeader = TRUE, width = 12,
                      plotlyOutput("excursionSPDeviationPlot", height = "450px")
                    )
                  )
                ),
                tabPanel(
                  title = "Monthly",
                  br(),
                  fluidRow(
                    box(
                      title = "Monthly Excursion Filters",
                      status = "warning",
                      solidHeader = TRUE,
                      width = 12,
                      tags$style(HTML("
                        .box-body { overflow: visible !important; }
                        .datepicker { z-index: 9999 !important; }
                      ")),
                      fluidRow(
                        column(3, uiOutput("excursionMonthlyStartUI")),
                        column(3, uiOutput("excursionMonthlyEndUI")),
                        column(4,
                               checkboxGroupInput(
                                 "excursionMonthlyThresholds",
                                 "Thresholds (Hz):",
                                 choices = c("0.10" = "0.1", "0.15" = "0.15", "0.20" = "0.2"),
                                 selected = c("0.1", "0.15", "0.2"),
                                 inline = TRUE
                               )
                        ),
                        column(2,
                               br(),
                               actionButton(
                                 "updateExcursionMonthly",
                                 "Update Monthly Plots",
                                 class = "btn-primary",
                                 style = "width: 100%;"
                               )
                        )
                      )
                    )
                  ),
                  fluidRow(
                    box(
                      title = "Monthly Excursion Count",
                      status = "primary",
                      solidHeader = TRUE,
                      width = 12,
                      plotlyOutput("excursionMonthlyCountPlot", height = "420px")
                    )
                  ),
                  fluidRow(
                    column(
                      width = 6,
                      box(
                        title = "Monthly Excursion Duration",
                        status = "info",
                        solidHeader = TRUE,
                        width = NULL,
                        plotlyOutput("excursionMonthlyDurationPlot", height = "420px")
                      )
                    ),
                    column(
                      width = 6,
                      box(
                        title = "Monthly Excursion Percentage",
                        status = "success",
                        solidHeader = TRUE,
                        width = NULL,
                        plotlyOutput("excursionMonthlyPercentagePlot", height = "420px")
                      )
                    )
                  )
                ),
                tabPanel(
                  title = "Weekly",
                  br(),
                  fluidRow(
                    box(
                      title = "Weekly Excursion Filters",
                      status = "warning",
                      solidHeader = TRUE,
                      width = 12,
                      tags$style(HTML("
                        .box-body { overflow: visible !important; }
                        .datepicker { z-index: 9999 !important; }
                      ")),
                      fluidRow(
                        column(3, uiOutput("excursionWeeklyStartUI")),
                        column(3, uiOutput("excursionWeeklyEndUI")),
                        column(4,
                               checkboxGroupInput(
                                 "excursionWeeklyThresholds",
                                 "Thresholds (Hz):",
                                 choices = c("0.10" = "0.1", "0.15" = "0.15", "0.20" = "0.2"),
                                 selected = c("0.1", "0.15", "0.2"),
                                 inline = TRUE
                               )
                        ),
                        column(2,
                               br(),
                               actionButton(
                                 "updateExcursionWeekly",
                                 "Update Weekly Plots",
                                 class = "btn-primary",
                                 style = "width: 100%;"
                               )
                        )
                      )
                    )
                  ),
                  fluidRow(
                    box(
                      title = "Weekly Excursion Count",
                      status = "primary",
                      solidHeader = TRUE,
                      width = 12,
                      plotlyOutput("excursionWeeklyCountPlot", height = "420px")
                    )
                  ),
                  fluidRow(
                    column(
                      width = 6,
                      box(
                        title = "Weekly Excursion Duration",
                        status = "info",
                        solidHeader = TRUE,
                        width = NULL,
                        plotlyOutput("excursionWeeklyDurationPlot", height = "420px")
                      )
                    ),
                    column(
                      width = 6,
                      box(
                        title = "Weekly Excursion Percentage",
                        status = "success",
                        solidHeader = TRUE,
                        width = NULL,
                        plotlyOutput("excursionWeeklyPercentagePlot", height = "420px")
                      )
                    )
                  )
                )
              )
      ),

      # -- Response Holding Tab --
      tabItem(tabName = "response",
              tabsetPanel(
                id = "responseSubtab",
                tabPanel(
                  title = "Daily",
                  value = "daily",
                  fluidRow(
                    box(
                      title = "System Response Holding Analysis", status = "info", solidHeader = TRUE, width = 12,
                      collapsible = TRUE, collapsed = TRUE,
                      tags$div(
                        style = "padding: 10px;",
                        tags$p("This tab shows the system's response holding capacity combining:"),
                        tags$ul(
                          tags$li(strong("MFR (Mandatory Frequency Response):"), " P, S, and H components"),
                          tags$li(strong("EAC (Enhanced Automatic Control):"), " Demand response products (DRL, DRH, DML, DMH, DCL, DCH)")
                        ),
                        tags$p(strong("SysDyn Calculations:")),
                        tags$ul(
                      tags$li("SysDyn_LP (Total Eq. Low Response) = P + 1.67 × (DRL + DML)"),
                      tags$li("SysDyn_H (Total Eq. High Response) = H + 1.67 × (DRH + DMH)")
                    )
                  )
                )
                  ),

                  # Filter Options
                  fluidRow(
                    box(
                      title = "Filter by Date Range", status = "warning", solidHeader = TRUE, width = 12,
                      # Add style to prevent clipping of date picker dropdown
                      tags$style(HTML("
                    .box-body { overflow: visible !important; }
                    .datepicker { z-index: 9999 !important; }
                  ")),
                      fluidRow(
                        column(3,
                               dateInput("responseStartDate", "Start Date:",
                                         value = as.Date("2025-01-01"),
                                         min = as.Date("2025-01-01"),
                                         max = as.Date("2025-09-30"))
                        ),
                        column(3,
                               dateInput("responseEndDate", "End Date:",
                                         value = as.Date("2025-01-01"),
                                         min = as.Date("2025-01-01"),
                                         max = as.Date("2025-09-30"))
                        ),
                        column(3,
                               br(),
                               actionButton("updateResponsePlots", "Update Plots",
                                            class = "btn-primary",
                                            style = "width: 100%;")
                        )
                      )
                    )
                  ),

                  # Summary Statistics
                  fluidRow(
                    column(4,
                           box(
                             title = "MFR Average", status = "primary", solidHeader = TRUE, width = NULL,
                             uiOutput("mfrSummaryUI")
                           )
                    ),
                    column(4,
                           box(
                             title = "EAC Average", status = "success", solidHeader = TRUE, width = NULL,
                             uiOutput("eacSummaryUI")
                           )
                    ),
                    column(4,
                           box(
                             title = "SysDyn Average", status = "danger", solidHeader = TRUE, width = NULL,
                             uiOutput("sysdynSummaryUI")
                           )
                    )
                  ),

                  # Time Series Plots
                  fluidRow(
                    box(
                      title = "System Response Time Series by Settlement Period",
                      status = "primary", solidHeader = TRUE, width = 12,
                      fluidRow(
                        column(12,
                               checkboxGroupInput("responseMetrics", "Select Metrics to Display:",
                                                  choices = c("SysDyn_LP (Total Eq. Low Response)" = "SysDyn_LP",
                                                              "SysDyn_H (Total Eq. High Response)" = "SysDyn_H",
                                                              "P (Primary)" = "P",
                                                              "S (Secondary)" = "S",
                                                              "H (High)" = "H",
                                                              "DRL (Demand Response Low)" = "DRL",
                                                              "DRH (Demand Response High)" = "DRH",
                                                              "DML (Demand Management Low)" = "DML",
                                                              "DMH (Demand Management High)" = "DMH"),
                                                  selected = c("SysDyn_LP", "SysDyn_H"),
                                                  inline = TRUE)
                        )
                      ),
                      plotlyOutput("responseTimeSeriesPlot", height = "500px")
                    )
                  ),

                  # Data Table
                  fluidRow(
                    box(
                      title = "Response Holding Data", status = "info", solidHeader = TRUE, width = 12,
                      DT::dataTableOutput("responseDataTable")
                    )
                  )
                ),
                tabPanel(
                  title = "Monthly",
                  value = "monthly",
                  br(),
                  fluidRow(
                    box(
                      title = "Monthly Response Holding Overview",
                      status = "primary",
                      solidHeader = TRUE,
                      width = 12,
                      fluidRow(
                        column(6, uiOutput("responseMonthlyStartUI")),
                        column(6, uiOutput("responseMonthlyEndUI"))
                      ),
                      fluidRow(
                        column(
                          width = 12,
                          checkboxGroupInput(
                            "responseMonthlyMetrics",
                            "Select Metrics to Display:",
                            choices = c(
                              "SysDyn_LP (Total Eq. Low Response)" = "SysDyn_LP",
                              "SysDyn_H (Total Eq. High Response)" = "SysDyn_H",
                              "P (Primary)" = "P",
                              "S (Secondary)" = "S",
                              "H (High)" = "H",
                              "DRL (Demand Response Low)" = "DRL",
                              "DRH (Demand Response High)" = "DRH",
                              "DML (Demand Management Low)" = "DML",
                              "DMH (Demand Management High)" = "DMH"
                            ),
                            selected = c("SysDyn_LP", "SysDyn_H"),
                            inline = TRUE
                          )
                        )
                      ),
                      plotlyOutput("responseMonthlyPlot", height = "450px")
                    )
                  )
                ),
                tabPanel(
                  title = "Weekly",
                  value = "weekly",
                  br(),
                  fluidRow(
                    box(
                      title = "Weekly Response Holding Overview",
                      status = "primary",
                      solidHeader = TRUE,
                      width = 12,
                      fluidRow(
                        column(6, uiOutput("responseWeeklyStartUI")),
                        column(6, uiOutput("responseWeeklyEndUI"))
                      ),
                      fluidRow(
                        column(
                          width = 12,
                          checkboxGroupInput(
                            "responseWeeklyMetrics",
                            "Select Metrics to Display:",
                            choices = c(
                              "SysDyn_LP (Total Eq. Low Response)" = "SysDyn_LP",
                              "SysDyn_H (Total Eq. High Response)" = "SysDyn_H",
                              "P (Primary)" = "P",
                              "S (Secondary)" = "S",
                              "H (High)" = "H",
                              "DRL (Demand Response Low)" = "DRL",
                              "DRH (Demand Response High)" = "DRH",
                              "DML (Demand Management Low)" = "DML",
                              "DMH (Demand Management High)" = "DMH"
                            ),
                            selected = c("SysDyn_LP", "SysDyn_H"),
                            inline = TRUE
                          )
                        )
                      ),
                      plotlyOutput("responseWeeklyPlot", height = "450px")
                    )
                  )
                )
              )
      ),

      # -- Monthly Trends Tab --
      tabItem(tabName = "monthly_trends",
              # Date Range Filter
              fluidRow(
                box(
                  title = "Analysis Period", status = "primary", solidHeader = TRUE, width = 12,
                  fluidRow(
                    column(3,
                           dateInput("monthlyStartDate", "Start Month:",
                                     value = as.Date("2025-01-01"),
                                     min = as.Date("2025-01-01"),
                                     max = as.Date("2025-12-31"),
                                     startview = "month", format = "yyyy-mm")
                    ),
                    column(3,
                           dateInput("monthlyEndDate", "End Month:",
                                     value = as.Date("2025-08-31"),
                                     min = as.Date("2025-01-01"),
                                     max = as.Date("2025-12-31"),
                                     startview = "month", format = "yyyy-mm")
                    ),
                    column(3,
                           selectInput("monthlyMetric", "Demand Metric:",
                                       choices = c("ND", "TSD", "ENGLAND_WALES_DEMAND"),
                                       selected = "ND")
                    ),
                    column(3,
                           br(),
                           actionButton("updateMonthlyPlots", "Update Analysis",
                                        class = "btn-primary",
                                        style = "width: 100%;")
                    )
                  )
                )
              ),

              # Panel 2: Monthly Red Ratio Trend
              fluidRow(
                box(
                  title = "Panel 2: Monthly Red Event Ratio Trend",
                  status = "warning", solidHeader = TRUE, width = 12,
                  plotlyOutput("monthlyRedRatio", height = "400px")
                )
              ),

              # Panel 3: Monthly Excursion Percentage
              # Panel 4: Monthly Demand Change Analysis
              fluidRow(
                box(
                  title = "Panel 4: Monthly Demand Change Analysis",
                  status = "success", solidHeader = TRUE, width = 12,
                  plotlyOutput("monthlyUnforeseenComparison", height = "450px")
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


  demandErrorData <- reactive({
    path <- "data/output/reports/red_event_demand.csv"
    if (!file.exists(path)) return(data.table())
    dt <- tryCatch(fread(path), error = function(e) data.table())
    if (!nrow(dt)) return(data.table())
    if ("Date" %in% names(dt)) {
      dt[, Date := as.Date(Date)]
    }
    if ("Datetime" %in% names(dt)) {
      dt[, Datetime := suppressWarnings(as.POSIXct(Datetime, tz = "UTC"))]
    }
    if ("Settlement_Period" %in% names(dt)) {
      dt[, Settlement_Period := as.integer(Settlement_Period)]
    }
    if ("Absolute_Error" %in% names(dt)) {
      dt[, Absolute_Error := as.numeric(Absolute_Error)]
    } else {
      dt[, Absolute_Error := NA_real_]
    }
    dt
  })


  # Reactive expression to load REMIT unplanned trip data
  remitTripData <- reactive({
    path <- "data/output/reports/red_events_remit_matches.csv"
    if (!file.exists(path)) return(data.table())
    dt <- tryCatch(fread(path), error = function(e) data.table())
    if (!nrow(dt)) return(data.table())

    parse_time <- function(x) suppressWarnings(as.POSIXct(x, tz = "UTC"))
    time_cols <- intersect(c("event_start_time", "publish_time"), names(dt))
    for (col in time_cols) {
      dt[, (col) := parse_time(get(col))]
    }
    if (!"event_start_time" %in% names(dt)) {
      return(data.table())
    }
    dt[is.na(event_start_time) & "publish_time" %in% names(dt),
       event_start_time := publish_time]
    dt <- dt[!is.na(event_start_time)]
    if (!"unavailability_type" %in% names(dt)) return(data.table())
    dt <- dt[tolower(unavailability_type) == "unplanned"]
    if (!nrow(dt)) return(data.table())
    dt[, event_date := as.Date(event_start_time)]
    dt <- dt[!is.na(event_date)]
    dt
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

  excursion_threshold_colors <- c("0.1" = "#ff7f0e",
                                  "0.15" = "#2ca02c",
                                  "0.2" = "#1f77b4")

  selectedExcursionThresholds <- reactive({
    thr_input <- input$excursionThresholds
    if (is.null(thr_input)) return(numeric())
    thr <- sort(unique(as.numeric(thr_input)))
    thr[!is.na(thr)]
  })

  getExcursionColor <- function(threshold) {
    col <- excursion_threshold_colors[as.character(threshold)]
    if (is.null(col) || is.na(col)) "#999999" else col
  }

  excursionEmptyPlot <- function(message, x_title = NULL, y_title = NULL) {
    plotly_empty(type = "scatter", mode = "text") %>%
      layout(
        annotations = list(
          list(
            text = message,
            showarrow = FALSE,
            x = 0.5, y = 0.5,
            xref = "paper", yref = "paper"
          )
        ),
        xaxis = list(title = x_title),
        yaxis = list(title = y_title)
      )
  }

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
    # Get actual data range
    df[, date := as.Date(dtm_sec)]
    min_date <- min(df$date, na.rm = TRUE)
    max_date <- max(df$date, na.rm = TRUE)

    div(
      dateInput("freqStartDate", "Start Date:",
                value = min_date,
                min = min_date,
                max = max_date),
      br(),
      dateInput("freqEndDate", "End Date:",
                value = max_date,
                min = min_date,
                max = max_date)
    )
  })

  # Dynamic date range UI for KPI plots
  output$kpiDateRangeUI <- renderUI({
    df <- kpiData()
    # Get actual data range
    min_date <- min(df$date, na.rm = TRUE)
    max_date <- max(df$date, na.rm = TRUE)

    div(
      dateInput("kpiStartDate", "Start Date:",
                value = min_date,
                min = min_date,
                max = max_date),
      br(),
      dateInput("kpiEndDate", "End Date:",
                value = max_date,
                min = min_date,
                max = max_date)
    )
  })

  output$kpiMonthlyDateRangeUI <- renderUI({
    df <- kpiData()
    if (nrow(df) == 0) {
      return(tags$p("No KPI data available", style = "color: #999; font-style: italic;"))
    }
    min_date <- suppressWarnings(lubridate::floor_date(min(df$date, na.rm = TRUE), unit = "month"))
    max_date <- suppressWarnings(lubridate::floor_date(max(df$date, na.rm = TRUE), unit = "month"))
    if (is.infinite(min_date) || is.na(min_date) || is.infinite(max_date) || is.na(max_date)) {
      return(tags$p("No KPI data available", style = "color: #999; font-style: italic;"))
    }
    tagList(
      dateInput("kpiMonthlyStartDate", "Start Month:",
                value = min_date,
                min = min_date,
                max = max_date,
                startview = "month",
                format = "yyyy-mm"),
      br(),
      dateInput("kpiMonthlyEndDate", "End Month:",
                value = max_date,
                min = min_date,
                max = max_date,
                startview = "month",
                format = "yyyy-mm")
    )
  })

  output$kpiWeeklyDateRangeUI <- renderUI({
    df <- kpiData()
    if (nrow(df) == 0) {
      return(tags$p("No KPI data available", style = "color: #999; font-style: italic;"))
    }
    min_week <- suppressWarnings(lubridate::floor_date(min(df$date, na.rm = TRUE), unit = "week", week_start = 1))
    max_week <- suppressWarnings(lubridate::floor_date(max(df$date, na.rm = TRUE), unit = "week", week_start = 1))
    if (is.na(min_week) || is.na(max_week) || is.infinite(min_week) || is.infinite(max_week)) {
      return(tags$p("No KPI data available", style = "color: #999; font-style: italic;"))
    }
    tagList(
      dateInput("kpiWeeklyStartDate", "Start Week:",
                value = min_week,
                min = min_week,
                max = max_week,
                startview = "month",
                format = "yyyy-mm-dd"),
      br(),
      dateInput("kpiWeeklyEndDate", "End Week:",
                value = max_week,
                min = min_week,
                max = max_week,
                startview = "month",
                format = "yyyy-mm-dd")
    )
  })

  output$excursionMonthlyStartUI <- renderUI({
    df <- monthlyExcursionData()
    if (nrow(df) == 0) {
      return(tags$p("No excursion data available", style = "color: #999; font-style: italic;"))
    }
    min_month <- min(df$month, na.rm = TRUE)
    max_month <- max(df$month, na.rm = TRUE)
    dateInput(
      "excursionMonthlyStart",
      "Start Month:",
      value = min_month,
      min = min_month,
      max = max_month,
      startview = "month",
      format = "yyyy-mm"
    )
  })

  output$excursionMonthlyEndUI <- renderUI({
    df <- monthlyExcursionData()
    if (nrow(df) == 0) {
      return(tags$p("No excursion data available", style = "color: #999; font-style: italic;"))
    }
    min_month <- min(df$month, na.rm = TRUE)
    max_month <- max(df$month, na.rm = TRUE)
    dateInput(
      "excursionMonthlyEnd",
      "End Month:",
      value = max_month,
      min = min_month,
      max = max_month,
      startview = "month",
      format = "yyyy-mm"
    )
  })

  output$excursionWeeklyStartUI <- renderUI({
    df <- excursionDailyData()
    if (nrow(df) == 0) {
      return(tags$p("No excursion data available", style = "color: #999; font-style: italic;"))
    }
    min_week <- suppressWarnings(lubridate::floor_date(min(df$date, na.rm = TRUE), unit = "week", week_start = 1))
    max_week <- suppressWarnings(lubridate::floor_date(max(df$date, na.rm = TRUE), unit = "week", week_start = 1))
    dateInput(
      "excursionWeeklyStart",
      "Start Week:",
      value = min_week,
      min = min_week,
      max = max_week,
      startview = "month",
      format = "yyyy-mm-dd"
    )
  })

  output$excursionWeeklyEndUI <- renderUI({
    df <- excursionDailyData()
    if (nrow(df) == 0) {
      return(tags$p("No excursion data available", style = "color: #999; font-style: italic;"))
    }
    min_week <- suppressWarnings(lubridate::floor_date(min(df$date, na.rm = TRUE), unit = "week", week_start = 1))
    max_week <- suppressWarnings(lubridate::floor_date(max(df$date, na.rm = TRUE), unit = "week", week_start = 1))
    dateInput(
      "excursionWeeklyEnd",
      "End Week:",
      value = max_week,
      min = min_week,
      max = max_week,
      startview = "month",
      format = "yyyy-mm-dd"
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

  # Data Coverage - Extract date range from input file names
  dataInputCoverage <- reactive({
    tryCatch({
      # List all fnew-*.csv files in data/input
      freq_files <- list.files("data/input", pattern = "^fnew-.*\\.csv$", full.names = FALSE)

      if (length(freq_files) == 0) {
        return(list(start_date = "No data", end_date = "No data", months = 0))
      }

      # Extract year and month from filenames (pattern: fnew-YYYY-M.csv)
      file_info <- data.frame(filename = freq_files, stringsAsFactors = FALSE)
      file_info$year <- as.integer(sub("fnew-(\\d{4})-.*", "\\1", freq_files))
      file_info$month <- as.integer(sub("fnew-\\d{4}-(\\d+)\\.csv", "\\1", freq_files))

      # Create dates (using first day of each month)
      file_info$date <- as.Date(paste(file_info$year, file_info$month, "01", sep = "-"))

      # Find earliest and latest dates
      first_date <- min(file_info$date)
      last_date <- max(file_info$date)

      # Format as "YYYY-MM" for cleaner display
      start_str <- format(first_date, "%Y-%m")
      end_str <- format(last_date, "%Y-%m")

      # Calculate number of months
      n_months <- length(freq_files)

      return(list(
        start_date = start_str,
        end_date = end_str,
        months = n_months
      ))
    }, error = function(e) {
      return(list(start_date = "Error reading data", end_date = "Error reading data", months = 0))
    })
  })

  output$configDataStartDate <- renderUI({
    coverage <- dataInputCoverage()
    tags$span(coverage$start_date)
  })

  output$configDataEndDate <- renderUI({
    coverage <- dataInputCoverage()
    tags$span(coverage$end_date)
  })

  output$configDataMonths <- renderUI({
    coverage <- dataInputCoverage()
    tags$span(paste0(coverage$months, " months"))
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
    df <- filteredEvents()
    display_cols <- c("date", "starting_sp", "boundary_time",
                      "min_f", "max_f", "abs_freq_change", "rocof_p99",
                      "imbalance_mw", "trend", "event_timing",
                      "category", "severity")
    available_cols <- intersect(display_cols, names(df))
    datatable(df[, ..available_cols],
              options = list(pageLength = 10, scrollX = TRUE),
              rownames = FALSE,
              filter = 'top')
  })

  # --- Events Analysis (Red events aggregation) ---
  eventRedData <- reactive({
    df <- eventData()
    if (!"category" %in% names(df)) return(data.table())
    df <- df[category == "Red"]
    if (!nrow(df)) return(df)
    df[, date := as.Date(date)]
    df[, week_start := floor_date(date, "week", week_start = 1)]
    df[, month_label := format(date, "%Y-%m")]
    df[, month_date := as.Date(paste0(month_label, "-01"))]
    if (!"imbalance_mw" %in% names(df)) {
      df[, imbalance_mw := NA_real_]
    } else {
      df[, imbalance_mw := as.numeric(imbalance_mw)]
    }
    setorder(df, date, starting_sp)
    df
  })

  safe_stat <- function(x, fun) {
    if (length(x) == 0 || all(is.na(x))) return(NA_real_)
    fun(x, na.rm = TRUE)
  }

  complete_sp_counts <- function(dt) {
    full_sp <- data.table(starting_sp = 1:48)
    merged <- merge(full_sp, dt, by = "starting_sp", all.x = TRUE)
    merged[is.na(event_count), event_count := 0]
    merged
  }

  monthlySummaryData <- reactive({
    df <- eventRedData()
    if (nrow(df) == 0) return(data.table())
    summary <- df[, .(
      event_count = .N,
      mean_severity = safe_stat(severity, mean),
      mean_imbalance = safe_stat(abs(imbalance_mw), mean),
      mean_positive_imbalance = safe_stat(imbalance_mw[imbalance_mw > 0], mean),
      mean_negative_imbalance = safe_stat(imbalance_mw[imbalance_mw < 0], mean),
      abs_freq_change_avg = safe_stat(abs_freq_change, mean),
      rocof_p99_avg = safe_stat(rocof_p99, mean)
    ), by = .(month_label, month_date)]
    if (nrow(summary) == 0) return(summary)
    setorder(summary, month_date)
    summary[, cumulative_count := cumsum(event_count)]
    summary[, month_label := factor(month_label, levels = unique(month_label))]
    summary
  })

  eventAnalysisNav <- reactiveValues(
    daily_idx = 0L,
    weekly_idx = 0L,
    monthly_idx = 0L
  )

  availableDailyDates <- reactive({
    df <- eventRedData()
    if (nrow(df) == 0) return(as.Date(character()))
    sort(unique(df$date))
  })

  availableWeeklyStarts <- reactive({
    df <- eventRedData()
    if (nrow(df) == 0) return(as.Date(character()))
    sort(unique(df$week_start))
  })

  formatWeekLabel <- function(week_start) {
    paste0("W", format(week_start, "%V"), " ", format(week_start, "%d %b"))
  }


  availableMonthlyLabels <- reactive({
    df <- eventRedData()
    if (nrow(df) == 0) return(character())
    sort(unique(df$month_label))
  })

  observeEvent(availableDailyDates(), {
    dates <- availableDailyDates()
    eventAnalysisNav$daily_idx <- if (length(dates) == 0) 0L else length(dates)
  })

  observeEvent(availableWeeklyStarts(), {
    weeks <- availableWeeklyStarts()
    if (length(weeks) == 0) return()
    eventAnalysisNav$weekly_idx <- length(weeks)

    week_choices <- setNames(as.character(weeks), formatWeekLabel(weeks))
    start_selected <- input$eventWeeklyRangeStart
    end_selected <- input$eventWeeklyRangeEnd
    if (is.null(start_selected) || !(start_selected %in% as.character(weeks))) {
      start_selected <- as.character(min(weeks))
    }
    if (is.null(end_selected) || !(end_selected %in% as.character(weeks))) {
      end_selected <- as.character(max(weeks))
    }
    if (as.Date(start_selected) > as.Date(end_selected)) {
      end_selected <- start_selected
    }
    updateSelectInput(session, "eventWeeklyRangeStart",
                      choices = week_choices,
                      selected = start_selected)
    updateSelectInput(session, "eventWeeklyRangeEnd",
                      choices = week_choices,
                      selected = end_selected)
  })

  observeEvent(availableMonthlyLabels(), {
    labels <- availableMonthlyLabels()
    eventAnalysisNav$monthly_idx <- if (length(labels) == 0) 0L else length(labels)
  })

  observeEvent(input$eventDailyPrev, {
    dates <- availableDailyDates()
    if (length(dates) == 0) return()
    eventAnalysisNav$daily_idx <- max(1L, eventAnalysisNav$daily_idx - 1L)
  })

  observeEvent(input$eventDailyNext, {
    dates <- availableDailyDates()
    if (length(dates) == 0) return()
    eventAnalysisNav$daily_idx <- min(length(dates), eventAnalysisNav$daily_idx + 1L)
  })

  observeEvent(input$eventWeeklyPrev, {
    weeks <- availableWeeklyStarts()
    if (length(weeks) == 0) return()
    eventAnalysisNav$weekly_idx <- max(1L, eventAnalysisNav$weekly_idx - 1L)
  })

  observeEvent(input$eventWeeklyNext, {
    weeks <- availableWeeklyStarts()
    if (length(weeks) == 0) return()
    eventAnalysisNav$weekly_idx <- min(length(weeks), eventAnalysisNav$weekly_idx + 1L)
  })

  observeEvent(input$eventMonthlyCalPrev, {
    labels <- availableMonthlyLabels()
    if (length(labels) == 0) return()
    eventAnalysisNav$monthly_idx <- max(1L, eventAnalysisNav$monthly_idx - 1L)
  })

  observeEvent(input$eventMonthlyCalNext, {
    labels <- availableMonthlyLabels()
    if (length(labels) == 0) return()
    eventAnalysisNav$monthly_idx <- min(length(labels), eventAnalysisNav$monthly_idx + 1L)
  })

  selectedDailyDate <- reactive({
    dates <- availableDailyDates()
    if (length(dates) == 0) return(NA)
    idx <- min(max(eventAnalysisNav$daily_idx, 1L), length(dates))
    dates[idx]
  })

  selectedWeeklyStart <- reactive({
    weeks <- availableWeeklyStarts()
    if (length(weeks) == 0) return(NA)
    idx <- min(max(eventAnalysisNav$weekly_idx, 1L), length(weeks))
    weeks[idx]
  })

  weeklyRange <- reactive({
    weeks <- availableWeeklyStarts()
    if (length(weeks) == 0) return(NULL)

    start_val <- input$eventWeeklyRangeStart
    end_val <- input$eventWeeklyRangeEnd
    if (is.null(start_val) || !(start_val %in% as.character(weeks))) {
      start_val <- as.character(min(weeks))
    }
    if (is.null(end_val) || !(end_val %in% as.character(weeks))) {
      end_val <- as.character(max(weeks))
    }

    start_date <- as.Date(start_val)
    end_date <- as.Date(end_val)
    if (is.na(start_date) || is.na(end_date)) return(NULL)
    if (start_date > end_date) {
      end_date <- start_date
    }
    list(start = start_date, end = end_date)
  })

  output$eventWeeklyImbalancePlot <- renderPlotly({
    df <- eventRedData()
    if (nrow(df) == 0) return(plotly_empty())
    range_weeks <- weeklyRange()
    if (is.null(range_weeks)) return(plotly_empty())

    weekly_summary <- df[, .(
      avg_abs_imbalance = safe_stat(abs(imbalance_mw), mean)
    ), by = week_start]
    weekly_summary <- weekly_summary[week_start >= range_weeks$start & week_start <= range_weeks$end]
    if (nrow(weekly_summary) == 0 || all(is.na(weekly_summary$avg_abs_imbalance))) {
      return(plotly_empty(type = "scatter", mode = "text") %>%
               layout(
                 annotations = list(list(
                   text = "No imbalance data available for selected range",
                   showarrow = FALSE,
                   x = 0.5, y = 0.5,
                   xref = "paper", yref = "paper"
                 )),
                 xaxis = list(title = "Week"),
                 yaxis = list(title = "Avg |Imbalance| (MW)")
               ))
    }

    setorder(weekly_summary, week_start)
    weekly_summary[, week_label := formatWeekLabel(week_start)]

    plot_ly(weekly_summary,
            x = ~week_start,
            y = ~avg_abs_imbalance,
            type = "scatter",
            mode = "lines+markers+text",
            line = list(color = "#ff7f0e", width = 2),
            marker = list(color = "#ff7f0e", size = 6),
            text = ~sprintf("%.0f MW", avg_abs_imbalance),
            textposition = "top center",
            textfont = list(color = "#ff7f0e")) %>%
      layout(
        xaxis = list(
          title = "Week",
          tickmode = "array",
          tickvals = weekly_summary$week_start,
          ticktext = weekly_summary$week_label,
          tickangle = -90
        ),
        yaxis = list(title = "Avg |Imbalance| (MW)"),
        showlegend = FALSE
      )
  })

  selectedMonthlyRow <- reactive({
    summary <- monthlySummaryData()
    if (nrow(summary) == 0) return(NULL)
    tail(summary, 1)
  })

  selectedCalendarMonth <- reactive({
    labels <- availableMonthlyLabels()
    if (length(labels) == 0) return(NA_character_)
    idx <- min(max(eventAnalysisNav$monthly_idx, 1L), length(labels))
    labels[idx]
  })

  output$eventAnalysisSelector <- renderUI({
    df <- eventRedData()
    if (nrow(df) == 0) {
      return(helpText("No Red events available in the current dataset."))
    }
    mode <- input$eventAnalysisGranularity %||% "Daily"
    if (mode == "Daily") {
      dates <- availableDailyDates()
      if (length(dates) == 0) {
        return(helpText("No Red events available in the current dataset."))
      }
      selected <- selectedDailyDate()
      if (is.na(selected)) {
        return(helpText("No Red events available in the current dataset."))
      }
      tagList(
        div(
          class = "btn-group",
          actionButton("eventDailyPrev", label = NULL, icon = icon("chevron-left"), class = "btn-default"),
          actionButton("eventDailyNext", label = NULL, icon = icon("chevron-right"), class = "btn-default")
        ),
        div(style = "margin-top: 10px;", strong(format(selected, "%Y-%m-%d")))
      )
    } else if (mode == "Weekly") {
      return(NULL)
    } else if (mode == "MonthlyCalendar") {
      labels <- availableMonthlyLabels()
      if (length(labels) == 0) {
        return(helpText("No Red events available in the current dataset."))
      }
      selected_label <- selectedCalendarMonth()
      if (is.na(selected_label)) {
        return(helpText("No Red events available in the current dataset."))
      }
      div(
        class = "btn-group",
        actionButton("eventMonthlyCalPrev", label = NULL, icon = icon("chevron-left"), class = "btn-default"),
        actionButton("eventMonthlyCalNext", label = NULL, icon = icon("chevron-right"), class = "btn-default"),
        div(style = "display: inline-block; margin-left: 10px;", strong(selected_label))
      )
    } else {
      selected <- selectedMonthlyRow()
      if (is.null(selected)) {
        return(helpText("No Red events available in the current dataset."))
      }
      label <- as.character(selected$month_label)
      div(style = "margin-top: 10px;", strong(label))
    }
  })

  build_sp_plot <- function(sp_dt, title_text, plot_type = c("bar", "heatmap")) {
    plot_type <- match.arg(plot_type)
    sp_dt[, starting_sp := as.integer(starting_sp)]
    sp_dt[, sp_factor := factor(starting_sp, levels = 1:48)]
    plot_data <- as.data.frame(sp_dt)

    if (plot_type == "heatmap") {
      z_matrix <- matrix(plot_data$event_count, nrow = 1)
      plot_ly(
        x = plot_data$sp_factor,
        y = c("SP"),
        z = z_matrix,
        type = "heatmap",
        colors = "Reds",
        colorbar = list(title = "# Red events")
      ) %>%
        layout(
          xaxis = list(title = "Settlement Period (SP)"),
          yaxis = list(title = "", showticklabels = FALSE),
          title = title_text
        )
    } else {
      plot_ly(plot_data, x = ~sp_factor, y = ~event_count, type = "bar", name = "# Red events") %>%
        layout(
          yaxis = list(title = "Red events"),
          xaxis = list(title = "Settlement Period (SP)"),
          title = title_text
        )
    }
  }

  build_temporal_plot <- function(dt, x_col, title_text, x_title = NULL) {
    plot_data <- as.data.frame(dt)
    plt <- plot_ly(plot_data, x = plot_data[[x_col]], y = ~event_count, type = "bar", name = "# Red events") %>%
      layout(
        yaxis = list(title = "Red events"),
        title = title_text
      )
    if (!is.null(x_title)) {
      plt <- plt %>% layout(xaxis = list(title = x_title))
    }
    plt
  }

  monthlyCalendarData <- reactive({
    df <- eventRedData()
    if (nrow(df) == 0) return(NULL)
    selected_label <- selectedCalendarMonth()
    if (is.na(selected_label)) return(NULL)
    month_mask <- df[month_label == selected_label]
    start_date <- as.Date(paste0(selected_label, "-01"))
    end_date <- as.Date(ceiling_date(start_date, "month") - days(1))
    full_dates <- data.table(date = seq(start_date, end_date, by = "day"))
    counts <- month_mask[, .(event_count = .N), by = date]
    full_dates[counts, event_count := i.event_count, on = "date"]
    full_dates[is.na(event_count), event_count := 0L]
    full_dates[, day_label := format(date, "%d")]
    full_dates[, day_factor := factor(day_label, levels = day_label)]
    full_dates
  })


  output$eventAnalysisPrimaryPlot <- renderPlotly({
    df <- eventRedData()
    if (nrow(df) == 0) return(plotly_empty())
    mode <- input$eventAnalysisGranularity %||% "Daily"

    if (mode == "Weekly") {
      weekly_summary <- df[, .(
        event_count = .N,
        avg_severity = safe_stat(severity, mean),
        avg_abs_imbalance = safe_stat(abs(imbalance_mw), mean)
      ), by = week_start]
      range_weeks <- weeklyRange()
      if (is.null(range_weeks)) return(plotly_empty())
      weekly_summary <- weekly_summary[week_start >= range_weeks$start & week_start <= range_weeks$end]
      if (nrow(weekly_summary) == 0) {
        return(plotly_empty(type = "scatter", mode = "text") %>%
                 layout(
                   annotations = list(list(
                     text = "No weekly data in selected range",
                     showarrow = FALSE,
                     x = 0.5, y = 0.5,
                     xref = "paper", yref = "paper"
                   )),
                   xaxis = list(title = "Week"),
                   yaxis = list(title = "# Red events")
                 ))
      }
      setorder(weekly_summary, week_start)
      weekly_summary[, week_label := formatWeekLabel(week_start)]

      plt <- plot_ly(weekly_summary,
                     x = ~week_start,
                     y = ~event_count,
                     type = "bar",
                     name = "# Red events",
                     marker = list(color = ~event_count,
                                   colorscale = "Reds",
                                   showscale = FALSE)) %>%
        layout(
          xaxis = list(
            title = "Week",
            tickmode = "array",
            tickvals = weekly_summary$week_start,
            ticktext = weekly_summary$week_label,
            tickangle = -90
          ),
          yaxis = list(title = "# Red events"),
          title = "Weekly Red Event Aggregation",
          hovermode = "x unified"
        )

      if (any(is.finite(weekly_summary$avg_severity))) {
        plt <- plt %>%
          add_trace(
            y = ~avg_severity,
            type = "scatter",
            mode = "lines+markers",
            name = "Avg Severity",
            line = list(color = "#1f77b4", width = 2),
            text = ~sprintf("%.2f", avg_severity),
            textposition = "top center",
            textfont = list(color = "#1f77b4"),
            marker = list(color = "#1f77b4", size = 6)
          ) %>%
          layout(
            legend = list(orientation = "h", x = 0.5, y = -0.2, xanchor = "center")
          )
      }

      return(plt)
    } else if (mode == "Monthly") {
      summary <- monthlySummaryData()
      if (nrow(summary) == 0) return(plotly_empty())
      plot_data <- as.data.frame(summary)
      combined_vals <- c(plot_data$event_count, plot_data$mean_imbalance)
      combined_vals <- combined_vals[is.finite(combined_vals)]
      if (!length(combined_vals)) combined_vals <- 0
      min_combined <- min(c(0, combined_vals))
      max_combined <- max(c(0, combined_vals))
      if (identical(min_combined, max_combined)) {
        max_combined <- max_combined + 1
        min_combined <- min_combined - 1
      }
      plot_ly(plot_data, x = ~month_label, y = ~event_count, type = "bar",
              marker = list(color = plot_data$event_count, colorscale = "Reds",
                            showscale = TRUE, colorbar = list(title = "# Red events")),
              name = "# Red events") %>%
        add_trace(
          y = ~mean_imbalance,
          type = "scatter",
          mode = "lines+markers+text",
          name = "Absolute Average Imbalance (MW)",
          line = list(color = "#1f77b4", width = 2),
          marker = list(color = "#1f77b4", size = 6),
          text = ~sprintf("%.1f MW", mean_imbalance),
          textposition = "top center",
          textfont = list(color = "#1f77b4"),
          cliponaxis = FALSE,
          hoverinfo = "text+x+y"
        ) %>%
        layout(
          yaxis = list(title = "Red events / Imbalance (MW)",
                       range = c(0, 200)),
          xaxis = list(title = "Month"),
          title = "",
          legend = list(orientation = "h", x = 0.5, xanchor = "center", y = -0.2)
        )
    } else if (mode == "MonthlyCalendar") {
      calendar_data <- monthlyCalendarData()
      if (is.null(calendar_data) || nrow(calendar_data) == 0) return(plotly_empty())
      plot_data <- as.data.frame(calendar_data)
      active_month <- selectedCalendarMonth()
      plt <- plot_ly(
        plot_data,
        x = ~day_factor,
        y = ~event_count,
        type = "bar",
        marker = list(
          color = plot_data$event_count,
          colorscale = "Reds"
        ),
        showlegend = FALSE
      )

      if (isTRUE(input$toggleRemitDiamonds)) {
        remit_daily <- remitTripData()
        if (nrow(remit_daily) > 0 && !is.na(active_month)) {
          remit_daily <- remit_daily[format(event_date, "%Y-%m") == active_month]
          if (nrow(remit_daily)) {
            if (!"participant_id" %in% names(remit_daily)) remit_daily[, participant_id := NA_character_]
            if (!"asset_id" %in% names(remit_daily)) remit_daily[, asset_id := NA_character_]
            if (!"lost_capacity_mw" %in% names(remit_daily)) remit_daily[, lost_capacity_mw := NA_real_]
            if (!"duration_minutes" %in% names(remit_daily)) remit_daily[, duration_minutes := NA_real_]
            remit_daily[, day_label := format(event_date, "%d")]
            remit_daily[, day_factor := factor(day_label, levels = levels(plot_data$day_factor))]
            remit_daily <- remit_daily[!is.na(day_factor)]
            if (nrow(remit_daily)) {
              bar_lookup <- setNames(plot_data$event_count, as.character(plot_data$day_factor))
              remit_daily[, base_y := fcoalesce(as.numeric(bar_lookup[as.character(day_factor)]), 0)]
              remit_daily[, marker_y := base_y + 0.3 + (rowid(event_date) - 1) * 0.15]
              remit_daily[, event_start_str := format(event_start_time, "%Y-%m-%d %H:%M UTC")]
              remit_daily[, participant_label := fifelse(!is.na(participant_id) & participant_id != "", participant_id, "Unknown")]
              remit_daily[, asset_label := fifelse(!is.na(asset_id) & asset_id != "", asset_id, "Unknown")]
              remit_daily[, capacity_label := fifelse(!is.na(lost_capacity_mw), sprintf("%.0f MW", lost_capacity_mw), "N/A")]
              remit_daily[, duration_label := fifelse(!is.na(duration_minutes), sprintf("%.0f min", duration_minutes), "N/A")]
              remit_daily[, tooltip := sprintf(
                paste0("Unplanned Trip: %s / %s",
                       "<br>Start: %s",
                       "<br>Lost Capacity: %s",
                       "<br>Duration: %s"),
                participant_label,
                asset_label,
                event_start_str,
                capacity_label,
                duration_label
              )]
              plt <- plt %>%
                add_trace(
                  data = as.data.frame(remit_daily),
                  x = ~day_factor,
                  y = ~marker_y,
                  type = "scatter",
                  mode = "markers",
                  marker = list(symbol = "diamond", size = 12, color = "#e377c2",
                                line = list(color = "#6f1d3b", width = 1.2)),
                  hoverinfo = "text",
                  text = ~tooltip,
                  name = "Unplanned production trip",
                  showlegend = TRUE
                )
            }
          }
        }
      }

      plt %>%
        layout(
          yaxis = list(title = "Red events"),
          xaxis = list(title = "Day of Month"),
          title = active_month,
          showlegend = TRUE,
          legend = list(orientation = "h", x = 1, xanchor = "right",
                        y = -0.2, title = list(text = NULL))
        )
    } else {
      plotly_empty()
    }
  })

  output$eventAnalysisDailyPlot <- renderPlotly({
    df <- eventRedData()
    if (nrow(df) == 0) return(plotly_empty())
    selected_date <- selectedDailyDate()
    if (is.na(selected_date)) return(plotly_empty())
    day_subset <- df[date == selected_date]
    sp_counts <- day_subset[, .(
      event_count = .N
    ), by = starting_sp]
    sp_counts <- complete_sp_counts(sp_counts)
    build_sp_plot(sp_counts, paste("Daily SP Distribution -", selected_date), plot_type = "bar")
  })

  output$eventAnalysisDailyDemandPlot <- renderPlotly({
    demand_dt <- demandErrorData()
    if (nrow(demand_dt) == 0) return(plotly_empty())
    selected_date <- selectedDailyDate()
    if (is.na(selected_date)) return(plotly_empty())
    day_data <- demand_dt[Date == selected_date]
    if (nrow(day_data) == 0 || all(is.na(day_data$Absolute_Error))) {
      msg <- paste0("No demand forecast error data for ", selected_date,
                    ". Ensure red_event_demand.csv covers this date.")
      return(plotly_empty(type = "scatter", mode = "text") %>%
               layout(
                 annotations = list(
                   text = msg,
                   showarrow = FALSE,
                   xref = "paper", yref = "paper", x = 0.5, y = 0.5
                 ),
                 xaxis = list(title = "Settlement Period"),
                 yaxis = list(title = "Absolute Error (MW)")
               ))
    }
    sp_base <- data.table(Settlement_Period = 1:48)
    if (nrow(day_data)) {
      day_agg <- day_data[, .(abs_error = safe_stat(Absolute_Error, mean)), by = Settlement_Period]
    } else {
      day_agg <- data.table(Settlement_Period = integer(), abs_error = numeric())
    }
    merged <- merge(sp_base, day_agg, by = "Settlement_Period", all.x = TRUE)
    merged[is.na(abs_error), abs_error := 0]
    merged[, sp_factor := factor(Settlement_Period, levels = 1:48)]
    plot_ly(merged,
            x = ~sp_factor,
            y = ~abs_error,
            type = "bar",
            name = "Absolute Error (MW)",
            marker = list(color = "#1f77b4")) %>%
      layout(
        xaxis = list(title = "Settlement Period"),
        yaxis = list(title = "Absolute Error (MW)"),
        title = paste("Forecast Absolute Error -", selected_date)
      )
  })

  output$eventAnalysisMonthlyMetricsPlot <- renderPlotly({
    summary <- monthlySummaryData()
    if (nrow(summary) == 0) return(plotly_empty())
    plot_data <- as.data.frame(summary)
    plot_ly(plot_data, x = ~month_label, y = ~mean_severity,
            type = "scatter", mode = "lines+markers",
            name = "Avg Severity", line = list(color = "#ff7f0e", width = 2),
            marker = list(color = "#ff7f0e", size = 6), text = ~sprintf("%.2f", mean_severity),
            textposition = "top center", cliponaxis = FALSE,
            hoverinfo = "text+x+y") %>%
      layout(
        yaxis = list(title = "Average Severity", range = c(0, 6)),
        xaxis = list(title = "Month"),
        showlegend = FALSE,
        title = ""
      )
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
  filteredExcursionData <- eventReactive(list(input$updateExcursionPlots, input$excursionThresholds), {
    req(input$excursionStartDate, input$excursionEndDate)

    daily_df <- excursionDailyData()

    # Filter by date range
    thresholds <- selectedExcursionThresholds()
    if (!length(thresholds)) {
      return(list(daily = data.table()))
    }
    if (!"threshold" %in% names(daily_df)) {
      daily_df[, threshold := NA_real_]
    }
    daily_filtered <- daily_df[date >= input$excursionStartDate &
                                 date <= input$excursionEndDate &
                                 threshold %in% thresholds]

    list(daily = daily_filtered)
  }, ignoreNULL = FALSE)

  # Plot 1: Number of Excursions - Daily Time Series
  output$excursionCountPlot <- renderPlotly({
    req(input$excursionStartDate, input$excursionEndDate)

    # Check if single day selected
    single_day <- input$excursionStartDate == input$excursionEndDate
    thresholds <- selectedExcursionThresholds()
    if (!length(thresholds)) {
      return(excursionEmptyPlot("Enable at least one threshold to view excursions.",
                                "Settlement Period (SP)", "Count of Excursion Events"))
    }

    if (single_day) {
      # Single day: count excursion events per SP
      # Load per-second frequency data for the selected day
      freq_data <- frequencyData()
      freq_data[, date := as.Date(dtm_sec)]
      day_freq <- freq_data[date == input$excursionStartDate]

      if (nrow(day_freq) == 0) {
        return(excursionEmptyPlot("No data available for selected date.",
                                  "Settlement Period (SP)", "Count of Excursion Events"))
      }

      # Calculate deviation
      day_freq[, deviation := abs(f - 50)]

      # Detect excursions for each threshold
      all_excursions <- list()

      for (threshold in thresholds) {
        # Mark points exceeding threshold
        day_freq[, exceeds := deviation >= threshold]

        # Create excursion groups
        day_freq[, excursion_id := cumsum(c(1, diff(exceeds) != 0))]
        day_freq[, is_excursion := exceeds == TRUE]

        # Get excursion events with start_time
        excursions <- day_freq[is_excursion == TRUE, .(
          start_time = min(dtm_sec)
        ), by = excursion_id]

        if (nrow(excursions) > 0) {
          # Calculate starting SP from start_time
          excursions[, starting_sp := floor(as.numeric(difftime(start_time,
                                             as.POSIXct(paste0(as.Date(start_time), " 00:00:00"), tz = "UTC"),
                                             units = "secs")) / 1800) + 1]
          excursions[, threshold := threshold]
          all_excursions[[paste0("t", threshold*100)]] <- excursions
        }
      }

      combined_excursions <- if (length(all_excursions) > 0) {
        rbindlist(all_excursions, fill = TRUE)
      } else {
        data.table(threshold = numeric(), starting_sp = integer())
      }

      p <- plot_ly()
      for (thr in thresholds) {
        sp_series <- data.table(SP = 1:48, value = 0)
        if (nrow(combined_excursions)) {
          thr_counts <- combined_excursions[threshold == thr, .N, by = starting_sp]
          if (nrow(thr_counts)) {
            setnames(thr_counts, c("SP", "value"))
            sp_series <- merge(sp_series, thr_counts, by = "SP", all.x = TRUE, suffixes = c("", ".thr"))
            if ("value.thr" %in% names(sp_series)) {
              sp_series[, value := value.thr]
              sp_series[, value.thr := NULL]
            }
          }
        }
        sp_series[is.na(value), value := 0]
        p <- p %>%
          add_trace(
            data = sp_series,
            x = ~SP,
            y = ~value,
            name = sprintf("%.2f Hz", thr),
            type = "bar",
            marker = list(color = getExcursionColor(thr))
          )
      }

      p <- p %>%
        layout(
          title = "Number of Excursions per SP",
          xaxis = list(title = "Settlement Period (SP)", range = c(0.5, 48.5)),
          yaxis = list(title = "Count of Excursion Events"),
          legend = list(x = 0.5, y = -0.2, orientation = "h", xanchor = "center"),
          barmode = "group"
        )

      return(p)

    } else {
      # Multi-day: show time series
      data <- filteredExcursionData()
      df <- data$daily

      df <- df[threshold %in% thresholds]
      if (nrow(df) == 0) {
        return(excursionEmptyPlot("No data available for selected thresholds/date range.",
                                  "Date", "# Excursions"))
      }

      # Create plotly with single Y-axis
      p <- plot_ly()

      for (thr in thresholds) {
        thr_df <- df[threshold == thr]
        if (!nrow(thr_df)) next
        p <- p %>% add_trace(
          data = thr_df,
          x = ~date,
          y = ~num_excursions,
          name = sprintf("%.2f Hz", thr),
          type = "bar",
          marker = list(color = getExcursionColor(thr)),
          hovertemplate = paste0(
            "Date: %{x|%b %d, %Y}<br>",
            sprintf("%.2f Hz: ", thr), "%{y}<br>",
            "<extra></extra>"
          )
        )
      }

      # Configure layout with single Y-axis
      p <- p %>% layout(
        title = "Number of Excursions",
        xaxis = list(title = "Date"),
        yaxis = list(title = "Number of Excursions"),
        legend = list(x = 0.5, y = -0.2, orientation = "h", xanchor = "center"),
        hovermode = "x unified"
      )

      return(p)
    }
  })

  # Plot 2: Total Duration - Daily Time Series
  output$excursionDailyDurationPlot <- renderPlotly({
    req(input$excursionStartDate, input$excursionEndDate)

    # Check if single day selected
    single_day <- input$excursionStartDate == input$excursionEndDate
    thresholds <- selectedExcursionThresholds()
    if (!length(thresholds)) {
      return(excursionEmptyPlot("Enable at least one threshold to view excursions.",
                                "Settlement Period (SP)", "Total Duration (seconds)"))
    }

    if (single_day) {
      # Single day: show total duration per SP
      freq_data <- frequencyData()
      freq_data[, date := as.Date(dtm_sec)]
      day_freq <- freq_data[date == input$excursionStartDate]

      if (nrow(day_freq) == 0) {
        return(excursionEmptyPlot("No data available for selected date.",
                                  "Settlement Period (SP)", "Total Duration (seconds)"))
      }

      # Calculate deviation
      day_freq[, deviation := abs(f - 50)]

      # Detect excursions for each threshold
      all_excursions <- list()

      for (threshold in thresholds) {
        day_freq[, exceeds := deviation >= threshold]
        day_freq[, excursion_id := cumsum(c(1, diff(exceeds) != 0))]
        day_freq[, is_excursion := exceeds == TRUE]
        excursions <- day_freq[is_excursion == TRUE, .(
          start_time = min(dtm_sec),
          duration_sec = .N
        ), by = excursion_id]
        if (nrow(excursions) > 0) {
          excursions[, starting_sp := floor(as.numeric(difftime(start_time,
                                             as.POSIXct(paste0(as.Date(start_time), " 00:00:00"), tz = "UTC"),
                                             units = "secs")) / 1800) + 1]
          excursions[, threshold := threshold]
          all_excursions[[paste0("t", threshold*100)]] <- excursions
        }
      }

      combined_excursions <- if (length(all_excursions) > 0) {
        rbindlist(all_excursions, fill = TRUE)
      } else {
        data.table(threshold = numeric(), starting_sp = integer(), duration_sec = numeric())
      }

      p <- plot_ly()
      for (thr in thresholds) {
        sp_series <- data.table(SP = 1:48, duration = 0)
        if (nrow(combined_excursions)) {
          thr_dur <- combined_excursions[threshold == thr, .(duration = sum(duration_sec)), by = starting_sp]
          if (nrow(thr_dur)) {
            setnames(thr_dur, c("SP", "duration"))
            sp_series <- merge(sp_series, thr_dur, by = "SP", all.x = TRUE, suffixes = c("", ".thr"))
            if ("duration.thr" %in% names(sp_series)) {
              sp_series[, duration := duration.thr]
              sp_series[, duration.thr := NULL]
            }
          }
        }
        sp_series[is.na(duration), duration := 0]
        p <- p %>% add_trace(
          data = sp_series,
          x = ~SP,
          y = ~duration,
          name = sprintf("%.2f Hz", thr),
          type = "bar",
          marker = list(color = getExcursionColor(thr))
        )
      }

      p <- p %>%
        layout(
          title = "Total Duration of Excursions per SP",
          xaxis = list(title = "Settlement Period (SP)", range = c(0.5, 48.5)),
          yaxis = list(title = "Total Duration (seconds)"),
          legend = list(x = 0.5, y = -0.2, orientation = "h", xanchor = "center"),
          barmode = "group"
        )

      return(p)

    } else {
      data <- filteredExcursionData()
      df <- data$daily
      df <- df[threshold %in% thresholds]
      if (nrow(df) == 0) {
        return(excursionEmptyPlot("No data available for selected thresholds/date range.",
                                  "Date", "Duration (seconds)"))
      }

      p <- plot_ly()
      for (thr in thresholds) {
        thr_df <- df[threshold == thr]
        if (!nrow(thr_df)) next
        p <- p %>% add_trace(
          data = thr_df,
          x = ~date,
          y = ~total_duration_sec,
          name = sprintf("%.2f Hz", thr),
          type = "bar",
          marker = list(color = getExcursionColor(thr)),
          hovertemplate = paste0(
            "Date: %{x|%b %d, %Y}<br>",
            sprintf("%.2f Hz: ", thr), "%{y} sec<br>",
            "<extra></extra>"
          )
        )
      }

      p <- p %>% layout(
        title = "Total Duration of Excursions",
        xaxis = list(title = "Date"),
        yaxis = list(title = "Duration (seconds)"),
        legend = list(x = 0.5, y = -0.2, orientation = "h", xanchor = "center"),
        hovermode = "x unified",
        barmode = "group"
      )

      return(p)

    }
  })


  # Percentage of Time Plot
  output$excursionPercentagePlot <- renderPlotly({
    req(input$excursionStartDate, input$excursionEndDate)

    single_day <- input$excursionStartDate == input$excursionEndDate
    thresholds <- selectedExcursionThresholds()
    if (!length(thresholds)) {
      return(excursionEmptyPlot("Enable at least one threshold to view excursions.",
                                "Settlement Period (SP)", "Time in Excursion (%)"))
    }

    if (single_day) {
      freq_data <- frequencyData()
      freq_data[, date := as.Date(dtm_sec)]
      day_freq <- freq_data[date == input$excursionStartDate]

      if (nrow(day_freq) == 0) {
        return(excursionEmptyPlot("No data available for selected date.",
                                  "Settlement Period (SP)", "Time in Excursion (%)"))
      }

      day_freq[, deviation := abs(f - 50)]
      all_excursions <- list()

      for (threshold in thresholds) {
        day_freq[, exceeds := deviation >= threshold]
        day_freq[, excursion_id := cumsum(c(1, diff(exceeds) != 0))]
        day_freq[, is_excursion := exceeds == TRUE]
        excursions <- day_freq[is_excursion == TRUE, .(
          start_time = min(dtm_sec),
          duration_sec = .N
        ), by = excursion_id]
        if (nrow(excursions) > 0) {
          excursions[, starting_sp := floor(as.numeric(difftime(start_time,
                                             as.POSIXct(paste0(as.Date(start_time), " 00:00:00"), tz = "UTC"),
                                             units = "secs")) / 1800) + 1]
          excursions[, threshold := threshold]
          all_excursions[[paste0("t", threshold*100)]] <- excursions
        }
      }

      combined_excursions <- if (length(all_excursions) > 0) {
        rbindlist(all_excursions, fill = TRUE)
      } else {
        data.table(threshold = numeric(), starting_sp = integer(), duration_sec = numeric())
      }

      p <- plot_ly()
      for (thr in thresholds) {
        sp_series <- data.table(SP = 1:48, pct = 0)
        if (nrow(combined_excursions)) {
          thr_pct <- combined_excursions[threshold == thr, .(pct = (sum(duration_sec) / 1800) * 100), by = starting_sp]
          if (nrow(thr_pct)) {
            setnames(thr_pct, c("SP", "pct"))
            sp_series <- merge(sp_series, thr_pct, by = "SP", all.x = TRUE, suffixes = c("", ".thr"))
            if ("pct.thr" %in% names(sp_series)) {
              sp_series[, pct := pct.thr]
              sp_series[, pct.thr := NULL]
            }
          }
        }
        sp_series[is.na(pct), pct := 0]
        p <- p %>%
          add_trace(
            data = sp_series,
            x = ~SP,
            y = ~pct,
            name = sprintf("%.2f Hz", thr),
            type = "bar",
            marker = list(color = getExcursionColor(thr))
          )
      }

      p <- p %>%
        layout(
          title = "Time in Excursion per SP",
          xaxis = list(title = "Settlement Period (SP)", range = c(0.5, 48.5)),
          yaxis = list(title = "Time in Excursion (%)"),
          legend = list(x = 0.5, y = -0.2, orientation = "h", xanchor = "center"),
          barmode = "group"
        )

      return(p)

    } else {
      data <- filteredExcursionData()
      df <- data$daily
      df <- df[threshold %in% thresholds]
      if (nrow(df) == 0) {
        return(excursionEmptyPlot("No data available for selected thresholds/date range.",
                                  "Date", "Time in Excursion (%)"))
      }

      df[, duration_pct := (total_duration_sec / (24 * 3600)) * 100]

      p <- plot_ly()
      for (thr in thresholds) {
        thr_df <- df[threshold == thr]
        if (!nrow(thr_df)) next
        p <- p %>% add_trace(
          data = thr_df,
          x = ~date,
          y = ~duration_pct,
          name = sprintf("%.2f Hz", thr),
          type = "bar",
          marker = list(color = getExcursionColor(thr)),
          hovertemplate = paste0(
            "Date: %{x|%b %d, %Y}<br>",
            sprintf("%.2f Hz: ", thr), "%{y:.2f}%<br>",
            "<extra></extra>"
          )
        )
      }

      p <- p %>% layout(
        title = "Daily Excursion Percentage",
        xaxis = list(title = "Date"),
        yaxis = list(title = "Time in Excursion (%)"),
        legend = list(x = 0.5, y = -0.2, orientation = "h", xanchor = "center"),
        hovermode = "x unified",
        barmode = "group"
      )

      return(p)

    }
  })

  output$excursionMonthlyCountPlot <- renderPlotly({
    excursionEmptyPlot("Monthly view coming soon.", "Month", "# Excursions")
  })

  output$excursionMonthlyDurationPlot <- renderPlotly({
    excursionEmptyPlot("Monthly view coming soon.", "Month", "Duration (hours)")
  })

  output$excursionMonthlyAvgDurationPlot <- renderPlotly({
    excursionEmptyPlot("Monthly view coming soon.", "Month", "Average Duration (seconds)")
  })


  # SP Deviation Plot
  output$excursionSPDeviationPlot <- renderPlotly({
    req(input$excursionStartDate, input$excursionEndDate)

    # Load SP boundary events
    sp_events <- eventData()
    sp_events[, date := as.Date(date)]

    # Check if single day or multiple days
    single_day <- input$excursionStartDate == input$excursionEndDate

    if (single_day) {
      # Single day: line plot
      day_data <- sp_events[date == input$excursionStartDate]

      if (nrow(day_data) == 0) {
        p <- ggplot() +
          annotate("text", x = 0.5, y = 0.5,
                   label = "No frequency data available for selected day",
                   size = 6) +
          theme_void()
        return(ggplotly(p))
      }

      # Calculate average frequency and signed deviation
      day_data[, avg_f := (min_f + max_f) / 2]
      day_data[, deviation := round(avg_f - 50.0, 6)]

      # Sort by SP to ensure proper line drawing
      setorder(day_data, starting_sp)

      # Create line plot
      p <- plot_ly(day_data) %>%
        add_trace(x = ~starting_sp, y = ~deviation, type = "scatter",
                  mode = "lines",
                  line = list(color = "black", width = 2),
                  text = ~paste("SP:", starting_sp, "<br>Deviation:", round(deviation, 3), "Hz"),
                  hoverinfo = "text", showlegend = FALSE,
                  connectgaps = FALSE) %>%
        layout(
          xaxis = list(title = "Settlement Period (SP)", range = c(0.5, 48.5)),
          yaxis = list(
            title = "Frequency Deviation from 50 Hz (Hz)",
            tickvals = c(-0.30, -0.25, -0.20, -0.15, -0.10, -0.05, 0, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30),
            ticktext = c("-0.30", "-0.25", "-0.20", "-0.15", "-0.10", "-0.05", "0", "0.05", "0.10", "0.15", "0.20", "0.25", "0.30"),
            zeroline = TRUE,
            zerolinecolor = "black",
            zerolinewidth = 1,
            range = c(-0.35, 0.35)
          )
        )

      return(p)
    } else {
      # Multiple days: time series of daily deviation statistics
      date_range_data <- sp_events[date >= input$excursionStartDate & date <= input$excursionEndDate]

      if (nrow(date_range_data) == 0) {
        p <- ggplot() +
          annotate("text", x = 0.5, y = 0.5,
                   label = "No frequency data available for selected date range",
                   size = 6) +
          theme_void()
        return(ggplotly(p))
      }

      # Calculate average frequency and signed deviation
      date_range_data[, avg_f := (min_f + max_f) / 2]
      date_range_data[, deviation := round(avg_f - 50.0, 6)]

      # Calculate daily statistics
      daily_stats <- date_range_data[, .(
        max_dev = max(deviation, na.rm = TRUE),
        min_dev = min(deviation, na.rm = TRUE),
        max_sp = starting_sp[which.max(deviation)],
        min_sp = starting_sp[which.min(deviation)]
      ), by = date]

      setorder(daily_stats, date)

      # Create time series plot
      p <- plot_ly(daily_stats) %>%
        add_trace(x = ~date, y = ~max_dev, name = "Max Deviation",
                  type = "scatter", mode = "lines+markers",
                  line = list(color = "#d62728", width = 2),
                  marker = list(size = 4, color = "#d62728"),
                  text = ~paste("Date:", date, "<br>Max Dev:", round(max_dev, 3), "Hz<br>At SP:", max_sp),
                  hoverinfo = "text") %>%
        add_trace(x = ~date, y = ~min_dev, name = "Min Deviation",
                  type = "scatter", mode = "lines+markers",
                  line = list(color = "#1f77b4", width = 2),
                  marker = list(size = 4, color = "#1f77b4"),
                  text = ~paste("Date:", date, "<br>Min Dev:", round(min_dev, 3), "Hz<br>At SP:", min_sp),
                  hoverinfo = "text") %>%
        layout(
          title = "Daily Frequency Deviation Statistics",
          xaxis = list(title = "Date"),
          yaxis = list(
            title = "Frequency Deviation from 50 Hz (Hz)",
            zeroline = TRUE,
            zerolinecolor = "black",
            zerolinewidth = 1
          ),
          legend = list(x = 0.5, y = -0.2, orientation = "h", xanchor = "center"),
          hovermode = "x unified",
          barmode = "group"
        )

      return(p)
    }
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

  # --- Response Holding Tab Logic ---
  response_metric_colors <- c(
    "SysDyn_LP" = "#d62728",
    "SysDyn_H" = "#1f77b4",
    "P" = "#2ca02c",
    "S" = "#ff7f0e",
    "H" = "#9467bd",
    "DRL" = "#8c564b",
    "DRH" = "#e377c2",
    "DML" = "#7f7f7f",
    "DMH" = "#bcbd22"
  )
  response_metric_labels <- c(
    "SysDyn_LP" = "SysDyn_LP (Total Eq. Low Response)",
    "SysDyn_H" = "SysDyn_H (Total Eq. High Response)"
  )
  response_metric_label <- function(metric) {
    if (metric %in% names(response_metric_labels)) {
      return(response_metric_labels[[metric]])
    }
    metric
  }

  # Reactive expression to load response holding data
  responseData <- reactive({
    req(file.exists("data/output/reports/system_dynamics_review.csv"))
    dt <- fread("data/output/reports/system_dynamics_review.csv")
    # Ensure Date is properly formatted
    if (!"Date" %in% names(dt)) {
      stop("ERROR: 'Date' column not found in system_dynamics_review.csv")
    }
    dt[, Date := as.Date(Date)]
    # SP column should already exist
    if (!"SP" %in% names(dt)) {
      stop("ERROR: 'SP' column not found in system_dynamics_review.csv")
    }
    return(dt)
  })

  # Filtered response data
  filteredResponseData <- eventReactive(input$updateResponsePlots, {
    req(input$responseStartDate, input$responseEndDate)
    df <- responseData()
    df_filtered <- df[Date >= input$responseStartDate & Date <= input$responseEndDate]
    return(df_filtered)
  }, ignoreNULL = FALSE)

  responseMonthlyChoices <- reactive({
    df <- responseData()
    if (nrow(df) == 0) return(character())
    months <- sort(unique(format(df$Date, "%Y-%m")))
    choices <- stats::setNames(months, format(as.Date(paste0(months, "-01")), "%b %Y"))
    choices
  })

  output$responseMonthlyStartUI <- renderUI({
    choices <- responseMonthlyChoices()
    if (!length(choices)) {
      return(tags$p("No data available", style = "color: #999; font-style: italic;"))
    }
    selected <- isolate(input$responseMonthlyStart)
    if (is.null(selected) || !(selected %in% choices)) {
      selected <- choices[1]
    }
    selectInput("responseMonthlyStart", "Start Month:", choices = choices, selected = selected)
  })

  output$responseMonthlyEndUI <- renderUI({
    choices <- responseMonthlyChoices()
    if (!length(choices)) {
      return(tags$p("No data available", style = "color: #999; font-style: italic;"))
    }
    selected <- isolate(input$responseMonthlyEnd)
    if (is.null(selected) || !(selected %in% choices)) {
      selected <- tail(choices, 1)
    }
    selectInput("responseMonthlyEnd", "End Month:", choices = choices, selected = selected)
  })

  responseWeeklyChoices <- reactive({
    df <- responseData()
    if (nrow(df) == 0) return(character())
    week_starts <- sort(unique(floor_date(df$Date, unit = "week", week_start = 1)))
    display <- paste0(format(week_starts, "%d %b %Y"), " (W", sprintf("%02d", isoweek(week_starts)), ")")
    stats::setNames(format(week_starts, "%Y-%m-%d"), display)
  })

  output$responseWeeklyStartUI <- renderUI({
    choices <- responseWeeklyChoices()
    if (!length(choices)) {
      return(tags$p("No data available", style = "color: #999; font-style: italic;"))
    }
    selected <- isolate(input$responseWeeklyStart)
    if (is.null(selected) || !(selected %in% choices)) {
      selected <- choices[1]
    }
    selectInput("responseWeeklyStart", "Start Week:", choices = choices, selected = selected)
  })

  output$responseWeeklyEndUI <- renderUI({
    choices <- responseWeeklyChoices()
    if (!length(choices)) {
      return(tags$p("No data available", style = "color: #999; font-style: italic;"))
    }
    selected <- isolate(input$responseWeeklyEnd)
    if (is.null(selected) || !(selected %in% choices)) {
      selected <- tail(choices, 1)
    }
    selectInput("responseWeeklyEnd", "End Week:", choices = choices, selected = selected)
  })


  # MFR Summary
  output$mfrSummaryUI <- renderUI({
    df <- filteredResponseData()
    if (nrow(df) == 0) {
      return(tags$p("No data available", style = "color: #999; font-style: italic;"))
    }

    tags$div(
      style = "padding: 10px;",
      tags$table(
        style = "width: 100%; border-collapse: collapse;",
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "P (Primary):"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.2f MW", mean(df$P, na.rm = TRUE)))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "S (Secondary):"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.2f MW", mean(df$S, na.rm = TRUE)))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "H (High):"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.2f MW", mean(df$H, na.rm = TRUE)))
        )
      )
    )
  })

  # EAC Summary
  output$eacSummaryUI <- renderUI({
    df <- filteredResponseData()
    if (nrow(df) == 0) {
      return(tags$p("No data available", style = "color: #999; font-style: italic;"))
    }

    tags$div(
      style = "padding: 10px;",
      tags$table(
        style = "width: 100%; border-collapse: collapse;",
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "DRL:"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.2f MW", mean(df$DRL, na.rm = TRUE)))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "DRH:"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.2f MW", mean(df$DRH, na.rm = TRUE)))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Total DR:"),
          tags$td(style = "padding: 5px; text-align: right;",
                  sprintf("%.2f MW", mean(df$DRL + df$DRH + df$DML + df$DMH, na.rm = TRUE)))
        )
      )
    )
  })

  # SysDyn Summary
  output$sysdynSummaryUI <- renderUI({
    df <- filteredResponseData()
    if (nrow(df) == 0) {
      return(tags$p("No data available", style = "color: #999; font-style: italic;"))
    }

    tags$div(
      style = "padding: 10px;",
      tags$table(
        style = "width: 100%; border-collapse: collapse;",
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold; color: #d62728;", "SysDyn_LP (Total Eq. Low Response):"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.2f MW", mean(df$SysDyn_LP, na.rm = TRUE)))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold; color: #1f77b4;", "SysDyn_H (Total Eq. High Response):"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.2f MW", mean(df$SysDyn_H, na.rm = TRUE)))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Coverage:"),
          tags$td(style = "padding: 5px; text-align: right;", paste(nrow(df), "SPs"))
        )
      )
    )
  })

  # Response Time Series Plot
  output$responseTimeSeriesPlot <- renderPlotly({
    df <- filteredResponseData()
    req(input$responseMetrics)

    if (nrow(df) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "No data available for selected range", size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    if (length(input$responseMetrics) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "Please select at least one metric to display", size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Create datetime for plotting - use minutes to avoid non-integer hours
    df[, datetime := Date + minutes((SP - 1) * 30)]

    # Define color palette for different metrics
    color_map <- response_metric_colors

    p <- plot_ly()

    # Add traces for each selected metric
    for (metric in input$responseMetrics) {
      if (metric %in% names(df)) {
        trace_name <- response_metric_label(metric)
        p <- p %>% add_trace(
          data = df,
          x = ~datetime,
          y = as.formula(paste0("~", metric)),
          name = trace_name,
          type = "scatter",
          mode = "lines",
          line = list(color = color_map[[metric]] %||% "#000000", width = 2)
        )
      }
    }

    p <- p %>% layout(
      xaxis = list(title = "Date"),
      yaxis = list(title = "Response Capacity (MW)"),
      legend = list(x = 0.5, y = -0.15, orientation = "h", xanchor = "center"),
      hovermode = "x unified"
    )

    return(p)
  })

  # Monthly Response Plot
  output$responseMonthlyPlot <- renderPlotly({
    df <- responseData()
    empty_plot <- function(msg) {
      plotly_empty(type = "scatter", mode = "text") %>%
        layout(
          annotations = list(
            list(
              text = msg,
              showarrow = FALSE,
              x = 0.5, y = 0.5,
              xref = "paper", yref = "paper"
            )
          ),
          xaxis = list(title = "Month"),
          yaxis = list(title = "Response Capacity (MW)")
        )
    }

    if (nrow(df) == 0) {
      return(empty_plot("No data available for selected range"))
    }

    metrics_input <- input$responseMonthlyMetrics
    if (is.null(metrics_input) || length(metrics_input) == 0) {
      metrics_input <- c("SysDyn_LP", "SysDyn_H")
    }
    metrics <- intersect(metrics_input, names(df))
    if (length(metrics) == 0) {
      return(empty_plot("Selected metrics not found in dataset"))
    }

    req(input$responseMonthlyStart, input$responseMonthlyEnd)
    start_str <- input$responseMonthlyStart
    end_str <- input$responseMonthlyEnd

    start_month <- suppressWarnings(lubridate::ymd(paste0(start_str, "-01")))
    end_month <- suppressWarnings(lubridate::ymd(paste0(end_str, "-01")))

    if (is.na(start_month) || is.na(end_month)) {
      return(empty_plot("Invalid month selection"))
    }
    if (start_month > end_month) {
      return(empty_plot("Start month must be before end month"))
    }

    df <- copy(df)
    df[, month_start := floor_date(Date, unit = "month")]
    df <- df[month_start >= start_month & month_start <= end_month]
    if (nrow(df) == 0) {
      return(empty_plot("No data available for the selected month range"))
    }

    monthly_summary <- df[, lapply(.SD, mean, na.rm = TRUE), by = month_start, .SDcols = metrics]
    if (nrow(monthly_summary) == 0) {
      return(empty_plot("No monthly aggregates available"))
    }

    monthly_long <- melt(
      monthly_summary,
      id.vars = "month_start",
      variable.name = "metric",
      value.name = "value"
    )
    monthly_long <- monthly_long[!is.na(value)]

    if (nrow(monthly_long) == 0) {
      return(empty_plot("Monthly aggregates contain no data"))
    }

    setorder(monthly_long, month_start)
    color_map <- response_metric_colors

    p <- plot_ly()
    for (metric_name in unique(monthly_long$metric)) {
      metric_data <- monthly_long[metric == metric_name]
      trace_name <- response_metric_label(metric_name)
      p <- p %>% add_trace(
        data = metric_data,
        x = ~month_start,
        y = ~value,
        name = trace_name,
        type = "scatter",
        mode = "lines+markers",
        line = list(color = color_map[[metric_name]] %||% "#000000", width = 2),
        marker = list(size = 6)
      )
    }

    p %>% layout(
      xaxis = list(title = "Month"),
      yaxis = list(title = "Average Response Capacity (MW)"),
      legend = list(orientation = "h", x = 0.5, y = -0.2, xanchor = "center"),
      hovermode = "x unified"
    )
  })

  output$responseWeeklyPlot <- renderPlotly({
    df <- responseData()
    empty_plot <- function(msg) {
      plotly_empty(type = "scatter", mode = "text") %>%
        layout(
          annotations = list(
            list(
              text = msg,
              showarrow = FALSE,
              x = 0.5, y = 0.5,
              xref = "paper", yref = "paper"
            )
          ),
          xaxis = list(title = "Week Starting"),
          yaxis = list(title = "Response Capacity (MW)")
        )
    }

    if (nrow(df) == 0) {
      return(empty_plot("No data available for selected range"))
    }

    metrics_input <- input$responseWeeklyMetrics
    if (is.null(metrics_input) || length(metrics_input) == 0) {
      metrics_input <- c("SysDyn_LP", "SysDyn_H")
    }
    metrics <- intersect(metrics_input, names(df))
    if (length(metrics) == 0) {
      return(empty_plot("Selected metrics not found in dataset"))
    }

    req(input$responseWeeklyStart, input$responseWeeklyEnd)
    start_str <- input$responseWeeklyStart
    end_str <- input$responseWeeklyEnd

    start_week <- suppressWarnings(lubridate::ymd(start_str))
    end_week <- suppressWarnings(lubridate::ymd(end_str))

    if (is.na(start_week) || is.na(end_week)) {
      return(empty_plot("Invalid week selection"))
    }
    if (start_week > end_week) {
      return(empty_plot("Start week must be before end week"))
    }

    df <- copy(df)
    df[, week_start := floor_date(Date, unit = "week", week_start = 1)]
    df <- df[week_start >= start_week & week_start <= end_week]
    if (nrow(df) == 0) {
      return(empty_plot("No data available for the selected week range"))
    }

    weekly_summary <- df[, lapply(.SD, mean, na.rm = TRUE), by = week_start, .SDcols = metrics]
    if (nrow(weekly_summary) == 0) {
      return(empty_plot("No weekly aggregates available"))
    }

    weekly_long <- melt(
      weekly_summary,
      id.vars = "week_start",
      variable.name = "metric",
      value.name = "value"
    )
    weekly_long <- weekly_long[!is.na(value)]

    if (nrow(weekly_long) == 0) {
      return(empty_plot("Weekly aggregates contain no data"))
    }

    setorder(weekly_long, week_start)
    weekly_long[, week_label := paste0(
      format(week_start, "%Y"),
      "-W",
      sprintf("%02d", lubridate::isoweek(week_start))
    )]
    weekly_long[, week_label := factor(week_label, levels = unique(week_label))]
    color_map <- response_metric_colors

    p <- plot_ly()
    for (metric_name in unique(weekly_long$metric)) {
      metric_data <- weekly_long[metric == metric_name]
      trace_name <- response_metric_label(metric_name)
      p <- p %>% add_trace(
        data = metric_data,
        x = ~week_label,
        y = ~value,
        name = trace_name,
        type = "scatter",
        mode = "lines+markers",
        line = list(color = color_map[[metric_name]] %||% "#000000", width = 2),
        marker = list(size = 6)
      )
    }

    p %>% layout(
      xaxis = list(title = "ISO Week", type = "category"),
      yaxis = list(title = "Average Response Capacity (MW)"),
      legend = list(orientation = "h", x = 0.5, y = -0.2, xanchor = "center"),
      hovermode = "x unified"
    )
  })

  # Response Data Table
  output$responseDataTable <- DT::renderDataTable({
    df <- filteredResponseData()
    if (nrow(df) == 0) return(data.table())

    display_cols <- c("Date", "SP", "P", "S", "H", "DRL", "DRH", "DML", "DMH", "SysDyn_LP", "SysDyn_H")
    df_display <- df[, .SD, .SDcols = intersect(display_cols, names(df))]

    datatable(df_display,
              options = list(pageLength = 15, scrollX = TRUE),
              rownames = FALSE) %>%
      formatRound(columns = c("P", "S", "H", "DRL", "DRH", "DML", "DMH", "SysDyn_LP", "SysDyn_H"), digits = 2)
  })

  # --- Imbalance Analysis Tab Logic ---

  # Reactive expression to load imbalance data
  imbalanceSummaryData <- reactive({
    req(file.exists("data/output/imbalance/imbalance_summary.csv"))
    dt <- fread("data/output/imbalance/imbalance_summary.csv")
    # Parse date from boundary_time and standardize column names
    dt[, date := as.POSIXct(boundary_time, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")]
    # Rename columns to match dashboard expectations
    setnames(dt,
             old = c("event_category", "event_severity", "max_abs_imbalance_mw", "mean_imbalance_mw"),
             new = c("category", "severity", "imbalance_peak_mw", "imbalance_mean_mw"),
             skip_absent = TRUE)
    # Add abs_freq_change column (calculate from min/max freq)
    dt[, abs_freq_change := max_freq_hz - min_freq_hz]
    return(dt)
  })

  imbalanceDetailData <- reactive({
    req(file.exists("data/output/imbalance/sp_boundary_imbalances.csv"))
    dt <- fread("data/output/imbalance/sp_boundary_imbalances.csv")
    # Parse date from boundary_time and rename columns
    dt[, date := as.POSIXct(boundary_time, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")]
    setnames(dt,
             old = c("event_category", "event_severity"),
             new = c("category", "severity"),
             skip_absent = TRUE)
    return(dt)
  })

  filteredImbalanceEvents <- reactive({
    df <- imbalanceSummaryData()
    if (nrow(df) == 0) return(df)
    if (input$imbalanceEventFilter == "top10") {
      setorder(df, -severity)
      df <- head(df, 10)
    } else if (input$imbalanceEventFilter == "latest10") {
      setorder(df, -date, -starting_sp)
      df <- head(df, 10)
    } else {
      setorder(df, -severity)
    }
    df
  })

  imbalanceEventIndex <- reactiveVal(1)

  observeEvent(filteredImbalanceEvents(), {
    imbalanceEventIndex(1)
  })

  observeEvent(input$imbalancePrev, {
    df <- filteredImbalanceEvents()
    if (nrow(df) == 0) return()
    imbalanceEventIndex(max(1, imbalanceEventIndex() - 1))
  })

  observeEvent(input$imbalanceNext, {
    df <- filteredImbalanceEvents()
    if (nrow(df) == 0) return()
    imbalanceEventIndex(min(nrow(df), imbalanceEventIndex() + 1))
  })

  currentImbalanceEvent <- reactive({
    df <- filteredImbalanceEvents()
    if (nrow(df) == 0) return(NULL)
    idx <- imbalanceEventIndex()
    idx <- min(max(idx, 1), nrow(df))
    df[idx]
  })

  output$imbalanceEventLabel <- renderUI({
    ev <- currentImbalanceEvent()
    if (is.null(ev)) {
      return(div(style = "margin-top: 25px;", tags$em("No events available")))
    }
    tags$div(
      style = "margin-top: 15px;",
      tags$strong(format(ev$date, "%Y-%m-%d %H:%M")),
      tags$br(),
      paste0("SP ", ev$starting_sp, " | Severity ", sprintf("%.1f", ev$severity))
    )
  })

  currentImbalanceEventId <- reactive({
    ev <- currentImbalanceEvent()
    if (is.null(ev)) return(NA_character_)
    ev$event_id
  })

  # Event Details

  # Frequency Event Plot
  output$imbalanceFrequencyPlot <- renderPlotly({
    req(currentImbalanceEventId())

    df_detail <- imbalanceDetailData()

    if (nrow(df_detail) == 0 || is.na(currentImbalanceEventId())) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "No data available. Adjust filters or use the navigation buttons.", size = 5) +
        theme_void()
      return(ggplotly(p))
    }

    # Use event_id to filter for this event
    event_data <- df_detail[event_id == currentImbalanceEventId()]

    if (nrow(event_data) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "No frequency data found for this event", size = 5) +
        theme_void()
      return(ggplotly(p))
    }

    # Ensure dtm_sec is POSIXct
    event_data[, dtm_sec := as.POSIXct(dtm_sec)]

    # Create dual-axis plot with frequency and RoCoF
    p <- plot_ly(event_data)

    # Add frequency line
    p <- p %>% add_trace(
      x = ~dtm_sec,
      y = ~f,
      name = "Frequency",
      type = "scatter",
      mode = "lines",
      line = list(color = "#1f77b4", width = 2),
      yaxis = "y1"
    )

    # Add 50 Hz reference line
    p <- p %>% add_trace(
      x = range(event_data$dtm_sec),
      y = c(50, 50),
      name = "50 Hz Reference",
      type = "scatter",
      mode = "lines",
      line = list(color = "gray50", dash = "dash", width = 1),
      showlegend = FALSE,
      yaxis = "y1"
    )

    # Add RoCoF line on secondary axis
    p <- p %>% add_trace(
      x = ~dtm_sec,
      y = ~rocof,
      name = "RoCoF",
      type = "scatter",
      mode = "lines",
      line = list(color = "#ff7f0e", width = 2),
      yaxis = "y2"
    )

    p <- p %>% layout(
      xaxis = list(title = "Time"),
      yaxis = list(
        title = "Frequency (Hz)",
        side = "left",
        showgrid = TRUE
      ),
      yaxis2 = list(
        title = "RoCoF (Hz/s)",
        side = "right",
        overlaying = "y",
        showgrid = FALSE
      ),
      legend = list(x = 0.5, y = -0.15, orientation = "h", xanchor = "center"),
      hovermode = "x unified"
    )

    return(p)
  })

  # Imbalance Time Series Plot
  output$imbalanceTimeSeriesPlot <- renderPlotly({
    req(currentImbalanceEventId())

    df_detail <- imbalanceDetailData()

    if (nrow(df_detail) == 0 || is.na(currentImbalanceEventId())) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "No data available. Adjust filters or use the navigation buttons.", size = 5) +
        theme_void()
      return(ggplotly(p))
    }

    # Use event_id to filter for this event
    event_data <- df_detail[event_id == currentImbalanceEventId()]

    if (nrow(event_data) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "No imbalance data found for this event", size = 5) +
        theme_void()
      return(ggplotly(p))
    }

    # Ensure dtm_sec is POSIXct
    event_data[, dtm_sec := as.POSIXct(dtm_sec)]

    p <- ggplot(event_data, aes(x = dtm_sec, y = imbalance_mw)) +
      geom_line(color = "#d62728", linewidth = 1) +
      geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
      labs(
        x = "Time",
        y = "Power Imbalance (MW)"
      ) +
      theme_minimal(base_size = 11)

    ggplotly(p, tooltip = c("x", "y"))
  })

  # Imbalance Summary Table

  # Reactive expression to load system dynamics data
  systemData <- reactive({
    req(file.exists("data/output/reports/system_dynamics_review.csv"))
    dt <- fread("data/output/reports/system_dynamics_review.csv")
    dt[, Date := as.Date(Date)]
    return(dt)
  })

  # Reactive expression to load monthly excursion data
  monthlyExcursionData <- reactive({
    req(file.exists("data/output/reports/frequency_excursion_monthly.csv"))
    dt <- fread("data/output/reports/frequency_excursion_monthly.csv")
    dt[, month := as.Date(month)]
    return(dt)
  })

  monthlyExcursionFilteredData <- eventReactive(input$updateExcursionMonthly, {
    df <- monthlyExcursionData()
    if (!nrow(df)) return(data.table())

    req(input$excursionMonthlyStart, input$excursionMonthlyEnd)
    start_month <- as.Date(input$excursionMonthlyStart)
    end_month <- as.Date(input$excursionMonthlyEnd)
    thresholds <- input$excursionMonthlyThresholds
    if (is.null(thresholds) || !length(thresholds)) {
      thresholds <- unique(df$threshold)
    } else {
      thresholds <- suppressWarnings(as.numeric(thresholds))
    }

    if (is.na(start_month) || is.na(end_month) || start_month > end_month) {
      return(data.table())
    }

    df <- df[month >= start_month & month <= end_month & threshold %in% thresholds]
    return(df)
  }, ignoreNULL = FALSE)

  weeklyExcursionFilteredData <- eventReactive(input$updateExcursionWeekly, {
    df <- excursionDailyData()
    if (!nrow(df)) return(data.table())

    req(input$excursionWeeklyStart, input$excursionWeeklyEnd)
    start_week <- as.Date(input$excursionWeeklyStart)
    end_week <- as.Date(input$excursionWeeklyEnd)
    thresholds <- input$excursionWeeklyThresholds
    if (is.null(thresholds) || !length(thresholds)) {
      thresholds <- unique(df$threshold)
    } else {
      thresholds <- suppressWarnings(as.numeric(thresholds))
    }

    if (is.na(start_week) || is.na(end_week) || start_week > end_week) {
      return(data.table())
    }

    df <- df[date >= start_week & date <= end_week & threshold %in% thresholds]
    return(df)
  }, ignoreNULL = FALSE)

  # Reactive expression to load monthly imbalance data
  monthlyImbalanceData <- reactive({
    req(file.exists("data/output/reports/monthly_imbalance_summary.csv"))
    dt <- fread("data/output/reports/monthly_imbalance_summary.csv")
    dt[, month := as.Date(paste0(month, "-01"))]
    return(dt)
  })

  # Reactive expression to load monthly unforeseen comparison data
  monthlyUnforeseenComparisonData <- reactive({
    req(file.exists("data/output/reports/monthly_unforeseen_comparison.csv"))
    dt <- fread("data/output/reports/monthly_unforeseen_comparison.csv")
    return(dt)
  })

  excursionMonthlyEmptyPlot <- function(message) {
    ggplotly(
      ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = message, size = 6) +
        theme_void()
    )
  }

  # --- KPI Tab Logic ---

  kpiMonthlyFilteredData <- eventReactive(input$updateKpiMonthlyPlot, {
    df <- kpiData()
    req(input$kpiMonthlyStartDate, input$kpiMonthlyEndDate)
    start_date <- as.Date(input$kpiMonthlyStartDate)
    end_date <- as.Date(input$kpiMonthlyEndDate)
    if (is.na(start_date) || is.na(end_date)) {
      return(df[0])
    }
    if (start_date > end_date) {
      return(df[0])
    }
    df[date >= start_date & date <= end_date]
  }, ignoreNULL = FALSE)

  kpiWeeklyFilteredData <- eventReactive(input$updateKpiWeeklyPlot, {
    df <- kpiData()
    req(input$kpiWeeklyStartDate, input$kpiWeeklyEndDate)
    start_date <- as.Date(input$kpiWeeklyStartDate)
    end_date <- as.Date(input$kpiWeeklyEndDate)
    if (is.na(start_date) || is.na(end_date)) {
      return(df[0])
    }
    if (start_date > end_date) {
      return(df[0])
    }
    df[date >= start_date & date <= end_date]
  }, ignoreNULL = FALSE)

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

  # 2. Time Series - Daily Quality Metrics
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

  # ========================================================================
  # MONTHLY TRENDS TAB - Server Logic
  # ========================================================================

  # Reactive data filtering for monthly trends
  monthlyFilteredData <- eventReactive(input$updateMonthlyPlots, {
    list(
      events = eventData(),
      system = systemData(),
      kpi = kpiData(),
      excursions = monthlyExcursionData(),
      imbalance = monthlyImbalanceData(),
      unforeseen_comparison = monthlyUnforeseenComparisonData(),
      start_date = input$monthlyStartDate,
      end_date = input$monthlyEndDate,
      metric = input$monthlyMetric
    )
  }, ignoreNULL = FALSE)

  # Monthly Frequency KPI (moved to KPI tab)
  output$monthlyQualityMetrics <- renderPlotly({
    df <- kpiMonthlyFilteredData()
    start_date <- suppressWarnings(as.Date(input$kpiMonthlyStartDate))
    end_date <- suppressWarnings(as.Date(input$kpiMonthlyEndDate))
    selected_categories <- input$kpiMonthlyCategories

    empty_plot <- function(msg) {
      ggplotly(
        ggplot() +
          annotate("text", x = 0.5, y = 0.5, label = msg, size = 6) +
          theme_void()
      )
    }

    if (!is.na(start_date) && !is.na(end_date) && start_date > end_date) {
      return(empty_plot("Start month must be before end month."))
    }

    if (is.null(df) || nrow(df) == 0) {
      return(empty_plot("No KPI data available for selected range"))
    }

    df[, month := format(date, "%Y-%m")]
    monthly_kpi <- df[, .(
      Red = mean(percentage_red, na.rm = TRUE),
      Amber = mean(percentage_amber, na.rm = TRUE),
      Blue = mean(percentage_blue, na.rm = TRUE),
      Green = mean(percentage_green, na.rm = TRUE)
    ), by = month]

    if (nrow(monthly_kpi) == 0) {
      return(empty_plot("No data in selected date range"))
    }

    monthly_kpi_long <- melt(
      monthly_kpi,
      id.vars = "month",
      variable.name = "Category",
      value.name = "Percentage"
    )
    monthly_kpi_long <- monthly_kpi_long[order(month)]

    if (is.null(selected_categories) || length(selected_categories) == 0) {
      return(empty_plot("Please select at least one quality category."))
    }
    monthly_kpi_long <- monthly_kpi_long[Category %in% selected_categories]
    if (nrow(monthly_kpi_long) == 0) {
      return(empty_plot("Selected categories have no data in this range."))
    }

    p <- ggplot(monthly_kpi_long, aes(x = month, y = Percentage, color = Category, group = Category)) +
      geom_line(linewidth = 1.2) +
      geom_point(size = 3) +
      scale_color_manual(
        name = "Quality Category",
        values = c("Red" = "#d62728", "Amber" = "#ff7f0e", "Blue" = "#1f77b4", "Green" = "#2ca02c")[selected_categories]
      ) +
      labs(
        x = "Month",
        y = "Average Percentage (%)"
      ) +
      theme_minimal(base_size = 12) +
      theme(
        legend.position = "right",
        axis.text.x = element_text(angle = 45, hjust = 1),
        panel.grid.major = element_line(color = "gray90"),
        panel.grid.minor = element_blank()
      )

    ggplotly(p, tooltip = c("x", "y", "colour")) %>%
      layout(
        xaxis = list(title = "Month"),
        yaxis = list(title = "Average Percentage (%)"),
        legend = list(orientation = "v", x = 1.02, y = 0.5)
      )
  })

  output$weeklyQualityMetrics <- renderPlotly({
    df <- kpiWeeklyFilteredData()
    start_date <- suppressWarnings(as.Date(input$kpiWeeklyStartDate))
    end_date <- suppressWarnings(as.Date(input$kpiWeeklyEndDate))
    selected_categories <- input$kpiWeeklyCategories

    empty_plot <- function(msg) {
      ggplotly(
        ggplot() +
          annotate("text", x = 0.5, y = 0.5, label = msg, size = 6) +
          theme_void()
      )
    }

    if (!is.na(start_date) && !is.na(end_date) && start_date > end_date) {
      return(empty_plot("Start week must be before end week."))
    }
    if (is.null(df) || nrow(df) == 0) {
      return(empty_plot("No KPI data available for selected range"))
    }

    df[, week_start := lubridate::floor_date(date, unit = "week", week_start = 1)]
    weekly_kpi <- df[, .(
      Red = mean(percentage_red, na.rm = TRUE),
      Amber = mean(percentage_amber, na.rm = TRUE),
      Blue = mean(percentage_blue, na.rm = TRUE),
      Green = mean(percentage_green, na.rm = TRUE)
    ), by = week_start]

    if (nrow(weekly_kpi) == 0) {
      return(empty_plot("No data in selected date range"))
    }

    weekly_kpi_long <- melt(
      weekly_kpi,
      id.vars = "week_start",
      variable.name = "Category",
      value.name = "Percentage"
    )
    setorder(weekly_kpi_long, week_start)

    if (is.null(selected_categories) || length(selected_categories) == 0) {
      return(empty_plot("Please select at least one quality category."))
    }
    weekly_kpi_long <- weekly_kpi_long[Category %in% selected_categories]
    if (nrow(weekly_kpi_long) == 0) {
      return(empty_plot("Selected categories have no data in this range."))
    }

    week_breaks <- sort(unique(weekly_kpi_long$week_start))
    if (length(week_breaks) > 14) {
      step <- ceiling(length(week_breaks) / 14)
      week_breaks <- week_breaks[seq(1, length(week_breaks), by = step)]
    }
    label_fun <- function(x) paste0("W", format(x, "%V"), "\n", format(x, "%d %b"))

    p <- ggplot(weekly_kpi_long, aes(x = week_start, y = Percentage, color = Category, group = Category)) +
      geom_line(linewidth = 1.1) +
      geom_point(size = 2.5) +
      scale_color_manual(
        name = "Quality Category",
        values = c("Red" = "#d62728", "Amber" = "#ff7f0e", "Blue" = "#1f77b4", "Green" = "#2ca02c")[selected_categories]
      ) +
      scale_x_date(breaks = week_breaks, labels = label_fun) +
      labs(
        x = "Week Starting",
        y = "Average Percentage (%)"
      ) +
      theme_minimal(base_size = 11) +
      theme(
        legend.position = "bottom",
        axis.text.x = element_text(angle = 45, hjust = 1)
      )

    ggplotly(p, tooltip = c("x", "y", "colour")) %>%
      layout(
        xaxis = list(
          title = "Week Starting",
          tickformat = "%Y-W%V",
          tickangle = -45
        ),
        yaxis = list(title = "Average Percentage (%)"),
        legend = list(orientation = "h", x = 0.2, y = -0.2)
      )
  })

  output$excursionMonthlyCountPlot <- renderPlotly({
    df <- monthlyExcursionFilteredData()
    if (is.null(df) || nrow(df) == 0) {
      return(excursionMonthlyEmptyPlot("No excursion data for selected range"))
    }

    df <- copy(df)
    df[, month_label := format(month, "%Y-%m")]
    df[, month_label := factor(month_label, levels = unique(month_label))]
    df[, threshold_label := sprintf(">= %.2f Hz", threshold)]

    color_levels <- unique(df$threshold)
    color_map <- setNames(sapply(color_levels, getExcursionColor), sprintf(">= %.2f Hz", color_levels))

    p <- ggplot(df, aes(x = month_label, y = num_excursions, color = threshold_label, group = threshold_label)) +
      geom_line(linewidth = 1.1) +
      geom_point(size = 3) +
      scale_color_manual(values = color_map, name = "Threshold") +
      labs(x = "Month", y = "Number of Excursions") +
      theme_minimal(base_size = 11) +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))

    ggplotly(p, tooltip = c("x", "y", "colour")) %>%
      layout(
        xaxis = list(title = "Month"),
        yaxis = list(title = "Number of Excursions"),
        legend = list(orientation = "h", x = 0.5, y = -0.25, xanchor = "center")
      )
  })

  output$excursionMonthlyDurationPlot <- renderPlotly({
    df <- monthlyExcursionFilteredData()
    if (is.null(df) || nrow(df) == 0) {
      return(excursionMonthlyEmptyPlot("No excursion data for selected range"))
    }

    df <- copy(df)
    df[, month_label := format(month, "%Y-%m")]
    df[, month_label := factor(month_label, levels = unique(month_label))]
    df[, threshold_label := sprintf(">= %.2f Hz", threshold)]
    df[, duration_hours := total_duration_sec / 3600]

    color_levels <- unique(df$threshold)
    color_map <- setNames(sapply(color_levels, getExcursionColor), sprintf(">= %.2f Hz", color_levels))

    p <- ggplot(df, aes(x = month_label, y = duration_hours, color = threshold_label, group = threshold_label)) +
      geom_line(linewidth = 1.1) +
      geom_point(size = 3) +
      scale_color_manual(values = color_map, name = "Threshold") +
      labs(x = "Month", y = "Duration (hours)") +
      theme_minimal(base_size = 11) +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))

    ggplotly(p, tooltip = c("x", "y", "colour")) %>%
      layout(
        xaxis = list(title = "Month"),
        yaxis = list(title = "Duration (hours)"),
        legend = list(orientation = "h", x = 0.5, y = -0.25, xanchor = "center")
      )
  })

  output$excursionMonthlyPercentagePlot <- renderPlotly({
    df <- monthlyExcursionFilteredData()
    if (is.null(df) || nrow(df) == 0) {
      return(excursionMonthlyEmptyPlot("No excursion data for selected range"))
    }

    df <- copy(df)
    df[, month_label := format(month, "%Y-%m")]
    df[, month_label := factor(month_label, levels = unique(month_label))]
    df[, threshold_label := sprintf(">= %.2f Hz", threshold)]
    df[, total_seconds := lubridate::days_in_month(month) * 24 * 3600]
    df[, pct_time := pmin(100, (total_duration_sec / total_seconds) * 100)]

    color_levels <- unique(df$threshold)
    color_map <- setNames(sapply(color_levels, getExcursionColor), sprintf(">= %.2f Hz", color_levels))

    p <- ggplot(df, aes(x = month_label, y = pct_time, color = threshold_label, group = threshold_label)) +
      geom_line(linewidth = 1.1) +
      geom_point(size = 3) +
      scale_color_manual(values = color_map, name = "Threshold") +
      labs(x = "Month", y = "Percentage of Time (%)") +
      theme_minimal(base_size = 11) +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))

    ggplotly(p, tooltip = c("x", "y", "colour")) %>%
      layout(
        xaxis = list(title = "Month"),
        yaxis = list(title = "Percentage of Time (%)"),
        legend = list(orientation = "h", x = 0.5, y = -0.25, xanchor = "center")
      )
  })

  buildWeeklyExcursionPlot <- function(df, value_col, y_label) {
    if (is.null(df) || nrow(df) == 0) {
      return(excursionMonthlyEmptyPlot("No excursion data for selected range"))
    }

    df <- copy(df)
    df[, week_start := lubridate::floor_date(date, unit = "week", week_start = 1)]
    df_summary <- df[, .(
      num_excursions = sum(num_excursions, na.rm = TRUE),
      total_duration_sec = sum(total_duration_sec, na.rm = TRUE),
      days = .N
    ), by = .(week_start, threshold)]

    if (nrow(df_summary) == 0) {
      return(excursionMonthlyEmptyPlot("No excursion data for selected range"))
    }

    df_summary[, duration_hours := total_duration_sec / 3600]
    df_summary[, pct_time := pmin(100, (total_duration_sec / (days * 24 * 3600)) * 100)]

    df_summary[, threshold_label := sprintf(">= %.2f Hz", threshold)]

    draw_df <- df_summary[, .(week_start, threshold_label, value = get(value_col)), by = .(week_start, threshold_label)]
    draw_df <- draw_df[!is.na(value)]
    if (nrow(draw_df) == 0) {
      return(excursionMonthlyEmptyPlot("No excursion data for selected metric"))
    }

    color_levels <- unique(df_summary$threshold)
    color_map <- setNames(sapply(color_levels, getExcursionColor), sprintf(">= %.2f Hz", color_levels))

    week_breaks <- sort(unique(draw_df$week_start))
    if (length(week_breaks) > 14) {
      step <- ceiling(length(week_breaks) / 14)
      week_breaks <- week_breaks[seq(1, length(week_breaks), by = step)]
    }
    label_fun <- function(x) paste0("W", format(x, "%V"), "\n", format(x, "%d %b"))

    p <- ggplot(draw_df, aes(x = week_start, y = value, color = threshold_label, group = threshold_label)) +
      geom_line(linewidth = 1.1) +
      geom_point(size = 2.8) +
      scale_color_manual(values = color_map, name = "Threshold") +
      scale_x_date(breaks = week_breaks, labels = label_fun) +
      labs(x = "Week Starting", y = y_label) +
      theme_minimal(base_size = 11) +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))

    ggplotly(p, tooltip = c("x", "y", "colour")) %>%
      layout(
        xaxis = list(title = "Week Starting"),
        yaxis = list(title = y_label),
        legend = list(orientation = "h", x = 0.5, y = -0.25, xanchor = "center")
      )
  }

  output$excursionWeeklyCountPlot <- renderPlotly({
    df <- weeklyExcursionFilteredData()
    buildWeeklyExcursionPlot(df, "num_excursions", "Number of Excursions")
  })

  output$excursionWeeklyDurationPlot <- renderPlotly({
    df <- weeklyExcursionFilteredData()
    buildWeeklyExcursionPlot(df, "duration_hours", "Duration (hours)")
  })

  output$excursionWeeklyPercentagePlot <- renderPlotly({
    df <- weeklyExcursionFilteredData()
    buildWeeklyExcursionPlot(df, "pct_time", "Percentage of Time (%)")
  })

  # Panel 2: Monthly Frequency Excursion Percentage by Threshold
  output$monthlyRedRatio <- renderPlotly({
    data <- monthlyFilteredData()
    df <- data$excursions

    if (is.null(df) || nrow(df) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5,
                 label = "No excursion data available", size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Filter by date range
    df_filtered <- df[month >= data$start_date & month <= data$end_date]

    if (nrow(df_filtered) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5,
                 label = "No data in selected date range", size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Calculate percentage of time for each threshold
    # Total seconds in a month varies, so calculate for each month
    df_filtered[, month_year := format(month, "%Y-%m")]
    df_filtered[, days_in_month := as.numeric(difftime(
      as.Date(paste0(month_year, "-01")) + months(1),
      as.Date(paste0(month_year, "-01")),
      units = "days"
    ))]
    df_filtered[, total_seconds_in_month := days_in_month * 24 * 3600]
    df_filtered[, excursion_percentage := (total_duration_sec / total_seconds_in_month) * 100]

    # Create threshold labels
    df_filtered[, threshold_label := paste0(">= ", threshold, " Hz")]

    # Order months chronologically
    df_filtered <- df_filtered[order(month)]

    # Create time series line plot
    p <- ggplot(df_filtered, aes(x = month_year, y = excursion_percentage,
                                   color = threshold_label, group = threshold_label)) +
      geom_line(linewidth = 1.2) +
      geom_point(size = 3) +
      scale_color_manual(
        name = "Excursion Threshold",
        values = c(
          ">= 0.1 Hz" = "#1f77b4",
          ">= 0.15 Hz" = "#ff7f0e",
          ">= 0.2 Hz" = "#d62728"
        )
      ) +
      labs(
        x = "Month",
        y = "Percentage of Time (%)"
      ) +
      theme_minimal(base_size = 12) +
      theme(
        legend.position = "right",
        axis.text.x = element_text(angle = 45, hjust = 1),
        panel.grid.major = element_line(color = "gray90"),
        panel.grid.minor = element_blank()
      )

    ggplotly(p, tooltip = c("x", "y", "colour")) %>%
      layout(
        xaxis = list(title = "Month"),
        yaxis = list(title = "Percentage of Time (%)"),
        legend = list(orientation = "v", x = 1.02, y = 0.5)
      )
  })

  # Panel 4: Monthly Unforeseen vs Total Demand Change Comparison
  output$monthlyUnforeseenComparison <- renderPlotly({
    data <- monthlyFilteredData()
    df <- data$unforeseen_comparison
    selected_metric <- data$metric

    if (is.null(df) || nrow(df) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5,
                 label = "No monthly unforeseen comparison data available", size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Filter by metric and date range
    df_filtered <- df[metric == selected_metric]
    df_filtered[, month_date := as.Date(paste0(month, "-01"))]
    df_filtered <- df_filtered[month_date >= data$start_date & month_date <= data$end_date]

    if (nrow(df_filtered) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5,
                 label = "No data in selected date range", size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Reshape to long format for plotting
    comparison_long <- melt(df_filtered,
                           id.vars = "month",
                           measure.vars = c("mean_total_change_mw", "mean_unforeseen_mw"),
                           variable.name = "Component",
                           value.name = "MW")

    # Create labels
    comparison_long[, component_label := fcase(
      Component == "mean_total_change_mw", "Total Demand Change",
      Component == "mean_unforeseen_mw", "Unforeseen Component"
    )]

    # Order chronologically
    comparison_long <- comparison_long[order(month)]

    # Create dual-line comparison plot
    p <- ggplot(comparison_long, aes(x = month, y = MW,
                                      color = component_label, group = component_label)) +
      geom_line(linewidth = 1.2) +
      geom_point(size = 3) +
      scale_color_manual(
        name = "Component",
        values = c(
          "Total Demand Change" = "#1f77b4",
          "Unforeseen Component" = "#d62728"
        )
      ) +
      labs(
        x = "Month",
        y = "Mean Absolute Change (MW)"
      ) +
      theme_minimal(base_size = 12) +
      theme(
        legend.position = "right",
        axis.text.x = element_text(angle = 45, hjust = 1),
        panel.grid.major = element_line(color = "gray90"),
        panel.grid.minor = element_blank()
      )

    ggplotly(p, tooltip = c("x", "y", "colour")) %>%
      layout(
        xaxis = list(title = "Month"),
        yaxis = list(title = "Mean Absolute Change (MW)"),
        legend = list(orientation = "v", x = 1.02, y = 0.5)
      )
  })
}

# ===================================================================
# Run the Application
# ===================================================================
shinyApp(ui, server)
