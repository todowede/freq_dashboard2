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
      menuItem("Monthly Red Ratio", tabName = "plots", icon = icon("chart-line")),
      menuItem("Response Holding", tabName = "response", icon = icon("battery-full")),
      menuItem("Imbalance Analysis", tabName = "imbalance", icon = icon("balance-scale")),
      menuItem("Demand Analysis", tabName = "demand", icon = icon("plug")),
      menuItem("Unforeseen Demand", tabName = "unforeseen", icon = icon("exclamation-triangle")),
      menuItem("Unforeseen Patterns", tabName = "unforeseen_patterns", icon = icon("chart-line"))
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
                                       value = as.Date("2025-05-01"),
                                       min = as.Date("2025-01-01"),
                                       max = as.Date("2025-09-30")),
                             dateInput("overviewEndDate", "End Date:",
                                       value = as.Date("2025-05-01"),
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
              fluidRow(
                box(
                  title = "Filter Options", status = "warning", solidHeader = TRUE, width = 12,
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
                  # Add style to prevent clipping of date picker dropdown
                  tags$style(HTML("
                    .box-body { overflow: visible !important; }
                    .datepicker { z-index: 9999 !important; }
                  ")),
                  fluidRow(
                    column(3,
                           dateInput("excursionStartDate", "Start Date:",
                                     value = as.Date("2025-05-01"),
                                     min = as.Date("2025-01-01"),
                                     max = as.Date("2025-09-30"))
                    ),
                    column(3,
                           dateInput("excursionEndDate", "End Date:",
                                     value = as.Date("2025-05-01"),
                                     min = as.Date("2025-01-01"),
                                     max = as.Date("2025-09-30"))
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

      # -- Monthly Red Ratio Tab --
      tabItem(tabName = "plots",
              fluidRow(
                box(
                  title = "Monthly Red Event Ratio Plots", status = "info", solidHeader = TRUE, width = 12,
                  p("This section displays static plots showing the monthly Red event ratio trends - the percentage of SP boundaries that were classified as Red events each month."),
                  uiOutput("plotGalleryUI")
                )
              )
      ),

      # -- Response Holding Tab --
      tabItem(tabName = "response",
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
                      tags$li("SysDyn_LP (Low Frequency) = P + 1.67 × (DRL + DML)"),
                      tags$li("SysDyn_H (High Frequency) = H + 1.67 × (DRH + DMH)")
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
                                     value = as.Date("2025-05-01"),
                                     min = as.Date("2025-01-01"),
                                     max = as.Date("2025-09-30"))
                    ),
                    column(3,
                           dateInput("responseEndDate", "End Date:",
                                     value = as.Date("2025-05-01"),
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
                                              choices = c("SysDyn_LP" = "SysDyn_LP",
                                                          "SysDyn_H" = "SysDyn_H",
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

      # -- Imbalance Analysis Tab --
      tabItem(tabName = "imbalance",
              fluidRow(
                box(
                  title = "Power Imbalance from Frequency Events", status = "info", solidHeader = TRUE, width = 12,
                  collapsible = TRUE, collapsed = TRUE,
                  tags$div(
                    style = "padding: 10px;",
                    tags$p("This analysis reverse-engineers the power imbalance (MW) that caused each frequency deviation."),
                    tags$p(strong("Calculation components:")),
                    tags$ul(
                      tags$li("Low frequency response (from system dynamics data)"),
                      tags$li("High frequency response"),
                      tags$li("Demand damping (2.5% per Hz)"),
                      tags$li("RoCoF component (inertia × df/dt)")
                    ),
                    tags$p(strong("Formula:"), " Imbalance = -LF_response + Demand_damping + HF_response + RoCoF_component"),
                    tags$p(style = "font-size: 12px; color: #666;",
                           strong("Note:"), " Default values used: Inertia = 150 GVA·s, Demand = 35,000 MW")
                  )
                )
              ),

              # Event Selection
              fluidRow(
                box(
                  title = "Select Event to Analyze", status = "warning", solidHeader = TRUE, width = 12,
                  fluidRow(
                    column(4,
                           selectInput("imbalanceEventFilter", "Filter Events:",
                                       choices = c("All Red Events" = "all", "Top 10 Severity" = "top10", "Latest 10" = "latest10"),
                                       selected = "top10")
                    ),
                    column(4,
                           uiOutput("imbalanceEventSelectUI")
                    ),
                    column(4,
                           br(),
                           actionButton("updateImbalancePlot", "Load Event Data",
                                        class = "btn-primary",
                                        style = "width: 100%;")
                    )
                  )
                )
              ),

              # Event Summary
              fluidRow(
                column(6,
                       box(
                         title = "Event Details", status = "danger", solidHeader = TRUE, width = NULL,
                         uiOutput("imbalanceEventDetailsUI")
                       )
                ),
                column(6,
                       box(
                         title = "Imbalance Summary", status = "primary", solidHeader = TRUE, width = NULL,
                         uiOutput("imbalanceSummaryUI")
                       )
                )
              ),

              # Frequency Event Plot
              fluidRow(
                box(
                  title = "Frequency Event (±15 seconds around SP boundary)",
                  status = "warning", solidHeader = TRUE, width = 12,
                  plotlyOutput("imbalanceFrequencyPlot", height = "400px")
                )
              ),

              # Imbalance Time Series Plot
              fluidRow(
                box(
                  title = "Power Imbalance Time Series (±15 seconds around SP boundary)",
                  status = "primary", solidHeader = TRUE, width = 12,
                  plotlyOutput("imbalanceTimeSeriesPlot", height = "400px")
                )
              ),

              # Summary Table
              fluidRow(
                box(
                  title = "All Events Imbalance Summary", status = "info", solidHeader = TRUE, width = 12,
                  DT::dataTableOutput("imbalanceSummaryTable")
                )
              )
      ),

      # -- Demand Analysis Tab --
      tabItem(tabName = "demand",
              fluidRow(
                box(
                  title = "Demand Analysis at Settlement Period Boundaries", status = "info", solidHeader = TRUE, width = 12,
                  collapsible = TRUE, collapsed = TRUE,
                  tags$div(
                    style = "padding: 10px;",
                    tags$p("This analysis examines demand patterns at each 30-minute Settlement Period (SP) boundary."),
                    tags$p(strong("Metrics tracked:")),
                    tags$ul(
                      tags$li(strong("ND:"), " National Demand"),
                      tags$li(strong("TSD:"), " Transmission System Demand"),
                      tags$li(strong("ENGLAND_WALES_DEMAND:"), " England & Wales Demand")
                    ),
                    tags$p(strong("Analysis includes:")),
                    tags$ul(
                      tags$li("Demand changes (ΔMW) across SP boundaries"),
                      tags$li("Correlation with frequency events"),
                      tags$li("Daily peak demand identification"),
                      tags$li("Hourly demand patterns")
                    )
                  )
                )
              ),

              # Filter Options
              fluidRow(
                box(
                  title = "Filter Options", status = "warning", solidHeader = TRUE, width = 12,
                  # Add style to prevent clipping of date picker dropdown
                  tags$style(HTML("
                    .box-body { overflow: visible !important; }
                    .datepicker { z-index: 9999 !important; }
                  ")),
                  fluidRow(
                    column(3,
                           radioButtons("demandFilterMode", "Filter By:",
                                        choices = c("Date Range" = "date_range", "Month" = "month"),
                                        selected = "date_range")
                    ),
                    column(4,
                           conditionalPanel(
                             condition = "input.demandFilterMode == 'date_range'",
                             dateInput("demandStartDate", "Start Date:",
                                       value = as.Date("2025-05-01"),
                                       min = as.Date("2025-01-01"),
                                       max = as.Date("2025-09-30")),
                             dateInput("demandEndDate", "End Date:",
                                       value = as.Date("2025-05-01"),
                                       min = as.Date("2025-01-01"),
                                       max = as.Date("2025-09-30"))
                           ),
                           conditionalPanel(
                             condition = "input.demandFilterMode == 'month'",
                             selectInput("demandMonthFilter", "Select Month:", choices = NULL, multiple = FALSE)
                           )
                    ),
                    column(2,
                           br(),
                           actionButton("updateDemandPlots", "Update Plots",
                                        class = "btn-primary",
                                        style = "width: 100%; margin-top: 5px;")
                    )
                  )
                )
              ),

              # Summary Statistics
              fluidRow(
                column(4,
                       box(
                         title = "Demand Statistics", status = "primary", solidHeader = TRUE, width = NULL,
                         uiOutput("demandStatsUI")
                       )
                ),
                column(4,
                       box(
                         title = "Peak Demand", status = "danger", solidHeader = TRUE, width = NULL,
                         uiOutput("demandPeakUI")
                       )
                ),
                column(4,
                       box(
                         title = "Event Correlation", status = "warning", solidHeader = TRUE, width = NULL,
                         uiOutput("demandEventCorrelationUI")
                       )
                )
              ),

              # Plots
              fluidRow(
                box(
                  title = "Demand Time Series",
                  status = "primary", solidHeader = TRUE, width = 12,
                  plotlyOutput("demandTimeSeriesPlot", height = "500px")
                )
              ),

              fluidRow(
                box(
                  title = "Demand Changes at SP Boundaries",
                  status = "info", solidHeader = TRUE, width = 12,
                  plotlyOutput("demandChangesPlot", height = "400px")
                )
              ),

              fluidRow(
                box(
                  title = "Hourly Demand Pattern",
                  status = "success", solidHeader = TRUE, width = 12,
                  plotlyOutput("demandHourlyPlot", height = "400px")
                )
              ),

              # Data Tables
              fluidRow(
                box(
                  title = "Demand Data at SP Boundaries", status = "info", solidHeader = TRUE, width = 12,
                  DT::dataTableOutput("demandDataTable")
                )
              )
      ),

      # -- Unforeseen Demand Events Tab --
      tabItem(tabName = "unforeseen",
              fluidRow(
                box(
                  title = "Unforeseen Demand Change Analysis with Demand Damping Separation",
                  status = "info", solidHeader = TRUE, width = 12,
                  collapsible = TRUE, collapsed = TRUE,
                  tags$div(
                    style = "padding: 10px;",
                    tags$p(strong("Business Context:")),
                    tags$p("Price signals cause coordinated demand changes at SP boundaries that NESO cannot anticipate. This analysis separates:"),
                    tags$ul(
                      tags$li(strong("Market-driven changes"), " (unforeseen - require extra reserve)"),
                      tags$li(strong("Natural damping response"), " (helpful - automatic stabilization)")
                    ),
                    tags$p(strong("Demand Damping:")),
                    tags$p("When frequency deviates, demand naturally responds (e.g., motors slow down when frequency drops). Formula: ΔMW_damping = Demand × 2.5% × |Δf| (NESO standard)"),
                    tags$p(strong("Unforeseen Component:")),
                    tags$p("ΔMW_unforeseen = ΔMW_total - ΔMW_damping"),
                    tags$p("Events are flagged as 'unforeseen' if they exceed 2.5 standard deviations from the hourly baseline.")
                  )
                )
              ),

              # Filter Options
              fluidRow(
                box(
                  title = "Filter Options", status = "warning", solidHeader = TRUE, width = 12,
                  # Add style to prevent clipping of date picker dropdown
                  tags$style(HTML("
                    .box-body { overflow: visible !important; }
                    .datepicker { z-index: 9999 !important; }
                  ")),
                  fluidRow(
                    column(3,
                           selectInput("unforeseenMetric", "Demand Metric:",
                                       choices = c("ND" = "ND",
                                                   "TSD" = "TSD",
                                                   "England & Wales" = "ENGLAND_WALES_DEMAND"),
                                       selected = "ND")
                    ),
                    column(3,
                           selectInput("unforeseenFilter", "Event Filter:",
                                       choices = c("All Events" = "all",
                                                   "Unforeseen Only" = "unforeseen",
                                                   "Normal Only" = "normal"),
                                       selected = "unforeseen")
                    ),
                    column(3,
                           dateInput("unforeseenStartDate", "Start Date:",
                                     value = as.Date("2025-05-01"),
                                     min = as.Date("2025-01-01"),
                                     max = as.Date("2025-09-30"))
                    ),
                    column(3,
                           dateInput("unforeseenEndDate", "End Date:",
                                     value = as.Date("2025-05-01"),
                                     min = as.Date("2025-01-01"),
                                     max = as.Date("2025-09-30"))
                    )
                  )
                )
              ),

              # Summary Statistics
              fluidRow(
                column(3,
                       box(
                         title = "Event Statistics", status = "primary", solidHeader = TRUE, width = NULL,
                         uiOutput("unforeseenStatsUI")
                       )
                ),
                column(3,
                       box(
                         title = "Deviation Magnitude", status = "danger", solidHeader = TRUE, width = NULL,
                         uiOutput("unforeseenMagnitudeUI")
                       )
                ),
                column(3,
                       box(
                         title = "Damping Component", status = "success", solidHeader = TRUE, width = NULL,
                         uiOutput("unforeseenDampingUI")
                       )
                ),
                column(3,
                       box(
                         title = "Causality", status = "warning", solidHeader = TRUE, width = NULL,
                         uiOutput("unforeseenCausalityUI")
                       )
                )
              ),

              # Time Series Plot
              fluidRow(
                box(
                  title = "Demand Changes Over Time (with Damping Separation)",
                  status = "primary", solidHeader = TRUE, width = 12,
                  plotlyOutput("unforeseenTimeSeriesPlot", height = "500px")
                )
              ),

              # SP Frequency Event Categories
              fluidRow(
                box(
                  title = "SP Frequency Event Categories",
                  status = "warning", solidHeader = TRUE, width = 12,
                  plotlyOutput("unforeseenVsFreqCategoryPlot", height = "400px")
                )
              ),

              # Frequency Profile Plot
              fluidRow(
                box(
                  title = "Frequency Profile for Selected Day",
                  status = "info", solidHeader = TRUE, width = 12,
                  plotlyOutput("unforeseenFrequencyProfilePlot", height = "400px")
                )
              ),

              # Data Table
              fluidRow(
                box(
                  title = "Unforeseen Demand Events Details", status = "info", solidHeader = TRUE, width = 12,
                  DT::dataTableOutput("unforeseenDataTable")
                )
              )
      ),

      # -- Unforeseen Patterns Tab --
      tabItem(tabName = "unforeseen_patterns",
              fluidRow(
                box(
                  title = "Unforeseen Demand Patterns Analysis",
                  status = "info", solidHeader = TRUE, width = 12,
                  collapsible = TRUE, collapsed = TRUE,
                  tags$div(
                    style = "padding: 10px;",
                    tags$p(strong("Purpose:")),
                    tags$p("Identify temporal patterns in unforeseen demand events to understand which hours, days, and periods are most problematic."),
                    tags$p(strong("Key Insights:")),
                    tags$ul(
                      tags$li("Which hours consistently have more unforeseen events?"),
                      tags$li("How do events distribute across days/weeks/months?"),
                      tags$li("Are there trending patterns over time?")
                    )
                  )
                )
              ),

              # Date Range Filter
              fluidRow(
                box(
                  title = "Filter by Date Range", status = "warning", solidHeader = TRUE, width = 12,
                  fluidRow(
                    column(3,
                           dateInput("patternsStartDate", "Start Date:",
                                     value = as.Date("2025-05-01"),
                                     min = as.Date("2025-01-01"),
                                     max = as.Date("2025-09-30"))
                    ),
                    column(3,
                           dateInput("patternsEndDate", "End Date:",
                                     value = as.Date("2025-05-01"),
                                     min = as.Date("2025-01-01"),
                                     max = as.Date("2025-09-30"))
                    ),
                    column(3,
                           selectInput("patternsMetric", "Demand Metric:",
                                       choices = c("ND", "TSD", "ENGLAND_WALES_DEMAND"),
                                       selected = "ND")
                    ),
                    column(3,
                           br(),
                           actionButton("updatePatternsPlots", "Update Plots",
                                        class = "btn-primary",
                                        style = "width: 100%;")
                    )
                  )
                )
              ),

              # Panel 1: Aggregated Bar Chart - Events per Hour
              fluidRow(
                box(
                  title = "Total Unforeseen Events by Hour of Day",
                  status = "primary", solidHeader = TRUE, width = 12,
                  plotlyOutput("patternsHourlyBarPlot", height = "400px")
                )
              ),

              # Panel 2: Heatmap - Events by Hour and Date
              fluidRow(
                box(
                  title = "Unforeseen Events Heatmap (Hour × Date)",
                  status = "info", solidHeader = TRUE, width = 12,
                  plotlyOutput("patternsHeatmapPlot", height = "500px")
                )
              ),

              # Panel 3: Time Series with Hour Filter
              fluidRow(
                box(
                  title = "Daily Event Count Time Series",
                  status = "success", solidHeader = TRUE, width = 12,
                  fluidRow(
                    column(3,
                           selectInput("patternsHourFilter", "Filter by Hour:",
                                       choices = c("All Hours" = "all", as.character(0:23)),
                                       selected = "all")
                    ),
                    column(9,
                           helpText("Select a specific hour to see trends for that hour only, or 'All Hours' to see total daily counts.")
                    )
                  ),
                  plotlyOutput("patternsTimeSeriesPlot", height = "400px")
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
    div(
      dateInput("freqStartDate", "Start Date:",
                value = as.Date("2025-05-01"),
                min = as.Date("2025-01-01"),
                max = as.Date("2025-09-30")),
      br(),
      dateInput("freqEndDate", "End Date:",
                value = as.Date("2025-05-01"),
                min = as.Date("2025-01-01"),
                max = as.Date("2025-09-30"))
    )
  })

  # Dynamic date range UI for KPI plots
  output$kpiDateRangeUI <- renderUI({
    div(
      dateInput("kpiStartDate", "Start Date:",
                value = as.Date("2025-05-01"),
                min = as.Date("2025-01-01"),
                max = as.Date("2025-09-30")),
      br(),
      dateInput("kpiEndDate", "End Date:",
                value = as.Date("2025-05-01"),
                min = as.Date("2025-01-01"),
                max = as.Date("2025-09-30"))
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
    req(input$excursionStartDate, input$excursionEndDate)

    # Check if single day selected
    single_day <- input$excursionStartDate == input$excursionEndDate

    if (single_day) {
      # Single day: count excursion events per SP
      # Load per-second frequency data for the selected day
      freq_data <- frequencyData()
      freq_data[, date := as.Date(dtm_sec)]
      day_freq <- freq_data[date == input$excursionStartDate]

      if (nrow(day_freq) == 0) {
        return(plotly_empty(type = "scatter", mode = "markers") %>%
                 layout(title = "No data available for selected date"))
      }

      # Calculate deviation
      day_freq[, deviation := abs(f - 50)]

      # Detect excursions for each threshold
      thresholds <- c(0.1, 0.15, 0.2)
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

      # Combine all excursions
      if (length(all_excursions) > 0) {
        combined_excursions <- rbindlist(all_excursions, fill = TRUE)

        # Count excursions per SP for each threshold
        count_01 <- combined_excursions[threshold == 0.1, .N, by = starting_sp]
        setnames(count_01, c("SP", "count_01"))
        count_015 <- combined_excursions[threshold == 0.15, .N, by = starting_sp]
        setnames(count_015, c("SP", "count_015"))
        count_02 <- combined_excursions[threshold == 0.2, .N, by = starting_sp]
        setnames(count_02, c("SP", "count_02"))

        # Create full SP range and merge
        all_sps <- data.table(SP = 1:48)
        all_sps <- merge(all_sps, count_01, by = "SP", all.x = TRUE)
        all_sps <- merge(all_sps, count_015, by = "SP", all.x = TRUE)
        all_sps <- merge(all_sps, count_02, by = "SP", all.x = TRUE)
        all_sps[is.na(count_01), count_01 := 0]
        all_sps[is.na(count_015), count_015 := 0]
        all_sps[is.na(count_02), count_02 := 0]
      } else {
        all_sps <- data.table(SP = 1:48, count_01 = 0, count_015 = 0, count_02 = 0)
      }

      # Create plot
      p <- plot_ly(all_sps) %>%
        add_trace(x = ~SP, y = ~count_01, name = "0.1 Hz",
                  type = "scatter", mode = "lines",
                  line = list(color = "#ff7f0e", width = 2)) %>%
        add_trace(x = ~SP, y = ~count_015, name = "0.15 Hz",
                  type = "scatter", mode = "lines",
                  line = list(color = "#2ca02c", width = 2)) %>%
        add_trace(x = ~SP, y = ~count_02, name = "0.2 Hz",
                  type = "scatter", mode = "lines",
                  line = list(color = "#1f77b4", width = 2)) %>%
        layout(
          title = "Number of Excursions per SP",
          xaxis = list(title = "Settlement Period (SP)", range = c(0.5, 48.5)),
          yaxis = list(title = "Count of Excursion Events"),
          legend = list(x = 0.5, y = -0.2, orientation = "h", xanchor = "center")
        )

      return(p)

    } else {
      # Multi-day: show time series
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
        mode = "lines",
        line = list(color = "#ff7f0e", width = 2),
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
        mode = "lines",
        line = list(color = "#2ca02c", width = 2),
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
        mode = "lines",
        line = list(color = "#1f77b4", width = 2),
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
    }
  })

  # Plot 2: Total Duration - Daily Time Series
  output$excursionDailyDurationPlot <- renderPlotly({
    req(input$excursionStartDate, input$excursionEndDate)

    # Check if single day selected
    single_day <- input$excursionStartDate == input$excursionEndDate

    if (single_day) {
      # Single day: show total duration per SP
      freq_data <- frequencyData()
      freq_data[, date := as.Date(dtm_sec)]
      day_freq <- freq_data[date == input$excursionStartDate]

      if (nrow(day_freq) == 0) {
        return(plotly_empty(type = "scatter", mode = "markers") %>%
                 layout(title = "No data available for selected date"))
      }

      # Calculate deviation
      day_freq[, deviation := abs(f - 50)]

      # Detect excursions for each threshold
      thresholds <- c(0.1, 0.15, 0.2)
      all_excursions <- list()

      for (threshold in thresholds) {
        # Mark points exceeding threshold
        day_freq[, exceeds := deviation >= threshold]

        # Create excursion groups
        day_freq[, excursion_id := cumsum(c(1, diff(exceeds) != 0))]
        day_freq[, is_excursion := exceeds == TRUE]

        # Get excursion events with start_time and duration
        excursions <- day_freq[is_excursion == TRUE, .(
          start_time = min(dtm_sec),
          duration_sec = .N
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

      # Combine all excursions
      if (length(all_excursions) > 0) {
        combined_excursions <- rbindlist(all_excursions, fill = TRUE)

        # Sum duration per SP for each threshold
        dur_01 <- combined_excursions[threshold == 0.1, .(duration = sum(duration_sec)), by = starting_sp]
        setnames(dur_01, c("SP", "dur_01"))
        dur_015 <- combined_excursions[threshold == 0.15, .(duration = sum(duration_sec)), by = starting_sp]
        setnames(dur_015, c("SP", "dur_015"))
        dur_02 <- combined_excursions[threshold == 0.2, .(duration = sum(duration_sec)), by = starting_sp]
        setnames(dur_02, c("SP", "dur_02"))

        # Create full SP range and merge
        all_sps <- data.table(SP = 1:48)
        all_sps <- merge(all_sps, dur_01, by = "SP", all.x = TRUE)
        all_sps <- merge(all_sps, dur_015, by = "SP", all.x = TRUE)
        all_sps <- merge(all_sps, dur_02, by = "SP", all.x = TRUE)
        all_sps[is.na(dur_01), dur_01 := 0]
        all_sps[is.na(dur_015), dur_015 := 0]
        all_sps[is.na(dur_02), dur_02 := 0]
      } else {
        all_sps <- data.table(SP = 1:48, dur_01 = 0, dur_015 = 0, dur_02 = 0)
      }

      # Create plot
      p <- plot_ly(all_sps) %>%
        add_trace(x = ~SP, y = ~dur_01, name = "0.1 Hz",
                  type = "scatter", mode = "lines",
                  line = list(color = "#ff7f0e", width = 2)) %>%
        add_trace(x = ~SP, y = ~dur_015, name = "0.15 Hz",
                  type = "scatter", mode = "lines",
                  line = list(color = "#2ca02c", width = 2)) %>%
        add_trace(x = ~SP, y = ~dur_02, name = "0.2 Hz",
                  type = "scatter", mode = "lines",
                  line = list(color = "#1f77b4", width = 2)) %>%
        layout(
          title = "Total Duration of Excursions per SP",
          xaxis = list(title = "Settlement Period (SP)", range = c(0.5, 48.5)),
          yaxis = list(title = "Total Duration (seconds)"),
          legend = list(x = 0.5, y = -0.2, orientation = "h", xanchor = "center")
        )

      return(p)

    } else {
      # Multi-day: show time series
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
        mode = "lines",
        line = list(color = "#ff7f0e", width = 2),
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
        mode = "lines",
        line = list(color = "#2ca02c", width = 2),
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
        mode = "lines",
        line = list(color = "#1f77b4", width = 2),
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
    }
  })

  # Percentage of Time Plot
  output$excursionPercentagePlot <- renderPlotly({
    req(input$excursionStartDate, input$excursionEndDate)

    # Check if single day selected
    single_day <- input$excursionStartDate == input$excursionEndDate

    if (single_day) {
      # Single day: show percentage per SP
      freq_data <- frequencyData()
      freq_data[, date := as.Date(dtm_sec)]
      day_freq <- freq_data[date == input$excursionStartDate]

      if (nrow(day_freq) == 0) {
        return(plotly_empty(type = "scatter", mode = "markers") %>%
                 layout(title = "No data available for selected date"))
      }

      # Calculate deviation
      day_freq[, deviation := abs(f - 50)]

      # Detect excursions for each threshold
      thresholds <- c(0.1, 0.15, 0.2)
      all_excursions <- list()

      for (threshold in thresholds) {
        # Mark points exceeding threshold
        day_freq[, exceeds := deviation >= threshold]

        # Create excursion groups
        day_freq[, excursion_id := cumsum(c(1, diff(exceeds) != 0))]
        day_freq[, is_excursion := exceeds == TRUE]

        # Get excursion events with start_time and duration
        excursions <- day_freq[is_excursion == TRUE, .(
          start_time = min(dtm_sec),
          duration_sec = .N
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

      # Combine all excursions
      if (length(all_excursions) > 0) {
        combined_excursions <- rbindlist(all_excursions, fill = TRUE)

        # Sum duration per SP for each threshold and convert to percentage
        # Each SP is 1800 seconds (30 minutes)
        pct_01 <- combined_excursions[threshold == 0.1, .(pct = (sum(duration_sec) / 1800) * 100), by = starting_sp]
        setnames(pct_01, c("SP", "pct_01"))
        pct_015 <- combined_excursions[threshold == 0.15, .(pct = (sum(duration_sec) / 1800) * 100), by = starting_sp]
        setnames(pct_015, c("SP", "pct_015"))
        pct_02 <- combined_excursions[threshold == 0.2, .(pct = (sum(duration_sec) / 1800) * 100), by = starting_sp]
        setnames(pct_02, c("SP", "pct_02"))

        # Create full SP range and merge
        all_sps <- data.table(SP = 1:48)
        all_sps <- merge(all_sps, pct_01, by = "SP", all.x = TRUE)
        all_sps <- merge(all_sps, pct_015, by = "SP", all.x = TRUE)
        all_sps <- merge(all_sps, pct_02, by = "SP", all.x = TRUE)
        all_sps[is.na(pct_01), pct_01 := 0]
        all_sps[is.na(pct_015), pct_015 := 0]
        all_sps[is.na(pct_02), pct_02 := 0]
      } else {
        all_sps <- data.table(SP = 1:48, pct_01 = 0, pct_015 = 0, pct_02 = 0)
      }

      # Create plot
      p <- plot_ly(all_sps) %>%
        add_trace(x = ~SP, y = ~pct_01, name = "0.1 Hz",
                  type = "scatter", mode = "lines",
                  line = list(color = "#ff7f0e", width = 2)) %>%
        add_trace(x = ~SP, y = ~pct_015, name = "0.15 Hz",
                  type = "scatter", mode = "lines",
                  line = list(color = "#2ca02c", width = 2)) %>%
        add_trace(x = ~SP, y = ~pct_02, name = "0.2 Hz",
                  type = "scatter", mode = "lines",
                  line = list(color = "#1f77b4", width = 2)) %>%
        layout(
          title = "Percentage of Time in Excursion per SP",
          xaxis = list(title = "Settlement Period (SP)", range = c(0.5, 48.5)),
          yaxis = list(title = "Percentage of SP Time (%)"),
          legend = list(x = 0.5, y = -0.2, orientation = "h", xanchor = "center")
        )

      return(p)

    } else {
      # Multi-day: show time series
      data <- filteredExcursionData()
      df <- data$daily

      if (nrow(df) == 0) {
        return(plotly_empty(type = "scatter", mode = "markers") %>%
                 layout(title = "No data available for selected date range"))
      }

      # Calculate percentage: (duration_sec / 86400 sec per day) * 100
      df[, percentage := (total_duration_sec / 86400) * 100]

      # Split data by threshold
      df_01 <- df[threshold == 0.1]
      df_015 <- df[threshold == 0.15]
      df_02 <- df[threshold == 0.2]

      # Create plotly
      p <- plot_ly()

      # Add 0.1 Hz line
      p <- p %>% add_trace(
        data = df_01,
        x = ~date,
        y = ~percentage,
        name = "0.1 Hz",
        type = "scatter",
        mode = "lines",
        line = list(color = "#ff7f0e", width = 2),
        hovertemplate = paste0(
          "Date: %{x|%b %d, %Y}<br>",
          "0.1 Hz: %{y:.2f}%<br>",
          "<extra></extra>"
        )
      )

      # Add 0.15 Hz line
      p <- p %>% add_trace(
        data = df_015,
        x = ~date,
        y = ~percentage,
        name = "0.15 Hz",
        type = "scatter",
        mode = "lines",
        line = list(color = "#2ca02c", width = 2),
        hovertemplate = paste0(
          "Date: %{x|%b %d, %Y}<br>",
          "0.15 Hz: %{y:.2f}%<br>",
          "<extra></extra>"
        )
      )

      # Add 0.2 Hz line
      p <- p %>% add_trace(
        data = df_02,
        x = ~date,
        y = ~percentage,
        name = "0.2 Hz",
        type = "scatter",
        mode = "lines",
        line = list(color = "#1f77b4", width = 2),
        hovertemplate = paste0(
          "Date: %{x|%b %d, %Y}<br>",
          "0.2 Hz: %{y:.2f}%<br>",
          "<extra></extra>"
        )
      )

      # Configure layout
      p <- p %>% layout(
        title = "Percentage of Time in Excursion",
        xaxis = list(title = "Date"),
        yaxis = list(title = "Percentage of Time (%)"),
        legend = list(x = 0.5, y = -0.2, orientation = "h", xanchor = "center"),
        hovermode = "x unified"
      )

      return(p)
    }
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
          hovermode = "x unified"
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
          tags$td(style = "padding: 5px; font-weight: bold; color: #d62728;", "SysDyn_LP:"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.2f MW", mean(df$SysDyn_LP, na.rm = TRUE)))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold; color: #1f77b4;", "SysDyn_H:"),
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
    color_map <- list(
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

    p <- plot_ly()

    # Add traces for each selected metric
    for (metric in input$responseMetrics) {
      if (metric %in% names(df)) {
        p <- p %>% add_trace(
          data = df,
          x = ~datetime,
          y = as.formula(paste0("~", metric)),
          name = metric,
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

  # Dynamic event selector UI
  output$imbalanceEventSelectUI <- renderUI({
    req(input$imbalanceEventFilter)
    df <- imbalanceSummaryData()

    if (nrow(df) == 0) {
      return(selectInput("selectedEvent", "Select Event:", choices = c("No events available" = "")))
    }

    # Filter events based on selection
    if (input$imbalanceEventFilter == "top10") {
      setorder(df, -severity)
      df <- head(df, 10)
    } else if (input$imbalanceEventFilter == "latest10") {
      setorder(df, -date, -starting_sp)
      df <- head(df, 10)
    }

    # Create event labels and use event_id as the unique identifier
    df[, event_label := paste0(format(date, "%Y-%m-%d %H:%M"), " SP", starting_sp,
                                " (Sev: ", sprintf("%.1f", severity), ")")]

    # Use event_id as the value (it's unique and already in the data)
    event_choices <- setNames(df$event_id, df$event_label)

    selectInput("selectedEvent", "Select Event:",
                choices = event_choices,
                selected = event_choices[1])
  })

  # Event Details
  output$imbalanceEventDetailsUI <- renderUI({
    req(input$selectedEvent)
    df <- imbalanceSummaryData()

    if (nrow(df) == 0 || input$selectedEvent == "") {
      return(tags$p("No event selected", style = "color: #999; font-style: italic;"))
    }

    # Use event_id to find the event
    event <- df[event_id == input$selectedEvent]

    if (nrow(event) == 0) {
      return(tags$p("Event not found", style = "color: #999; font-style: italic;"))
    }

    # Get detail data for ROCOF
    df_detail <- imbalanceDetailData()
    event_detail <- df_detail[event_id == input$selectedEvent]
    rocof_max <- if(nrow(event_detail) > 0) max(abs(event_detail$rocof), na.rm = TRUE) else NA

    tags$div(
      style = "padding: 10px;",
      tags$table(
        style = "width: 100%; border-collapse: collapse;",
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Date & SP:"),
          tags$td(style = "padding: 5px;", paste(format(event$date, "%Y-%m-%d %H:%M"), "/ SP", event$starting_sp))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Boundary Time:"),
          tags$td(style = "padding: 5px;", format(event$date, "%H:%M:%S"))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Frequency Range:"),
          tags$td(style = "padding: 5px;", sprintf("%.3f - %.3f Hz", event$min_freq_hz, event$max_freq_hz))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Frequency Change (Δf):"),
          tags$td(style = "padding: 5px;", sprintf("%.4f Hz", event$abs_freq_change))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "ROCOF (max):"),
          tags$td(style = "padding: 5px;", sprintf("%.4f Hz/s", rocof_max))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Event Category:"),
          tags$td(style = "padding: 5px; color: #d62728;", event$category)
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Severity Score:"),
          tags$td(style = "padding: 5px;", sprintf("%.2f", event$severity))
        )
      )
    )
  })

  # Imbalance Summary
  output$imbalanceSummaryUI <- renderUI({
    req(input$selectedEvent)
    df <- imbalanceSummaryData()

    if (nrow(df) == 0 || input$selectedEvent == "") {
      return(tags$p("No event selected", style = "color: #999; font-style: italic;"))
    }

    # Use event_id to find the event
    event <- df[event_id == input$selectedEvent]

    if (nrow(event) == 0) {
      return(tags$p("Event not found", style = "color: #999; font-style: italic;"))
    }

    # Get detail data to calculate component averages
    df_detail <- imbalanceDetailData()
    event_detail <- df_detail[event_id == input$selectedEvent]

    # Calculate stabilized values (last 5 seconds)
    if (nrow(event_detail) > 0) {
      stable_period <- event_detail[time_rel_s >= 10]
      if (nrow(stable_period) > 0) {
        pre_fault_imb <- mean(stable_period$imbalance_mw, na.rm = TRUE)
        avg_lf <- mean(stable_period$lf_response_mw, na.rm = TRUE)
        avg_hf <- mean(stable_period$hf_response_mw, na.rm = TRUE)
        avg_damping <- mean(stable_period$demand_damping_mw, na.rm = TRUE)
        avg_rocof <- mean(stable_period$rocof_component_mw, na.rm = TRUE)
      } else {
        pre_fault_imb <- NA
        avg_lf <- NA
        avg_hf <- NA
        avg_damping <- NA
        avg_rocof <- NA
      }
    } else {
      pre_fault_imb <- NA
      avg_lf <- NA
      avg_hf <- NA
      avg_damping <- NA
      avg_rocof <- NA
    }

    tags$div(
      style = "padding: 10px;",
      tags$table(
        style = "width: 100%; border-collapse: collapse;",
        tags$tr(
          tags$td(colspan = "2", style = "padding: 5px; font-weight: bold; border-bottom: 2px solid #ccc;", "Imbalance Statistics")
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Pre-fault Imbalance:"),
          tags$td(style = "padding: 5px; text-align: right;",
                  if(!is.na(pre_fault_imb)) sprintf("%.2f MW", pre_fault_imb) else "N/A")
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold; color: #d62728;", "Peak Imbalance:"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.2f MW", event$max_abs_imbalance_mw))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Mean Imbalance:"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.2f MW", event$mean_imbalance_mw))
        ),
        tags$tr(
          tags$td(colspan = "2", style = "padding: 8px 5px 5px 5px; font-weight: bold; border-bottom: 2px solid #ccc;", "Component Breakdown (Stabilized)")
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "LF Response:"),
          tags$td(style = "padding: 5px; text-align: right;",
                  if(!is.na(avg_lf)) sprintf("%.2f MW", avg_lf) else "N/A")
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "HF Response:"),
          tags$td(style = "padding: 5px; text-align: right;",
                  if(!is.na(avg_hf)) sprintf("%.2f MW", avg_hf) else "N/A")
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Demand Damping:"),
          tags$td(style = "padding: 5px; text-align: right;",
                  if(!is.na(avg_damping)) sprintf("%.2f MW", avg_damping) else "N/A")
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "RoCoF Component:"),
          tags$td(style = "padding: 5px; text-align: right;",
                  if(!is.na(avg_rocof)) sprintf("%.2f MW", avg_rocof) else "N/A")
        ),
        tags$tr(
          tags$td(colspan = "2", style = "padding: 8px 5px 5px 5px; font-size: 11px; color: #666;",
                  sprintf("System values used - Inertia: %.1f GVA·s, Demand: %.0f MW",
                          event$system_inertia_gvas, event$system_demand_mw))
        )
      )
    )
  })

  # Frequency Event Plot
  output$imbalanceFrequencyPlot <- renderPlotly({
    req(input$selectedEvent, input$updateImbalancePlot)

    df_detail <- imbalanceDetailData()

    if (nrow(df_detail) == 0 || input$selectedEvent == "") {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "No data available. Select an event and click 'Load Event Data'.", size = 5) +
        theme_void()
      return(ggplotly(p))
    }

    # Use event_id to filter for this event
    event_data <- df_detail[event_id == input$selectedEvent]

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
    req(input$selectedEvent, input$updateImbalancePlot)

    df_detail <- imbalanceDetailData()

    if (nrow(df_detail) == 0 || input$selectedEvent == "") {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "No data available. Select an event and click 'Load Event Data'.", size = 5) +
        theme_void()
      return(ggplotly(p))
    }

    # Use event_id to filter for this event
    event_data <- df_detail[event_id == input$selectedEvent]

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
  output$imbalanceSummaryTable <- DT::renderDataTable({
    df <- imbalanceSummaryData()
    if (nrow(df) == 0) return(data.table())

    # Select relevant columns that exist in the data
    display_cols <- c("date", "starting_sp", "category", "severity", "abs_freq_change",
                      "imbalance_peak_mw", "imbalance_mean_mw", "median_imbalance_mw",
                      "min_imbalance_mw", "max_imbalance_mw")
    df_display <- df[, .SD, .SDcols = intersect(display_cols, names(df))]

    datatable(df_display,
              options = list(pageLength = 15, scrollX = TRUE),
              rownames = FALSE) %>%
      formatRound(columns = intersect(c("severity", "abs_freq_change", "imbalance_peak_mw",
                                        "imbalance_mean_mw", "median_imbalance_mw",
                                        "min_imbalance_mw", "max_imbalance_mw"),
                                      names(df_display)), digits = 2)
  })

  # --- Demand Analysis Tab Logic ---

  # Reactive expression to load demand data
  demandData <- reactive({
    req(file.exists("data/output/reports/demand_at_sp_boundaries.csv"))
    dt <- fread("data/output/reports/demand_at_sp_boundaries.csv")
    dt[, Date := as.Date(Date)]
    return(dt)
  })

  demandHourlyData <- reactive({
    req(file.exists("data/output/reports/demand_hourly_summary.csv"))
    fread("data/output/reports/demand_hourly_summary.csv")
  })

  demandDailyPeaksData <- reactive({
    req(file.exists("data/output/reports/demand_daily_peaks.csv"))
    dt <- fread("data/output/reports/demand_daily_peaks.csv")
    dt[, Date := as.Date(Date)]
    return(dt)
  })

  # Populate month filter for demand tab
  observe({
    req(demandData())
    df <- demandData()
    df[, month_label := format(Date, "%b %Y")]
    month_choices <- sort(unique(df$month_label), decreasing = TRUE)
    updateSelectInput(session, "demandMonthFilter", choices = month_choices,
                      selected = if(length(month_choices) > 0) month_choices[1] else NULL)
  })

  # Filtered demand data
  filteredDemandData <- eventReactive(input$updateDemandPlots, {
    req(input$demandFilterMode)
    df <- demandData()

    if (input$demandFilterMode == "date_range") {
      req(input$demandStartDate, input$demandEndDate)
      df_filtered <- df[Date >= input$demandStartDate & Date <= input$demandEndDate]
    } else if (input$demandFilterMode == "month") {
      req(input$demandMonthFilter)
      df[, month_label := format(Date, "%b %Y")]
      df_filtered <- df[month_label == input$demandMonthFilter]
      df_filtered[, month_label := NULL]
    }

    return(df_filtered)
  }, ignoreNULL = FALSE)

  # Demand Statistics
  output$demandStatsUI <- renderUI({
    df <- filteredDemandData()
    if (nrow(df) == 0) {
      return(tags$p("No data available", style = "color: #999; font-style: italic;"))
    }

    tags$div(
      style = "padding: 10px;",
      tags$table(
        style = "width: 100%; border-collapse: collapse;",
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Avg ND:"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.0f MW", mean(df$ND, na.rm = TRUE)))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Avg TSD:"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.0f MW", mean(df$TSD, na.rm = TRUE)))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "SPs:"),
          tags$td(style = "padding: 5px; text-align: right;", format(nrow(df), big.mark = ","))
        )
      )
    )
  })

  # Peak Demand
  output$demandPeakUI <- renderUI({
    df <- filteredDemandData()
    if (nrow(df) == 0) {
      return(tags$p("No data available", style = "color: #999; font-style: italic;"))
    }

    peak_nd <- max(df$ND, na.rm = TRUE)
    peak_tsd <- max(df$TSD, na.rm = TRUE)

    tags$div(
      style = "padding: 10px;",
      tags$table(
        style = "width: 100%; border-collapse: collapse;",
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold; color: #d62728;", "Peak ND:"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.0f MW", peak_nd))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold; color: #1f77b4;", "Peak TSD:"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.0f MW", peak_tsd))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Range:"),
          tags$td(style = "padding: 5px; text-align: right;",
                  paste(format(min(df$Date), "%d %b"), "-", format(max(df$Date), "%d %b")))
        )
      )
    )
  })

  # Event Correlation
  output$demandEventCorrelationUI <- renderUI({
    df <- filteredDemandData()
    if (nrow(df) == 0) {
      return(tags$p("No data available", style = "color: #999; font-style: italic;"))
    }

    total_sps <- nrow(df)
    sps_with_events <- df[HasEvent == TRUE, .N]
    event_pct <- (sps_with_events / total_sps) * 100

    tags$div(
      style = "padding: 10px;",
      tags$table(
        style = "width: 100%; border-collapse: collapse;",
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Total SPs:"),
          tags$td(style = "padding: 5px; text-align: right;", format(total_sps, big.mark = ","))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold; color: #d62728;", "With Events:"),
          tags$td(style = "padding: 5px; text-align: right;", format(sps_with_events, big.mark = ","))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Event Rate:"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.1f%%", event_pct))
        )
      )
    )
  })

  # Demand Time Series
  output$demandTimeSeriesPlot <- renderPlotly({
    df <- filteredDemandData()
    if (nrow(df) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "No data available for selected range", size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Create datetime for plotting - use minutes to avoid non-integer hours
    df[, datetime := Date + minutes((SP - 1) * 30)]

    # Prepare data for plotting (ND and TSD)
    df_long <- melt(df[, .(datetime, ND, TSD)],
                    id.vars = "datetime",
                    variable.name = "metric",
                    value.name = "demand")

    p <- ggplot(df_long, aes(x = datetime, y = demand, color = metric, group = metric)) +
      geom_line(linewidth = 0.8) +
      scale_color_manual(values = c("ND" = "#d62728", "TSD" = "#1f77b4")) +
      labs(
        x = "Date",
        y = "Demand (MW)",
        color = "Metric"
      ) +
      theme_minimal(base_size = 11) +
      theme(legend.position = "bottom")

    ggplotly(p, tooltip = c("x", "y", "colour"))
  })

  # Demand Changes Plot
  output$demandChangesPlot <- renderPlotly({
    df <- filteredDemandData()
    if (nrow(df) == 0 || !"Delta_ND" %in% names(df)) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "No demand change data available", size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Create datetime for plotting - use minutes to avoid non-integer hours
    df[, datetime := Date + minutes((SP - 1) * 30)]

    # Filter out NAs
    df_clean <- df[!is.na(Delta_ND)]

    if (nrow(df_clean) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "No demand change data available", size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    p <- ggplot(df_clean, aes(x = datetime, y = Delta_ND)) +
      geom_col(fill = "#ff7f0e", alpha = 0.7) +
      geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
      labs(
        x = "Date",
        y = "Demand Change (ΔMW)"
      ) +
      theme_minimal(base_size = 11)

    ggplotly(p, tooltip = c("x", "y"))
  })

  # Hourly Demand Pattern
  output$demandHourlyPlot <- renderPlotly({
    df_hourly <- demandHourlyData()

    if (nrow(df_hourly) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "No hourly data available", size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Check if ND_Mean exists
    if (!"ND_Mean" %in% names(df_hourly)) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "Hourly summary not computed", size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    p <- ggplot(df_hourly, aes(x = Hour)) +
      geom_line(aes(y = ND_Mean, color = "ND"), linewidth = 1.2) +
      geom_ribbon(aes(ymin = ND_Min, ymax = ND_Max), alpha = 0.2, fill = "#d62728") +
      scale_color_manual(values = c("ND" = "#d62728")) +
      scale_x_continuous(breaks = seq(0, 23, 2)) +
      labs(
        x = "Hour of Day",
        y = "Demand (MW)",
        color = "Metric"
      ) +
      theme_minimal(base_size = 11) +
      theme(legend.position = "bottom")

    ggplotly(p, tooltip = c("x", "y", "colour"))
  })

  # Demand Data Table
  output$demandDataTable <- DT::renderDataTable({
    df <- filteredDemandData()
    if (nrow(df) == 0) return(data.table())

    display_cols <- c("Date", "SP", "ND", "TSD", "Delta_ND", "Delta_TSD")
    df_display <- df[, .SD, .SDcols = intersect(display_cols, names(df))]

    datatable(df_display,
              options = list(pageLength = 15, scrollX = TRUE),
              rownames = FALSE,
              filter = 'top') %>%
      formatRound(columns = intersect(c("ND", "TSD", "Delta_ND", "Delta_TSD"), names(df_display)), digits = 0)
  })

  # --- Unforeseen Demand Tab Logic ---

  # Reactive expression to load unforeseen demand events
  unforeseenData <- reactive({
    req(file.exists("data/output/reports/unforeseen_demand_events.csv"))
    dt <- fread("data/output/reports/unforeseen_demand_events.csv")
    dt[, Date := as.Date(Date)]
    return(dt)
  })

  # Filtered unforeseen demand data
  filteredUnforeseenData <- reactive({
    df <- unforeseenData()
    req(input$unforeseenMetric, input$unforeseenFilter,
        input$unforeseenStartDate, input$unforeseenEndDate)

    # Date filter
    df <- df[Date >= input$unforeseenStartDate & Date <= input$unforeseenEndDate]

    # Event type filter
    flag_col <- paste0("is_unforeseen_", input$unforeseenMetric)
    if (input$unforeseenFilter == "unforeseen") {
      df <- df[get(flag_col) == TRUE]
    } else if (input$unforeseenFilter == "normal") {
      df <- df[get(flag_col) == FALSE]
    }

    return(df)
  })

  # Summary Statistics
  output$unforeseenStatsUI <- renderUI({
    df <- filteredUnforeseenData()
    metric <- input$unforeseenMetric
    flag_col <- paste0("is_unforeseen_", metric)

    all_data <- unforeseenData()
    all_data <- all_data[Date >= input$unforeseenStartDate & Date <= input$unforeseenEndDate]

    n_total <- nrow(all_data)
    n_unforeseen <- sum(all_data[[flag_col]], na.rm = TRUE)
    pct_unforeseen <- ifelse(n_total > 0, n_unforeseen / n_total * 100, 0)

    tags$div(
      style = "padding: 10px;",
      tags$table(
        style = "width: 100%; border-collapse: collapse;",
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Total SPs:"),
          tags$td(style = "padding: 5px; text-align: right;", format(n_total, big.mark = ","))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Unforeseen Events:"),
          tags$td(style = "padding: 5px; text-align: right;", format(n_unforeseen, big.mark = ","))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Event Rate:"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.2f%%", pct_unforeseen))
        )
      )
    )
  })

  output$unforeseenMagnitudeUI <- renderUI({
    df <- filteredUnforeseenData()
    metric <- input$unforeseenMetric
    unforeseen_col <- paste0(metric, "_unforeseen")
    delta_col <- paste0("Delta_", metric)

    if (nrow(df) == 0 || !unforeseen_col %in% names(df)) {
      return(tags$p("No data available", style = "color: #999; font-style: italic;"))
    }

    max_unforeseen <- max(abs(df[[unforeseen_col]]), na.rm = TRUE)
    mean_unforeseen <- mean(abs(df[[unforeseen_col]]), na.rm = TRUE)
    p95_unforeseen <- quantile(abs(df[[unforeseen_col]]), 0.95, na.rm = TRUE)

    tags$div(
      style = "padding: 10px;",
      tags$table(
        style = "width: 100%; border-collapse: collapse;",
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Max Unforeseen:"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.0f MW", max_unforeseen))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Mean:"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.0f MW", mean_unforeseen))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "95th percentile:"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.0f MW", p95_unforeseen))
        )
      )
    )
  })

  output$unforeseenDampingUI <- renderUI({
    df <- filteredUnforeseenData()
    metric <- input$unforeseenMetric
    damping_col <- paste0(metric, "_damping")

    if (nrow(df) == 0 || !damping_col %in% names(df)) {
      return(tags$p("No data available", style = "color: #999; font-style: italic;"))
    }

    avg_damping <- mean(abs(df[[damping_col]]), na.rm = TRUE)
    max_damping <- max(abs(df[[damping_col]]), na.rm = TRUE)
    pct_with_damping <- sum(abs(df[[damping_col]]) > 0, na.rm = TRUE) / nrow(df) * 100

    tags$div(
      style = "padding: 10px;",
      tags$table(
        style = "width: 100%; border-collapse: collapse;",
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Avg Damping:"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.0f MW", avg_damping))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "Max Damping:"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.0f MW", max_damping))
        ),
        tags$tr(
          tags$td(style = "padding: 5px; font-weight: bold;", "% with damping:"),
          tags$td(style = "padding: 5px; text-align: right;", sprintf("%.1f%%", pct_with_damping))
        )
      )
    )
  })

  output$unforeseenCausalityUI <- renderUI({
    df <- filteredUnforeseenData()

    if (nrow(df) == 0 || !"causality" %in% names(df)) {
      return(tags$p("No data available", style = "color: #999; font-style: italic;"))
    }

    causality_counts <- df[, .N, by = causality]
    setorder(causality_counts, -N)

    tags$div(
      style = "padding: 10px;",
      tags$table(
        style = "width: 100%; border-collapse: collapse;",
        lapply(1:min(nrow(causality_counts), 4), function(i) {
          tags$tr(
            tags$td(style = "padding: 5px; font-weight: bold;", paste0(causality_counts$causality[i], ":")),
            tags$td(style = "padding: 5px; text-align: right;", causality_counts$N[i])
          )
        })
      )
    )
  })

  # Time Series Plot
  output$unforeseenTimeSeriesPlot <- renderPlotly({
    df <- filteredUnforeseenData()
    metric <- input$unforeseenMetric

    delta_col <- paste0("Delta_", metric)
    damping_col <- paste0(metric, "_damping")
    unforeseen_col <- paste0(metric, "_unforeseen")
    flag_col <- paste0("is_unforeseen_", metric)

    if (nrow(df) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "No data available for selected filters", size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Check if viewing single day or multiple days
    unique_dates <- unique(df$Date)

    if (length(unique_dates) > 1) {
      # Multiple days selected - show message
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5,
                 label = paste("Please select a single day to view this plot.\nCurrently showing", length(unique_dates), "days."),
                 size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Single day view - plot by SP
    p <- plot_ly(df)

    # Add total change
    p <- p %>% add_trace(
      x = ~SP,
      y = as.formula(paste0("~", delta_col)),
      name = "Total Change",
      type = "scatter",
      mode = "lines+markers",
      line = list(color = "#1f77b4", width = 1.5),
      marker = list(color = "#1f77b4", size = 4)
    )

    # Add unforeseen component
    p <- p %>% add_trace(
      x = ~SP,
      y = as.formula(paste0("~", unforeseen_col)),
      name = "Unforeseen Component",
      type = "scatter",
      mode = "markers",
      marker = list(color = "#d62728", size = 4)
    )

    # Highlight flagged events
    df_flagged <- df[get(flag_col) == TRUE]
    if (nrow(df_flagged) > 0) {
      p <- p %>% add_trace(
        data = df_flagged,
        x = ~SP,
        y = as.formula(paste0("~", unforeseen_col)),
        name = "Unforeseen Events",
        type = "scatter",
        mode = "markers",
        marker = list(color = "#ff7f0e", size = 8, symbol = "diamond")
      )
    }

    p <- p %>% layout(
      xaxis = list(title = "Settlement Period (SP)", range = c(0.5, 48.5)),
      yaxis = list(title = paste(metric, "Change (MW)")),
      legend = list(x = 0.5, y = -0.15, orientation = "h", xanchor = "center"),
      hovermode = "x unified"
    )

    return(p)
  })

  # Frequency Profile Plot
  output$unforeseenFrequencyProfilePlot <- renderPlotly({
    df <- filteredUnforeseenData()

    if (nrow(df) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "No data available", size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Check if single day
    unique_dates <- unique(df$Date)
    if (length(unique_dates) > 1) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5,
                 label = paste("Please select a single day to view this plot.\nCurrently showing", length(unique_dates), "days."),
                 size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Check if frequency data available
    if (!"min_f" %in% names(df) || !"max_f" %in% names(df)) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5,
                 label = "No frequency data available for this day",
                 size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Remove rows with NA frequency data
    df_freq <- df[!is.na(min_f) & !is.na(max_f)]

    if (nrow(df_freq) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5,
                 label = "No frequency events occurred on this day",
                 size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Plot frequency range
    p <- plot_ly(df_freq)

    # Add min frequency
    p <- p %>% add_trace(
      x = ~SP,
      y = ~min_f,
      name = "Min Frequency",
      type = "scatter",
      mode = "lines+markers",
      line = list(color = "#1f77b4", width = 1.5),
      marker = list(color = "#1f77b4", size = 4)
    )

    # Add max frequency
    p <- p %>% add_trace(
      x = ~SP,
      y = ~max_f,
      name = "Max Frequency",
      type = "scatter",
      mode = "lines+markers",
      line = list(color = "#d62728", width = 1.5),
      marker = list(color = "#d62728", size = 4)
    )

    # Add 50 Hz reference line
    p <- p %>% add_trace(
      x = c(0.5, 48.5),
      y = c(50, 50),
      name = "50 Hz Nominal",
      type = "scatter",
      mode = "lines",
      line = list(color = "gray", width = 1, dash = "dash")
    )

    p <- p %>% layout(
      xaxis = list(title = "Settlement Period (SP)", range = c(0.5, 48.5)),
      yaxis = list(title = "Frequency (Hz)"),
      legend = list(x = 0.5, y = -0.15, orientation = "h", xanchor = "center"),
      hovermode = "x unified"
    )

    return(p)
  })

  # SP Frequency Event Categories Plot
  output$unforeseenVsFreqCategoryPlot <- renderPlotly({
    df <- filteredUnforeseenData()

    if (nrow(df) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "No data available", size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Check if single day
    unique_dates <- unique(df$Date)
    if (length(unique_dates) > 1) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5,
                 label = paste("Please select a single day to view this plot.\nCurrently showing", length(unique_dates), "days."),
                 size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Check if frequency data available
    if (!"min_f" %in% names(df) || !"category" %in% names(df)) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5,
                 label = "No frequency data available for this day",
                 size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Remove rows with NA frequency data
    df_freq <- df[!is.na(min_f) & !is.na(max_f)]

    if (nrow(df_freq) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5,
                 label = "No frequency events occurred on this day",
                 size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Calculate average frequency
    df_freq[, avg_f := (min_f + max_f) / 2]

    # Map category to color
    df_freq[, color := fcase(
      category == "Red", "#d62728",
      category == "Green", "#2ca02c",
      category == "Tuning", "#9467bd",
      default = "#cccccc"
    )]

    p <- plot_ly(df_freq) %>%
      add_trace(x = ~SP, y = ~avg_f, type = "scatter", mode = "lines",
                line = list(color = "black", width = 1), showlegend = FALSE) %>%
      add_trace(x = ~SP, y = ~avg_f, type = "scatter", mode = "markers",
                marker = list(size = 8, color = ~color),
                text = ~paste("SP:", SP, "<br>Avg Freq:", round(avg_f, 3), "Hz<br>Category:", category),
                hoverinfo = "text", showlegend = FALSE) %>%
      layout(
        xaxis = list(title = "Settlement Period (SP)", range = c(0.5, 48.5)),
        yaxis = list(title = "Frequency (Hz)")
      )

    return(p)
  })

  # Data Table
  output$unforeseenDataTable <- DT::renderDataTable({
    df <- filteredUnforeseenData()
    metric <- input$unforeseenMetric

    if (nrow(df) == 0) return(data.table())

    display_cols <- c("Date", "SP", "Hour",
                      paste0("Delta_", metric),
                      paste0(metric, "_damping"),
                      paste0(metric, "_unforeseen"),
                      paste0("is_unforeseen_", metric),
                      paste0(metric, "_event_severity"),
                      "abs_freq_change", "trend", "causality")

    df_display <- df[, .SD, .SDcols = intersect(display_cols, names(df))]

    datatable(df_display,
              options = list(pageLength = 15, scrollX = TRUE),
              rownames = FALSE,
              filter = 'top') %>%
      formatRound(columns = intersect(c(paste0("Delta_", metric),
                                        paste0(metric, "_damping"),
                                        paste0(metric, "_unforeseen"),
                                        paste0(metric, "_event_severity"),
                                        "abs_freq_change"),
                                      names(df_display)), digits = 2)
  })

  # --- Unforeseen Patterns Tab Logic ---

  # Filtered patterns data
  filteredPatternsData <- eventReactive(input$updatePatternsPlots, {
    df <- unforeseenData()
    metric <- input$patternsMetric

    # Filter by date range
    df <- df[Date >= input$patternsStartDate & Date <= input$patternsEndDate]

    # Only keep flagged events
    flag_col <- paste0("is_unforeseen_", metric)
    if (flag_col %in% names(df)) {
      df <- df[get(flag_col) == TRUE]
    }

    return(df)
  }, ignoreNULL = FALSE)

  # Panel 1: Hourly Bar Chart
  output$patternsHourlyBarPlot <- renderPlotly({
    df <- filteredPatternsData()
    metric <- input$patternsMetric

    if (nrow(df) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5,
                 label = "No unforeseen events in selected date range",
                 size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Count events per hour
    hourly_counts <- df[, .(count = .N), by = Hour]

    # Ensure all hours 0-23 are represented
    all_hours <- data.table(Hour = 0:23)
    hourly_counts <- merge(all_hours, hourly_counts, by = "Hour", all.x = TRUE)
    hourly_counts[is.na(count), count := 0]

    setorder(hourly_counts, Hour)

    # Create bar chart
    p <- plot_ly(hourly_counts, x = ~Hour, y = ~count,
                 type = "bar",
                 marker = list(color = "#d62728"),
                 text = ~paste("Hour:", Hour, "<br>Events:", count),
                 textposition = "none",
                 hoverinfo = "text") %>%
      layout(
        xaxis = list(title = "Hour of Day", dtick = 1),
        yaxis = list(title = "Total Unforeseen Events"),
        hovermode = "x"
      )

    return(p)
  })

  # Panel 2: Heatmap
  output$patternsHeatmapPlot <- renderPlotly({
    df <- filteredPatternsData()
    metric <- input$patternsMetric

    if (nrow(df) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5,
                 label = "No unforeseen events in selected date range",
                 size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Count events per date and hour
    heatmap_data <- df[, .(count = .N), by = .(Date, Hour)]

    # Create complete grid
    all_dates <- seq(input$patternsStartDate, input$patternsEndDate, by = "day")
    all_hours <- 0:23
    complete_grid <- data.table(expand.grid(Date = all_dates, Hour = all_hours))

    # Merge with actual data
    heatmap_data <- merge(complete_grid, heatmap_data, by = c("Date", "Hour"), all.x = TRUE)
    heatmap_data[is.na(count), count := 0]

    # Convert to matrix
    heatmap_matrix <- dcast(heatmap_data, Date ~ Hour, value.var = "count")
    dates_vector <- heatmap_matrix$Date
    heatmap_matrix[, Date := NULL]
    heatmap_matrix <- as.matrix(heatmap_matrix)

    # Create heatmap
    p <- plot_ly(
      x = all_hours,
      y = dates_vector,
      z = heatmap_matrix,
      type = "heatmap",
      colorscale = "Reds",
      colorbar = list(title = "Events"),
      hovertemplate = paste(
        "Date: %{y|%Y-%m-%d}<br>",
        "Hour: %{x}<br>",
        "Events: %{z}<br>",
        "<extra></extra>"
      )
    ) %>%
      layout(
        xaxis = list(title = "Hour of Day", dtick = 1),
        yaxis = list(title = "Date", autorange = "reversed")
      )

    return(p)
  })

  # Panel 3: Time Series with Hour Filter
  output$patternsTimeSeriesPlot <- renderPlotly({
    df <- filteredPatternsData()
    metric <- input$patternsMetric
    hour_filter <- input$patternsHourFilter

    if (nrow(df) == 0) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5,
                 label = "No unforeseen events in selected date range",
                 size = 6) +
        theme_void()
      return(ggplotly(p))
    }

    # Filter by hour if not "all"
    if (hour_filter != "all") {
      df <- df[Hour == as.integer(hour_filter)]
    }

    # Count events per date
    daily_counts <- df[, .(count = .N), by = Date]

    # Ensure all dates in range are represented
    all_dates <- seq(input$patternsStartDate, input$patternsEndDate, by = "day")
    complete_dates <- data.table(Date = all_dates)
    daily_counts <- merge(complete_dates, daily_counts, by = "Date", all.x = TRUE)
    daily_counts[is.na(count), count := 0]

    setorder(daily_counts, Date)

    # Create time series plot
    p <- plot_ly(daily_counts, x = ~Date, y = ~count,
                 type = "scatter", mode = "lines+markers",
                 line = list(color = "#1f77b4", width = 2),
                 marker = list(size = 4, color = "#1f77b4"),
                 text = ~paste("Date:", Date, "<br>Events:", count),
                 hoverinfo = "text") %>%
      layout(
        xaxis = list(title = "Date"),
        yaxis = list(title = "Unforeseen Events Count"),
        hovermode = "x"
      )

    return(p)
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