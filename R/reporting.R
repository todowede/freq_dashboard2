# R/reporting.R
# Purpose: Functions to generate static plots and interactive reports.

# --- Dependencies ---
suppressPackageStartupMessages({
  library(data.table)
  library(lubridate)
  library(ggplot2)
  library(plotly)      # For interactive plots
  library(htmlwidgets) # For saving interactive plots
  library(dplyr)       # For data manipulation
  library(scales)      # For percentage formatting
})


#' Generates a report and plots for the SP boundary event detection analysis.
#'
#' This function reads the `sp_boundary_events.csv` file, calculates the
#' monthly "Red Ratio", saves this summary, and generates both a static PNG
#' and an interactive HTML plot.
#'
#' @param config The application configuration list.
#' @return Invisibly returns TRUE on success.
#'
generate_event_detection_report <- function(config) {
  cat("INFO: Generating report for 'event_detection' analysis...\n")
  
  # Define paths
  report_path <- file.path(config$paths$output_reports, "sp_boundary_events.csv")
  plot_dir <- config$paths$output_plots
  
  # Load data, checking for existence
  if (!file.exists(report_path)) {
    cat("WARN: Input file not found:", report_path, ". Skipping report.\n")
    return(invisible(FALSE))
  }
  event_data <- fread(report_path)
  if (nrow(event_data) == 0) {
    cat("INFO: Input file is empty. No report to generate.\n")
    return(invisible(TRUE))
  }
  
  # --- Monthly Aggregation ---
  event_data[, month := floor_date(date, "month")]
  monthly_summary <- event_data[, .(
    red_ratio = mean(category == "Red"),
    n_total = .N,
    n_red = sum(category == "Red")
  ), by = .(year = year(month), month = floor_date(date, "month"))]
  
  # Add month_lab column to match old code exactly
  monthly_summary[, month_lab := factor(format(month, "%b"), levels = month.abb, ordered = TRUE)]
  
  # Reorder columns to match old code exactly: year, month, month_lab, red_ratio, n_total, n_red
  monthly_summary <- monthly_summary[, .(year, month, month_lab, red_ratio, n_total, n_red)]
  setorder(monthly_summary, year, month)
  
  # --- Save Monthly Summary Data ---
  summary_out_path <- file.path(config$paths$output_reports, "monthly_red_ratio_summary.csv")
  cat("INFO: Saving monthly red ratio summary to:", summary_out_path, "\n")
  fwrite(monthly_summary, summary_out_path)
  
  # --- Dynamic Plot Generation (Based on Old Code Structure) ---
  years <- sort(unique(monthly_summary$year))
  num_years <- length(years)
  
  cat("INFO: Generating", ifelse(num_years == 1, 3, 5), "plots for", num_years, "year(s):", paste(years, collapse = ", "), "\n")
  
  # Helper plotting theme (matching old code)
  theme_base <- theme_minimal(base_size = 12) +
    theme(
      panel.grid.minor = element_blank(),
      axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1)
    )
  
  # --- 1) Individual yearly plots (one per year) ---
  for (yr in years) {
    p_individual <- monthly_summary %>%
      filter(year == yr) %>%
      ggplot(aes(x = month_lab, y = red_ratio, group = year)) +
      geom_line(color = "#0072B2") +
      geom_point(color = "#0072B2", size = 2) +
      scale_y_continuous(limits = c(0, max(monthly_summary$red_ratio) * 1.1), 
                         labels = scales::percent_format(accuracy = 1)) +
      labs(
        title = paste("Red Category Ratio by Month —", yr),
        x = "Month",
        y = "Red Ratio"
      ) +
      theme_base
    
    individual_path <- file.path(plot_dir, paste0("red_ratio_monthly_", yr, ".png"))
    ggsave(individual_path, plot = p_individual, width = 11, height = 4, dpi = 200)
    cat("INFO: Saved individual year plot:", individual_path, "\n")
  }
  
  # --- 2) Combined faceted plot (all years in panels) ---
  p_faceted <- monthly_summary %>%
    ggplot(aes(x = month_lab, y = red_ratio, color = factor(year), group = year)) +
    geom_line() +
    geom_point(size = 2) +
    facet_wrap(~year, ncol = 1, scales = "free_x") +
    scale_y_continuous(limits = c(0, max(monthly_summary$red_ratio) * 1.1), 
                       labels = scales::percent_format(accuracy = 1)) +
    scale_color_discrete(name = "Year") +
    labs(
      title = "Red Category Ratio by Month — All Years",
      x = "Month",
      y = "Red Ratio"
    ) +
    theme_base +
    theme(legend.position = "none")
  
  faceted_path <- file.path(plot_dir, "red_ratio_monthly_all_years_faceted.png")
  ggsave(faceted_path, plot = p_faceted, width = 11, height = max(4, 2.5 * num_years), dpi = 200)
  cat("INFO: Saved faceted plot:", faceted_path, "\n")
  
  # --- 3) Overlay plot (all years overlayed) ---
  if (num_years == 1) {
    # For single year, create a simplified overlay plot
    p_overlay <- monthly_summary %>%
      ggplot(aes(x = month_lab, y = red_ratio, group = year)) +
      geom_line(color = "#0072B2") +
      geom_point(color = "#0072B2", size = 2) +
      scale_y_continuous(limits = c(0, max(monthly_summary$red_ratio) * 1.1), 
                         labels = scales::percent_format(accuracy = 1)) +
      labs(
        title = paste("Red Category Ratio by Month (", years[1], ")"),
        x = "Month",
        y = "Red Ratio"
      ) +
      theme_base
  } else {
    # For multiple years, create true overlay
    p_overlay <- monthly_summary %>%
      ggplot(aes(x = month_lab, y = red_ratio, color = factor(year), group = year)) +
      geom_line() +
      geom_point(size = 2) +
      scale_y_continuous(limits = c(0, max(monthly_summary$red_ratio) * 1.1), 
                         labels = scales::percent_format(accuracy = 1)) +
      scale_color_discrete(name = "Year") +
      labs(
        title = "Red Category Ratio by Month (Overlayed by Year)",
        x = "Month",
        y = "Red Ratio"
      ) +
      theme_base
  }
  
  overlay_path <- file.path(plot_dir, "red_ratio_monthly_overlay.png")
  ggsave(overlay_path, plot = p_overlay, width = 11, height = 5, dpi = 200)
  cat("INFO: Saved overlay plot:", overlay_path, "\n")
  
  # --- Generate interactive plot (using faceted for consistency) ---
  p_interactive <- monthly_summary %>%
    ggplot(aes(x = month_lab, y = red_ratio, text = paste0(
      "Month: ", format(month, "%b %Y"), "<br>",
      "Red Ratio: ", scales::percent(red_ratio, accuracy = 0.1), "<br>",
      "Red Events: ", n_red, " of ", n_total
    ))) +
    geom_line(aes(group = year), color = "#0072B2") +
    geom_point(color = "#0072B2", size = 2) +
    facet_wrap(~year, scales = "free_x", ncol = 1) +
    scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, NA)) +
    labs(
      title = "Monthly 'Red' Event Ratio at SP Boundaries",
      subtitle = "Interactive view - hover for details",
      x = "Month",
      y = "Red Ratio"
    ) +
    theme_minimal(base_size = 12)
  
  # --- Save Interactive HTML Plot (with error handling) ---
  interactive_plot <- ggplotly(p_interactive, tooltip = "text")
  plot_out_path_html <- file.path(plot_dir, "interactive_monthly_red_ratio.html")
  
  tryCatch({
    saveWidget(interactive_plot, file = plot_out_path_html, selfcontained = TRUE)
    cat("INFO: Saved interactive HTML plot:", plot_out_path_html, "\n")
  }, error = function(e) {
    cat("WARN: Could not save HTML report (pandoc required):", e$message, "\n")
    cat("INFO: All static PNG plots saved successfully instead.\n")
  })
  
  # --- Summary of generated plots ---
  total_plots <- num_years + 2 + ifelse(file.exists(plot_out_path_html), 1, 0)
  cat("SUCCESS: Generated", total_plots, "plots total:\n")
  cat("  -", num_years, "individual year plot(s)\n")
  cat("  - 1 faceted plot (all years)\n") 
  cat("  - 1 overlay plot\n")
  if (file.exists(plot_out_path_html)) cat("  - 1 interactive HTML plot\n")
  
  return(invisible(TRUE))
}


