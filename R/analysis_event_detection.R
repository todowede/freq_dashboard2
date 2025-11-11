# R/analysis_event_detection.R
# Purpose: Functions to detect and classify frequency events at SP boundaries.

# --- Dependencies ---
suppressPackageStartupMessages({
  library(data.table)
  library(lubridate)
  library(ggplot2)
})

# Helper function for null-coalescing
`%||%` <- function(x, y) if (is.null(x)) y else x


#' Detects the trend in a window of frequency data using linear regression.
#'
#' This is a more robust method than simple min/max comparison as it considers
#' all points in the window and is less susceptible to noise or single-point outliers.
#'
#' @param f_values A numeric vector of frequency values from the window.
#' @return A character string: "Up", "Down", "Flat", or "Unknown".
#'
detect_trend_robustly <- function(f_values) {
  # A trend requires a minimum number of data points to be meaningful.
  if (length(f_values) < 5) return("Unknown")
  
  # Create a simple time series index (1, 2, 3, ...)
  time_steps <- 1:length(f_values)
  
  # Use a safe wrapper for the linear model in case of errors
  model <- tryCatch(lm(f_values ~ time_steps), error = function(e) NULL)
  if (is.null(model)) return("Unknown")
  
  summary_model <- summary(model)
  # Check for singularity or other issues where coefficients can't be calculated
  if (nrow(summary_model$coefficients) < 2) return("Flat")
  
  # Extract the slope (the trend) and its p-value (statistical significance)
  slope <- summary_model$coefficients[2, 1]
  p_value <- summary_model$coefficients[2, 4]
  
  # Trend is considered "Flat" if the slope is negligible or not statistically significant
  if (is.na(slope) || abs(slope) < 1e-5 || p_value > 0.05) {
    return("Flat")
  } else if (slope > 0) {
    return("Up")
  } else {
    return("Down")
  }
}


