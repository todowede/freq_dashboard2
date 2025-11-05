# R/analysis_demand.R
# Purpose: Analyze demand patterns at Settlement Period boundaries and correlate with frequency events
#
# This module performs demand analysis including:
# - Loading and processing demand data per SP
# - Calculating demand changes across SP boundaries
# - Correlating demand with frequency events
# - Identifying peak demand periods and anomalies

# --- Dependencies ---
suppressPackageStartupMessages({
  library(data.table)
  library(lubridate)
})

#' Main function to analyze demand at SP boundaries
#'
#' This function loads demand data, calculates various metrics at each settlement
#' period, and correlates demand patterns with detected frequency events.
#'
#' @param event_results A data.table from event_detection with classified SP boundary events
#' @param config The application configuration list
#'
#' @return A data.table containing demand analysis results
#'
run_demand_analysis <- function(event_results = NULL, config) {

  cat("\n============================================================\n")
  cat("INFO: Starting Demand Analysis at SP Boundaries\n")
  cat("============================================================\n\n")

  # --- 1. Load Demand Data ---
  demand_path <- file.path(config$paths$input, "system_demand.csv")

  if (!file.exists(demand_path)) {
    cat("ERROR: Demand data file not found:", demand_path, "\n")
    cat("NOTE: This module requires 'system_demand.csv' in the input directory.\n")
    return(data.table())
  }

  cat("INFO: Loading demand data from:", demand_path, "\n")

  demand_raw <- tryCatch({
    fread(demand_path)
  }, error = function(e) {
    cat("ERROR: Failed to load demand data:", e$message, "\n")
    return(NULL)
  })

  if (is.null(demand_raw) || nrow(demand_raw) == 0) {
    cat("ERROR: No demand data loaded.\n")
    return(data.table())
  }

  cat("INFO: Loaded", nrow(demand_raw), "demand records.\n")

  # --- 2. Process Demand Data ---
  cat("INFO: Processing demand data...\n")

  # Standardize column names
  setnames(demand_raw, old = names(demand_raw), new = toupper(names(demand_raw)))

  # Parse settlement date - handle multiple formats
  # Some rows use "31-DEC-2024" format, others use "2025-01-01" format
  demand_raw[, Date := {
    date_str <- SETTLEMENT_DATE
    # Try format 1: DD-MMM-YYYY (e.g., "31-DEC-2024")
    parsed <- as.Date(date_str, format = "%d-%b-%Y")
    # If that fails, try format 2: YYYY-MM-DD (e.g., "2025-01-01")
    if (any(is.na(parsed))) {
      parsed[is.na(parsed)] <- as.Date(date_str[is.na(parsed)], format = "%Y-%m-%d")
    }
    parsed
  }]

  demand_raw[, SP := as.integer(SETTLEMENT_PERIOD)]

  # Report parsing success
  n_parsed <- demand_raw[!is.na(Date), .N]
  n_total <- nrow(demand_raw)
  cat(sprintf("INFO: Successfully parsed %d / %d dates (%.1f%%)\n",
              n_parsed, n_total, 100 * n_parsed / n_total))

  # Get configured metrics
  params <- config$parameters$demand_analysis
  metrics_to_use <- params$metrics %||% c("ND", "TSD")

  # Select relevant columns
  demand_cols <- c("Date", "SP")
  for (metric in metrics_to_use) {
    if (metric %in% names(demand_raw)) {
      demand_cols <- c(demand_cols, metric)
    } else {
      cat("WARN: Requested metric '", metric, "' not found in demand data. Skipping.\n", sep = "")
    }
  }

  demand_data <- demand_raw[, .SD, .SDcols = demand_cols]
  demand_data <- demand_data[!is.na(Date) & !is.na(SP)]

  # Remove rows with all NA metrics
  metric_cols <- setdiff(demand_cols, c("Date", "SP"))

  if (length(metric_cols) > 0) {
    # Remove rows where all metrics are NA
    # Create a helper column that counts non-NA values across metric columns
    demand_data[, .temp_na_count := rowSums(!is.na(.SD)), .SDcols = metric_cols]
    # Keep rows where at least one metric is not NA
    demand_data <- demand_data[.temp_na_count > 0]
    # Remove helper column
    demand_data[, .temp_na_count := NULL]
  }

  cat("INFO: Processed", nrow(demand_data), "SP records with demand metrics:", paste(metric_cols, collapse = ", "), "\n")

  # --- 3. Calculate Demand Changes ---
  if (params$analyze_demand_changes %||% TRUE) {
    cat("INFO: Calculating demand changes across SP boundaries...\n")

    setorder(demand_data, Date, SP)

    for (metric in metric_cols) {
      # Calculate change from previous SP
      demand_data[, paste0("Delta_", metric) := get(metric) - shift(get(metric), 1)]

      # Handle day transitions (SP 48 -> SP 1)
      demand_data[SP == 1, paste0("Delta_", metric) := NA]
    }

    cat("INFO: Added demand change columns for:", paste(metric_cols, collapse = ", "), "\n")
  }

  # --- 4. Calculate Summary Statistics ---
  cat("INFO: Calculating summary statistics...\n")

  # Hourly averages
  demand_data[, Hour := (SP - 1) %/% 2]

  hourly_summary <- demand_data[, {
    result <- list()  # Don't add Hour here - it's automatically added by the by clause
    for (metric in metric_cols) {
      if (metric %in% names(.SD)) {
        result[[paste0(metric, "_Mean")]] <- mean(get(metric), na.rm = TRUE)
        result[[paste0(metric, "_Min")]] <- min(get(metric), na.rm = TRUE)
        result[[paste0(metric, "_Max")]] <- max(get(metric), na.rm = TRUE)
      }
    }
    result
  }, by = .(Hour)]

  # Daily peaks
  daily_peaks <- demand_data[, {
    result <- list()  # Don't add Date here - it's automatically added by the by clause
    for (metric in metric_cols) {
      if (metric %in% names(.SD)) {
        result[[paste0(metric, "_Peak")]] <- max(get(metric), na.rm = TRUE)
        peak_sp <- SP[which.max(get(metric))]
        result[[paste0(metric, "_PeakSP")]] <- ifelse(length(peak_sp) > 0, peak_sp, NA)
      }
    }
    result
  }, by = .(Date)]

  # --- 5. Correlate with Frequency Events (if available) ---
  if (!is.null(event_results) && nrow(event_results) > 0 && (params$correlate_with_events %||% TRUE)) {
    cat("INFO: Correlating demand with frequency events...\n")

    # Prepare event data for join
    events_for_join <- event_results[, .(date, starting_sp, category, severity, abs_freq_change)]
    setnames(events_for_join, c("date", "starting_sp"), c("Date", "SP"))
    events_for_join[, Date := as.Date(Date)]

    # Join demand data with events
    demand_with_events <- merge(demand_data, events_for_join, by = c("Date", "SP"), all.x = TRUE)

    # Flag rows with events
    demand_with_events[, HasEvent := !is.na(category)]
    demand_with_events[, EventCategory := ifelse(is.na(category), "None", as.character(category))]

    cat("INFO: Matched", demand_with_events[HasEvent == TRUE, .N], "demand records with frequency events.\n")

    # Calculate statistics by event category
    event_correlation <- demand_with_events[, {
      result <- list(Count = .N)  # Don't add EventCategory here - it's automatically added by the by clause
      for (metric in metric_cols) {
        if (metric %in% names(.SD)) {
          result[[paste0(metric, "_Mean")]] <- mean(get(metric), na.rm = TRUE)
          result[[paste0(metric, "_SD")]] <- sd(get(metric), na.rm = TRUE)
        }
      }
      result
    }, by = .(EventCategory)]

  } else {
    cat("INFO: Skipping event correlation (no event data provided or correlation disabled).\n")
    demand_with_events <- demand_data
    demand_with_events[, HasEvent := FALSE]
    demand_with_events[, EventCategory := "None"]
    event_correlation <- data.table(EventCategory = character(), Count = integer())
  }

  # --- 6. Save Results ---
  cat("\n============================================================\n")
  cat("INFO: Saving demand analysis results...\n")

  output_dir <- config$paths$output_reports

  # Main demand data with events
  output_path_main <- file.path(output_dir, "demand_at_sp_boundaries.csv")
  fwrite(demand_with_events, output_path_main)
  cat("SUCCESS: Saved detailed demand data to:", output_path_main, "\n")

  # Hourly summary
  output_path_hourly <- file.path(output_dir, "demand_hourly_summary.csv")
  fwrite(hourly_summary, output_path_hourly)
  cat("SUCCESS: Saved hourly summary to:", output_path_hourly, "\n")

  # Daily peaks
  output_path_peaks <- file.path(output_dir, "demand_daily_peaks.csv")
  fwrite(daily_peaks, output_path_peaks)
  cat("SUCCESS: Saved daily peaks to:", output_path_peaks, "\n")

  # Event correlation (if exists)
  if (nrow(event_correlation) > 0) {
    output_path_correlation <- file.path(output_dir, "demand_event_correlation.csv")
    fwrite(event_correlation, output_path_correlation)
    cat("SUCCESS: Saved event correlation to:", output_path_correlation, "\n")
  }

  cat("\n============================================================\n")
  cat("SUCCESS: Demand analysis complete!\n")
  cat("  - Analyzed", nrow(demand_with_events), "settlement periods\n")
  cat("  - Date range:", min(demand_with_events$Date), "to", max(demand_with_events$Date), "\n")
  cat("  - Metrics:", paste(metric_cols, collapse = ", "), "\n")
  cat("============================================================\n\n")

  return(demand_with_events)
}