#' Main reporting function called by the orchestrator.
#'
#' This function acts as a controller, calling specialized helpers to generate
#' all required reports.
#'
#' @param config The application configuration list.
#' @return Invisibly returns TRUE on success.
#'
#' Generates plots for frequency excursion analysis.
#'
#' This function reads the frequency excursion summary files and generates
#' visualizations for excursion counts, durations, and frequency state percentages.
#'
#' @param config The application configuration list.
#' @return Invisibly returns TRUE on success.
#'
generate_frequency_excursion_report <- function(config) {
  cat("INFO: Generating report for 'frequency_excursion' analysis...\n")

  # Define paths
  monthly_path <- file.path(config$paths$output_reports, "frequency_excursion_monthly.csv")
  plot_dir <- config$paths$output_plots

  # Check if files exist
  if (!file.exists(monthly_path)) {
    cat("WARN: Frequency excursion monthly data not found. Skipping report.\n")
    return(invisible(FALSE))
  }

  # Load data
  monthly_data <- fread(monthly_path)
  monthly_data[, month := as.Date(month)]

  if (nrow(monthly_data) == 0) {
    cat("INFO: No excursion data to plot.\n")
    return(invisible(TRUE))
  }

  # Split data by threshold
  df_01 <- monthly_data[threshold == 0.1]
  df_015 <- monthly_data[threshold == 0.15]
  df_02 <- monthly_data[threshold == 0.2]

  # --- Plot 1: Number of Excursions - Monthly Time Series ---
  p1_fallback <- monthly_data %>%
    ggplot(aes(x = month, y = num_excursions, color = factor(threshold))) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 3) +
    scale_color_manual(values = c("0.1" = "#ff7f0e", "0.15" = "#2ca02c", "0.2" = "#1f77b4"),
                       name = "Threshold (Hz)") +
    labs(title = "Number of Excursions", x = "", y = "Number of Excursions") +
    theme_minimal(base_size = 13) +
    theme(legend.position = "bottom")

  plot1_path <- file.path(plot_dir, "excursion_count_monthly.png")
  ggsave(plot1_path, plot = p1_fallback, width = 12, height = 6, dpi = 200)
  cat("INFO: Saved plot:", plot1_path, "\n")

  # --- Plot 2: Total Duration - Monthly Time Series ---
  p2_fallback <- monthly_data %>%
    ggplot(aes(x = month, y = total_duration_sec, color = factor(threshold))) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 3) +
    scale_color_manual(values = c("0.1" = "#ff7f0e", "0.15" = "#2ca02c", "0.2" = "#1f77b4"),
                       name = "Threshold (Hz)") +
    labs(title = "Total Duration of Excursions", x = "", y = "Duration (seconds)") +
    theme_minimal(base_size = 13) +
    theme(legend.position = "bottom")

  plot2_path <- file.path(plot_dir, "excursion_duration_monthly.png")
  ggsave(plot2_path, plot = p2_fallback, width = 12, height = 6, dpi = 200)
  cat("INFO: Saved plot:", plot2_path, "\n")

  cat("SUCCESS: Generated 2 frequency excursion plots\n")
  return(invisible(TRUE))
}


generate_reports <- function(config) {
  cat("INFO: Starting report generation process...\n")

  # Call the report generator for the event detection analysis
  generate_event_detection_report(config)

  # Call the report generator for frequency excursion analysis
  generate_frequency_excursion_report(config)

  # TODO: Add calls to other report generators here (e.g., for KPI monitoring)
  # generate_kpi_monitoring_report(config)

  cat("SUCCESS: Report generation complete.\n")
  return(invisible(TRUE))
}