#' Detects and classifies frequency events around 30-minute SP boundaries.
#'
#' This is the main function for this module. It orchestrates the process of
#' identifying SP boundaries, extracting data for each one, calculating a rich
#' set of advanced metrics, classifying the event, and saving the results.
#'
#' @param processed_data A data.table from `frequency_processor` with columns
#'   'dtm_sec', 'f', and 'rocof'.
#' @param config The application configuration list.
#'
#' @return A data.table containing the results of the boundary analysis.
#'
run_event_detection <- function(processed_data, config) {
  
  # --- 1. Get Parameters from Config ---
  cat("INFO: Starting SP boundary event detection analysis...\n")
  
  params <- config$parameters$event_detection
  
  # Add validation checks for required config parameters
  required_params <- c("window_seconds", "delta_f_hz", "rocof_p99_hz_s")
  if (is.null(params) || !all(required_params %in% names(params))) {
    stop("Configuration error: 'event_detection' section or one of its keys (window_seconds, delta_f_hz, rocof_p99_hz_s) is missing in config.yml.", call. = FALSE)
  }
  
  window_sec <- as.integer(params$window_seconds)
  thresh_df <- as.numeric(params$delta_f_hz)
  thresh_rocof <- as.numeric(params$rocof_p99_hz_s)
  
  cat(paste0("INFO: Parameters: Window= +/-", window_sec, "s, ",
             "Δf Threshold=", thresh_df, " Hz, ",
             "p99|ROCOF| Threshold=", thresh_rocof, " Hz/s\n"))
  
  # Check: Ensure there is enough data to analyze
  if (!is.data.table(processed_data) || nrow(processed_data) < 2) {
    cat("WARN: Not enough processed data to perform event detection. Skipping.\n")
    return(data.table())
  }
  
  # --- 2. Build SP Boundary Timeline ---
  min_time <- min(processed_data$dtm_sec)
  max_time <- max(processed_data$dtm_sec)
  
  boundaries_dt <- data.table(
    boundary_tm = seq(
      from = floor_date(min_time, "30 minutes"),
      to = ceiling_date(max_time, "30 minutes"),
      by = "30 mins"
    )
  )
  
  boundaries_dt[, `:=`(
    win_start = boundary_tm - seconds(window_sec),
    win_end = boundary_tm + seconds(window_sec)
  )]
  # Settlement Period handling:
  # - Raw timestamps arrive as UTC but are stored as POSIXct in the host tz (Europe/London, incl. BST).
  # - NESO defines SP01 as 00:00-00:30 GMT, SP02 as 00:30-01:00 GMT, … SP48 as 23:30-00:00 GMT.
  # - To keep numbering stable regardless of DST, convert each boundary back to UTC before converting it
  #   into a half-hour slot and wrap the result into [1, 48].
  boundaries_dt[, starting_sp := {
    boundary_utc <- with_tz(boundary_tm, tzone = "UTC")
    as.integer((((hour(boundary_utc) * 60L) + minute(boundary_utc)) %/% 30L) %% 48L + 1L)
  }]
  # --- 3. Extract Window Data using a Non-Equi Join ---
  setkey(processed_data, dtm_sec)
  
  window_data <- processed_data[boundaries_dt,
                                on = .(dtm_sec >= win_start, dtm_sec <= win_end),
                                nomatch = 0L,
                                .(
                                  boundary_tm,
                                  starting_sp,
                                  window_dtm = x.dtm_sec,
                                  f,
                                  rocof
                                )
  ]
  
  # --- 4. Calculate Metrics for Each Window ---
  cat("INFO: Calculating metrics for", format(nrow(boundaries_dt), big.mark = ","), "SP boundaries...\n")
  
  results <- window_data[, {
    
    # Basic metrics
    min_f <- min(f, na.rm = TRUE)
    max_f <- max(f, na.rm = TRUE)
    abs_freq_change <- max_f - min_f
    rocof_abs <- abs(rocof[!is.na(rocof)])
    rocof_p99 <- if (length(rocof_abs) > 0) as.numeric(quantile(rocof_abs, 0.99)) else 0
    
    # Trend Detection using linear regression
    trend <- detect_trend_robustly(f)
    
    # Event Timing (Pre vs. Post Boundary)
    min_time_rel <- window_dtm[which.min(f)] - boundary_tm
    max_time_rel <- window_dtm[which.max(f)] - boundary_tm
    event_timing <- if (abs(min_time_rel) < abs(max_time_rel)) "Min First" else "Max First"
    
    # Strategic Tuning Detection
    is_tuning_event <- FALSE
    if (length(rocof_abs) > 10) {
      if (mean(rocof_abs) < 0.005 && sd(rocof_abs) < 0.003) {
        is_tuning_event <- TRUE
      }
    }
    
    # Severity Score for ranking events
    severity <- (abs_freq_change / thresh_df) + (rocof_p99 / thresh_rocof)
    
    # Return a list of all calculated metrics for this window
    .(
      min_f = min_f,
      max_f = max_f,
      abs_freq_change = abs_freq_change,
      rocof_p99 = rocof_p99,
      trend = trend,
      event_timing = event_timing,
      is_tuning = is_tuning_event,
      severity = severity
    )
  }, by = .(boundary_tm, starting_sp)]
  
  # --- 5. Classify Events and Finalize ---
  results[, category := fcase(
    is_tuning == TRUE, "Tuning",
    abs_freq_change > thresh_df & rocof_p99 > thresh_rocof, "Red",
    default = "Green"
  )]
  
  # Original classification for backward compatibility (matches old code exactly)
  results[, category_old := ifelse(
    abs_freq_change > thresh_df & rocof_p99 > thresh_rocof,
    "Red", "Green"
  )]
  
  setorder(results, boundary_tm)
  
  # Prepare final output table with all advanced metrics
  output_dt <- results[, .(
    date = as.Date(boundary_tm),
    starting_sp,
    boundary_time = boundary_tm,
    min_f = round(min_f, 5),
    max_f = round(max_f, 5),
    abs_freq_change = round(abs_freq_change, 5),
    rocof_p99 = round(rocof_p99, 6),
    trend,
    event_timing,
    category,           # Enhanced classification (Red/Green/Tuning)
    category_old,       # Original classification for compatibility (Red/Green only)
    severity = round(severity, 2)
  )]
  
  # --- 6. Save Output ---
  out_path <- file.path(config$paths$output_reports, "sp_boundary_events.csv")
  cat("INFO: Saving enhanced event detection results to:", out_path, "\n")
  fwrite(output_dt, out_path)
  
  cat("SUCCESS: Event detection complete.", 
      format(output_dt[category == "Red", .N], big.mark = ","), "Red events found,",
      format(output_dt[category == "Tuning", .N], big.mark = ","), "Tuning events identified.\n")
  cat("INFO: Compatibility check - Old classification:",
      format(output_dt[category_old == "Red", .N], big.mark = ","), "Red,",
      format(output_dt[category_old == "Green", .N], big.mark = ","), "Green.\n")
  
  # --- 7. Generate Verification Plots ---
  generate_verification_plots(output_dt, processed_data, config)
  
  return(output_dt)
}


#' Generates verification plots for Red events based on configuration settings.
#'
#' This function creates individual frequency profile plots for Red events to allow
#' manual inspection and verification of the automated classification. The plots
#' show the 30-seconds window around each SP boundary with detailed metrics.
#'
#' @param event_results A data.table from run_event_detection with event classifications.
#' @param processed_data A data.table with per-second frequency and ROCOF data.
#' @param config The application configuration list.
#'
#' @return Invisibly returns the number of plots generated.
#'
generate_verification_plots <- function(event_results, processed_data, config) {
  
  # Check if verification plotting is enabled
  verif_config <- config$parameters$event_detection$verification_plots
  if (is.null(verif_config) || !isTRUE(verif_config$enabled)) {
    cat("INFO: Verification plotting disabled in configuration.\n")
    return(invisible(0))
  }
  
  # Create verification directory
  verif_dir <- file.path(config$paths$processed, "..", "verification")
  if (!dir.exists(verif_dir)) {
    dir.create(verif_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  # Filter for Red events (using category_old for consistency with old code)
  red_events <- event_results[category_old == "Red"]
  
  if (nrow(red_events) == 0) {
    cat("INFO: No Red events found - no verification plots to generate.\n")
    return(invisible(0))
  }
  
  cat("INFO: Found", nrow(red_events), "Red events for potential verification plotting.\n")
  
  # Determine which events to plot based on strategy
  events_to_plot <- select_events_for_plotting(red_events, verif_config)
  
  if (nrow(events_to_plot) == 0) {
    cat("WARN: No events selected for plotting after applying strategy.\n")
    return(invisible(0))
  }
  
  cat("INFO: Generating", nrow(events_to_plot), "verification plots using strategy '", 
      verif_config$strategy, "'...\n")
  
  # Get plot parameters
  window_sec <- config$parameters$event_detection$window_seconds
  plot_width <- verif_config$plot_width %||% 12
  plot_height <- verif_config$plot_height %||% 5
  plot_dpi <- verif_config$plot_dpi %||% 150
  
  # Generate plots
  plots_generated <- 0
  
  for (i in seq_len(nrow(events_to_plot))) {
    event <- events_to_plot[i]
    
    # Extract window data for this event
    window_start <- as.POSIXct(event$boundary_time) - seconds(window_sec)
    window_end <- as.POSIXct(event$boundary_time) + seconds(window_sec)
    
    window_data <- processed_data[dtm_sec >= window_start & dtm_sec <= window_end]
    
    if (nrow(window_data) < 2) {
      cat("WARN: Insufficient data for event at", as.character(event$boundary_time), "- skipping plot.\n")
      next
    }
    
    # Create plot filename
    plot_tag <- paste0(format(as.POSIXct(event$boundary_time), "%Y%m%d_%H%M"), "_SP", event$starting_sp)
    plot_filename <- paste0("red_event_", plot_tag, ".png")
    plot_path <- file.path(verif_dir, plot_filename)
    
    # Create detailed plot title
    plot_title <- paste0(
      "Red Event: ", format(as.POSIXct(event$boundary_time), "%Y-%m-%d %H:%M"),
      " (SP ", event$starting_sp, ")\n",
      "Δf = ", sprintf("%.3f", event$abs_freq_change), " Hz  |  ",
      "p99|ROCOF| = ", sprintf("%.6f", event$rocof_p99), " Hz/s  |  ",
      "Trend: ", event$trend, "  |  ",
      "Severity: ", sprintf("%.2f", event$severity)
    )
    
    # Create the plot
    p <- ggplot(window_data, aes(x = dtm_sec, y = f)) +
      geom_line(color = "#1f77b4", linewidth = 0.8) +
      geom_vline(xintercept = as.POSIXct(event$boundary_time), 
                 linetype = "dashed", color = "#d62728", linewidth = 1) +
      geom_point(data = window_data[which.min(f)], 
                 aes(x = dtm_sec, y = f), color = "#ff7f0e", size = 3, shape = 19) +
      geom_point(data = window_data[which.max(f)], 
                 aes(x = dtm_sec, y = f), color = "#2ca02c", size = 3, shape = 17) +
      scale_x_datetime(
        name = "Time (UTC)",
        date_labels = "%H:%M:%S",
        date_breaks = "10 secs"
      ) +
      scale_y_continuous(
        name = "Frequency (Hz)",
        limits = c(min(window_data$f, na.rm = TRUE) - 0.005, 
                   max(window_data$f, na.rm = TRUE) + 0.005)
      ) +
      labs(title = plot_title) +
      theme_minimal(base_size = 11) +
      theme(
        plot.title = element_text(size = 10, hjust = 0.5),
        axis.text.x = element_text(angle = 45, hjust = 1),
        panel.grid.minor = element_blank()
      ) +
      annotate("text", x = as.POSIXct(event$boundary_time), y = max(window_data$f, na.rm = TRUE),
               label = "SP Boundary", hjust = 0.5, vjust = -0.5, size = 3, color = "#d62728")
    
    # Save the plot
    tryCatch({
      ggsave(plot_path, plot = p, width = plot_width, height = plot_height, dpi = plot_dpi)
      plots_generated <- plots_generated + 1
    }, error = function(e) {
      cat("ERROR: Failed to save plot", plot_filename, ":", e$message, "\n")
    })
  }
  
  cat("SUCCESS: Generated", plots_generated, "verification plots in:", verif_dir, "\n")
  return(invisible(plots_generated))
}


#' Selects which Red events to plot based on the configured strategy.
#'
#' @param red_events A data.table of Red events.
#' @param verif_config The verification plotting configuration.
#' @return A data.table of events selected for plotting.
#'
select_events_for_plotting <- function(red_events, verif_config) {
  
  strategy <- verif_config$strategy %||% "all"
  count <- verif_config$count %||% 100
  sort_by <- verif_config$sort_by %||% "severity"
  
  # Ensure we have a severity column for sorting
  if (!"severity" %in% names(red_events)) {
    red_events[, severity := abs_freq_change + rocof_p99]
  }
  
  # Apply sorting based on sort_by parameter
  if (sort_by == "severity") {
    setorder(red_events, -severity)  # Descending (worst first)
  } else if (sort_by == "abs_freq_change") {
    setorder(red_events, -abs_freq_change)
  } else if (sort_by == "rocof_p99") {
    setorder(red_events, -rocof_p99)
  } else if (sort_by == "chronological") {
    setorder(red_events, date, starting_sp)
  }
  
  # Apply selection strategy
  if (strategy == "all") {
    return(red_events)
  } else if (strategy == "top_N") {
    return(head(red_events, count))
  } else if (strategy == "worst_N") {
    # Sort by severity descending and take top N
    setorder(red_events, -severity)
    return(head(red_events, count))
  } else if (strategy == "best_N") {
    # Sort by severity ascending and take top N
    setorder(red_events, severity)
    return(head(red_events, count))
  } else if (strategy == "random_N") {
    # Randomly sample N events
    if (nrow(red_events) <= count) {
      return(red_events)
    } else {
      sample_indices <- sample(nrow(red_events), count)
      return(red_events[sample_indices])
    }
  } else {
    cat("WARN: Unknown strategy '", strategy, "' - defaulting to 'top_N'.\n")
    return(head(red_events, count))
  }
}
