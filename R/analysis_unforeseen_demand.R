# R/analysis_unforeseen_demand.R
# Purpose: Analyze unforeseen demand changes at SP boundaries with demand damping separation
#
# This module addresses Ed's core challenge:
# - Separate market-driven demand changes from natural demand damping
# - Identify truly "unforeseen" demand events that NESO cannot predict
# - Quantify the magnitude and frequency of unexpected demand swings
#
# Business Context:
# Price signals cause coordinated demand changes at SP boundaries that NESO
# cannot anticipate. When frequency also changes, we need to distinguish:
# - Market-driven changes (unforeseen - need extra reserve)
# - Natural damping response (helpful - automatic stabilization)

# --- Dependencies ---
suppressPackageStartupMessages({
  library(data.table)
  library(lubridate)
})


#' Main function to run unforeseen demand analysis
#'
#' This function merges demand and frequency data, separates demand damping
#' from unforeseen changes, applies statistical thresholds, and generates reports.
#'
#' @param config The application configuration list.
#' @return A data.table containing the analysis results.
#'
run_unforeseen_demand_analysis <- function(config) {

  cat("\n============================================================\n")
  cat("INFO: Starting Unforeseen Demand Change Analysis\n")
  cat("============================================================\n\n")

  # --- 1. Load Data ---
  cat("INFO: Loading demand and frequency data...\n")

  demand_path <- file.path(config$paths$output_reports, "demand_at_sp_boundaries.csv")
  freq_path <- file.path(config$paths$output_reports, "sp_boundary_events.csv")

  if (!file.exists(demand_path)) {
    cat("ERROR: Demand data not found at:", demand_path, "\n")
    cat("       Please run 'demand' analysis step first.\n")
    return(NULL)
  }

  if (!file.exists(freq_path)) {
    cat("ERROR: Frequency event data not found at:", freq_path, "\n")
    cat("       Please run 'event_detection' analysis step first.\n")
    return(NULL)
  }

  demand_data <- fread(demand_path)
  freq_data <- fread(freq_path)

  cat("  Loaded", nrow(demand_data), "demand records\n")
  cat("  Loaded", nrow(freq_data), "frequency event records\n\n")

  # --- 2. Merge Data ---
  cat("INFO: Merging demand and frequency data by Date and SP...\n")
  merged_data <- merge_demand_and_frequency(demand_data, freq_data, config)
  cat("  Merged data:", nrow(merged_data), "records\n\n")

  # --- 3. Calculate Demand Damping Component ---
  cat("INFO: Calculating demand damping component using actual demand...\n")
  damping_config <- get_damping_config(config)
  merged_data <- calculate_demand_damping(merged_data, damping_config)
  cat("  Damping percentage:", damping_config$percentage_per_hz * 100, "% per Hz (NESO standard)\n")
  cat("  Using formula: Damping (MW) = Demand (MW) × ", damping_config$percentage_per_hz, " × |Δf (Hz)|\n\n", sep = "")

  # --- 4. Calculate Unforeseen Component ---
  cat("INFO: Calculating unforeseen demand changes (total - damping)...\n")
  merged_data <- calculate_unforeseen_component(merged_data)

  # --- 5. Build Hourly Baseline ---
  cat("INFO: Building hourly statistical baseline...\n")
  hourly_baseline <- calculate_hourly_baseline(merged_data, config)
  cat("  Baseline calculated for 24 hours\n\n")

  # --- 6. Flag Unforeseen Events ---
  cat("INFO: Flagging unforeseen events using statistical thresholds...\n")
  merged_data <- flag_unforeseen_events(merged_data, hourly_baseline, config)

  # Count flagged events by metric
  for (metric in c("ND", "TSD", "ENGLAND_WALES_DEMAND")) {
    flag_col <- paste0("is_unforeseen_", metric)
    if (flag_col %in% names(merged_data)) {
      n_unforeseen <- sum(merged_data[[flag_col]], na.rm = TRUE)
      cat("  Unforeseen events (", metric, "):", n_unforeseen, "\n", sep = "")
    }
  }
  cat("\n")

  # --- 7. Assess Causality ---
  cat("INFO: Assessing causality (demand-led vs frequency-led)...\n")
  merged_data <- assess_causality(merged_data, config)

  if ("causality" %in% names(merged_data)) {
    causality_counts <- merged_data[, .N, by = causality]
    setorder(causality_counts, -N)
    cat("  Causality breakdown:\n")
    for (i in 1:nrow(causality_counts)) {
      cat("    ", causality_counts$causality[i], ":", causality_counts$N[i], "\n")
    }
  }
  cat("\n")

  # --- 8. Generate Reports ---
  cat("INFO: Generating reports...\n")
  save_unforeseen_demand_reports(merged_data, hourly_baseline, config)

  # --- 9. Print Summary ---
  print_unforeseen_demand_summary(merged_data, config)

  cat("\nSUCCESS: Unforeseen demand analysis complete!\n")
  cat("============================================================\n\n")

  return(merged_data)
}


#' Merge demand and frequency event data
#'
#' @param demand_data Demand data from demand_at_sp_boundaries.csv
#' @param freq_data Frequency event data from sp_boundary_events.csv
#' @param config Configuration list
#' @return Merged data.table
#'
merge_demand_and_frequency <- function(demand_data, freq_data, config) {

  # Ensure Date is Date type
  demand_data[, Date := as.Date(Date)]

  # Parse date from freq_data boundary_time if needed
  if (!"date" %in% names(freq_data) && "boundary_time" %in% names(freq_data)) {
    freq_data[, date := as.Date(boundary_time)]
  } else if ("date" %in% names(freq_data)) {
    freq_data[, date := as.Date(date)]
  }

  # Select relevant columns from frequency data
  freq_cols <- c("date", "starting_sp", "abs_freq_change", "rocof_p99",
                 "trend", "category", "severity", "min_f", "max_f")
  freq_subset <- freq_data[, .SD, .SDcols = intersect(freq_cols, names(freq_data))]

  # Remove old event columns from demand data to avoid conflicts
  demand_clean <- copy(demand_data)
  cols_to_remove <- c("category", "severity", "abs_freq_change", "HasEvent", "EventCategory")
  for (col in cols_to_remove) {
    if (col %in% names(demand_clean)) {
      demand_clean[, (col) := NULL]
    }
  }

  # Merge on Date and SP
  merged <- merge(
    demand_clean,
    freq_subset,
    by.x = c("Date", "SP"),
    by.y = c("date", "starting_sp"),
    all.x = TRUE
  )

  # Fill NAs for events with no frequency data
  if ("abs_freq_change" %in% names(merged)) {
    merged[is.na(abs_freq_change), abs_freq_change := 0]
  }
  if ("category" %in% names(merged)) {
    merged[is.na(category), category := "None"]
  }
  if ("trend" %in% names(merged)) {
    merged[is.na(trend), trend := "Unknown"]
  }

  return(merged)
}


#' Get damping configuration parameters
#'
#' @param config Configuration list
#' @return List with damping parameters
#'
get_damping_config <- function(config) {

  # Check if damping config exists in config file
  if (!is.null(config$parameters$unforeseen_demand$demand_damping)) {
    damping_config <- config$parameters$unforeseen_demand$demand_damping
  } else {
    # Default values
    damping_config <- list(
      percentage_per_hz = 0.025,  # 2.5% per Hz (NESO standard)
      apply_direction = TRUE  # Use trend to determine sign
    )
  }

  return(damping_config)
}


#' Calculate demand damping component for each event
#'
#' Expected damping (MW) = Actual Demand (MW) × Damping % × Frequency change (Hz)
#' Formula: Damping = Demand × 0.025 × |Δf|
#' Sign is determined by frequency trend (Up = positive freq change = negative demand)
#'
#' @param data Merged data.table
#' @param damping_config Damping configuration
#' @return data.table with damping columns added
#'
calculate_demand_damping <- function(data, damping_config) {

  pct_per_hz <- damping_config$percentage_per_hz

  # For each metric, calculate expected damping using actual demand
  for (metric in c("ND", "TSD", "ENGLAND_WALES_DEMAND")) {
    damping_col <- paste0(metric, "_damping")

    if ("abs_freq_change" %in% names(data) && metric %in% names(data)) {
      # Calculate damping: Demand × 2.5% × |Δf|
      # Use actual demand at each SP boundary
      data[, (damping_col) := get(metric) * pct_per_hz * abs_freq_change]

      # Apply direction based on trend if available
      if ("trend" %in% names(data) && damping_config$apply_direction) {
        # Frequency Up → demand decreases (negative damping)
        # Frequency Down → demand increases (positive damping)
        # The damping component counteracts the frequency change
        data[trend == "Up", (damping_col) := -1 * get(damping_col)]
        data[trend == "Down", (damping_col) := get(damping_col)]
        data[trend == "Flat", (damping_col) := 0]
        data[trend == "Unknown", (damping_col) := 0]
      }
    } else {
      # Fallback if data not available
      data[, (damping_col) := 0]
    }
  }

  return(data)
}


#' Calculate unforeseen demand component (total - damping)
#'
#' @param data Data.table with demand and damping columns
#' @return data.table with unforeseen columns added
#'
calculate_unforeseen_component <- function(data) {

  for (metric in c("ND", "TSD", "ENGLAND_WALES_DEMAND")) {
    delta_col <- paste0("Delta_", metric)
    damping_col <- paste0(metric, "_damping")
    unforeseen_col <- paste0(metric, "_unforeseen")

    if (delta_col %in% names(data) && damping_col %in% names(data)) {
      # Unforeseen = Total change - Expected damping
      data[, (unforeseen_col) := get(delta_col) - get(damping_col)]
    }
  }

  return(data)
}


#' Calculate hourly baseline statistics for unforeseen changes
#'
#' For each hour of day, calculate mean and SD of unforeseen changes
#'
#' @param data Data.table with unforeseen columns
#' @param config Configuration list
#' @return data.table with hourly statistics
#'
calculate_hourly_baseline <- function(data, config) {

  baseline_list <- list()

  for (metric in c("ND", "TSD", "ENGLAND_WALES_DEMAND")) {
    unforeseen_col <- paste0(metric, "_unforeseen")

    if (unforeseen_col %in% names(data)) {
      # Calculate by hour
      hourly <- data[!is.na(get(unforeseen_col)), .(
        mean_unforeseen = mean(get(unforeseen_col), na.rm = TRUE),
        sd_unforeseen = sd(get(unforeseen_col), na.rm = TRUE),
        n = .N
      ), by = Hour]

      # Get threshold multiplier from config or use default
      k <- ifelse(!is.null(config$parameters$unforeseen_threshold_sd),
                  config$parameters$unforeseen_threshold_sd,
                  2.5)

      hourly[, threshold := sd_unforeseen * k]
      hourly[, metric := metric]

      baseline_list[[metric]] <- hourly
    }
  }

  baseline <- rbindlist(baseline_list, use.names = TRUE, fill = TRUE)

  return(baseline)
}


#' Flag unforeseen events based on statistical thresholds
#'
#' @param data Data.table with unforeseen columns
#' @param hourly_baseline Hourly statistics
#' @param config Configuration list
#' @return data.table with flag columns added
#'
flag_unforeseen_events <- function(data, hourly_baseline, config) {

  for (metric in c("ND", "TSD", "ENGLAND_WALES_DEMAND")) {
    unforeseen_col <- paste0(metric, "_unforeseen")
    threshold_col <- paste0(metric, "_threshold")
    flag_col <- paste0("is_unforeseen_", metric)
    severity_col <- paste0(metric, "_event_severity")

    if (unforeseen_col %in% names(data)) {
      # Merge baseline statistics
      current_metric <- metric  # Store in variable for data.table subsetting
      baseline_subset <- hourly_baseline[metric == current_metric, .(Hour, mean_unforeseen, sd_unforeseen, threshold)]
      data <- merge(data, baseline_subset, by = "Hour", all.x = TRUE, suffixes = c("", paste0("_", metric)))

      # Rename merged columns
      setnames(data,
               c("mean_unforeseen", "sd_unforeseen", "threshold"),
               c(paste0("mean_unforeseen_", metric), paste0("sd_unforeseen_", metric), threshold_col),
               skip_absent = TRUE)

      # Calculate deviation from hourly mean
      mean_col <- paste0("mean_unforeseen_", metric)
      sd_col <- paste0("sd_unforeseen_", metric)

      data[, deviation := abs(get(unforeseen_col) - get(mean_col))]

      # Flag if deviation exceeds threshold
      data[, (flag_col) := deviation > get(threshold_col)]

      # Calculate severity (number of standard deviations)
      data[, (severity_col) := fifelse(
        !is.na(get(sd_col)) & get(sd_col) > 0,
        deviation / get(sd_col),
        0
      )]

      # Clean up temporary column
      data[, deviation := NULL]
    }
  }

  return(data)
}


#' Assess causality: demand-led vs frequency-led
#'
#' This is a simplified causality assessment based on available data.
#' For true causality, we'd need sub-second timing from raw frequency data.
#'
#' Heuristic:
#' - If large unforeseen demand change AND small frequency change → Demand-led
#' - If small unforeseen demand change AND large frequency change → Frequency-led
#' - Otherwise → Mixed or Simultaneous
#'
#' @param data Data.table with analysis results
#' @param config Configuration list
#' @return data.table with causality column added
#'
assess_causality <- function(data, config) {

  # Use ND as primary metric for causality assessment
  if ("ND_unforeseen" %in% names(data) && "abs_freq_change" %in% names(data)) {

    # Thresholds for "large" changes
    demand_threshold <- 800  # MW
    freq_threshold <- 0.05   # Hz

    data[, causality := fcase(
      abs(ND_unforeseen) > demand_threshold & abs_freq_change < freq_threshold, "Demand-led",
      abs(ND_unforeseen) < demand_threshold & abs_freq_change > freq_threshold, "Frequency-led",
      abs(ND_unforeseen) > demand_threshold & abs_freq_change > freq_threshold, "Mixed",
      default = "Minor"
    )]

  } else {
    data[, causality := "Unknown"]
  }

  return(data)
}


#' Save unforeseen demand analysis reports
#'
#' @param data Analysis results
#' @param hourly_baseline Hourly statistics
#' @param config Configuration list
#'
save_unforeseen_demand_reports <- function(data, hourly_baseline, config) {

  output_dir <- config$paths$output_reports

  # --- 1. Detailed events file ---
  events_cols <- c(
    "Date", "SP", "Hour",
    "Delta_ND", "Delta_TSD", "Delta_ENGLAND_WALES_DEMAND",
    "abs_freq_change", "trend", "category", "min_f", "max_f", "severity",
    "ND_damping", "TSD_damping", "ENGLAND_WALES_DEMAND_damping",
    "ND_unforeseen", "TSD_unforeseen", "ENGLAND_WALES_DEMAND_unforeseen",
    "is_unforeseen_ND", "is_unforeseen_TSD", "is_unforeseen_ENGLAND_WALES_DEMAND",
    "ND_event_severity", "TSD_event_severity", "ENGLAND_WALES_DEMAND_event_severity",
    "causality"
  )

  events_output <- data[, .SD, .SDcols = intersect(events_cols, names(data))]
  events_path <- file.path(output_dir, "unforeseen_demand_events.csv")
  fwrite(events_output, events_path)
  cat("  Saved detailed events to:", events_path, "\n")

  # --- 2. Monthly summary ---
  monthly_summary <- generate_monthly_summary(data)
  monthly_path <- file.path(output_dir, "unforeseen_demand_monthly.csv")
  fwrite(monthly_summary, monthly_path)
  cat("  Saved monthly summary to:", monthly_path, "\n")

  # --- 3. Hourly baseline ---
  baseline_path <- file.path(output_dir, "demand_damping_baseline.csv")
  fwrite(hourly_baseline, baseline_path)
  cat("  Saved hourly baseline to:", baseline_path, "\n")
}


#' Generate monthly summary statistics
#'
#' @param data Analysis results
#' @return data.table with monthly aggregates
#'
generate_monthly_summary <- function(data) {

  data[, month := floor_date(Date, "month")]

  summary_list <- list()

  for (metric in c("ND", "TSD", "ENGLAND_WALES_DEMAND")) {
    flag_col <- paste0("is_unforeseen_", metric)
    unforeseen_col <- paste0(metric, "_unforeseen")
    delta_col <- paste0("Delta_", metric)

    if (flag_col %in% names(data) && unforeseen_col %in% names(data)) {

      # Calculate pct_with_red_events only if category column exists
      if ("category" %in% names(data)) {
        monthly <- data[, .(
          metric = metric,
          total_events = sum(get(flag_col), na.rm = TRUE),
          max_unforeseen_mw = max(abs(get(unforeseen_col)), na.rm = TRUE),
          max_total_mw = max(abs(get(delta_col)), na.rm = TRUE),
          mean_unforeseen_mw = mean(abs(get(unforeseen_col)[get(flag_col)]), na.rm = TRUE),
          p95_unforeseen_mw = quantile(abs(get(unforeseen_col)[get(flag_col)]), 0.95, na.rm = TRUE),
          pct_with_red_events = sum(get(flag_col) & category == "Red", na.rm = TRUE) /
                                sum(get(flag_col), na.rm = TRUE) * 100
        ), by = month]
      } else {
        monthly <- data[, .(
          metric = metric,
          total_events = sum(get(flag_col), na.rm = TRUE),
          max_unforeseen_mw = max(abs(get(unforeseen_col)), na.rm = TRUE),
          max_total_mw = max(abs(get(delta_col)), na.rm = TRUE),
          mean_unforeseen_mw = mean(abs(get(unforeseen_col)[get(flag_col)]), na.rm = TRUE),
          p95_unforeseen_mw = quantile(abs(get(unforeseen_col)[get(flag_col)]), 0.95, na.rm = TRUE),
          pct_with_red_events = NA_real_
        ), by = month]
      }

      summary_list[[metric]] <- monthly
    }
  }

  summary <- rbindlist(summary_list, use.names = TRUE, fill = TRUE)
  setorder(summary, month, metric)

  return(summary)
}


#' Print executive summary to console
#'
#' @param data Analysis results
#' @param config Configuration list
#'
print_unforeseen_demand_summary <- function(data, config) {

  cat("\n========================================================\n")
  cat("  EXECUTIVE SUMMARY: UNFORESEEN DEMAND ANALYSIS\n")
  cat("========================================================\n\n")

  for (metric in c("ND", "TSD", "ENGLAND_WALES_DEMAND")) {
    flag_col <- paste0("is_unforeseen_", metric)
    unforeseen_col <- paste0(metric, "_unforeseen")
    damping_col <- paste0(metric, "_damping")

    if (flag_col %in% names(data)) {
      cat("--- ", metric, " ---\n", sep = "")

      n_total <- nrow(data)
      n_unforeseen <- sum(data[[flag_col]], na.rm = TRUE)
      pct_unforeseen <- n_unforeseen / n_total * 100

      cat("  Total SP boundaries analyzed:", n_total, "\n")
      cat("  Unforeseen events detected:", n_unforeseen,
          sprintf("(%.2f%%)\n", pct_unforeseen))

      if (n_unforeseen > 0) {
        unforeseen_vals <- data[get(flag_col) == TRUE, get(unforeseen_col)]
        cat("  Max unforeseen deviation:", sprintf("%.1f MW\n", max(abs(unforeseen_vals), na.rm = TRUE)))
        cat("  Mean unforeseen deviation:", sprintf("%.1f MW\n", mean(abs(unforeseen_vals), na.rm = TRUE)))
        cat("  95th percentile:", sprintf("%.1f MW\n", quantile(abs(unforeseen_vals), 0.95, na.rm = TRUE)))

        # Correlation with Red events
        if ("category" %in% names(data)) {
          n_red_unforeseen <- sum(data[[flag_col]] & data$category == "Red", na.rm = TRUE)
          pct_red <- n_red_unforeseen / n_unforeseen * 100
          cat("  Correlation with Red events:", n_red_unforeseen,
              sprintf("(%.1f%% of unforeseen)\n", pct_red))
        }
      }

      # Average damping observed
      if (damping_col %in% names(data)) {
        avg_damping <- mean(abs(data[[damping_col]]), na.rm = TRUE)
        cat("  Average damping component:", sprintf("%.1f MW\n", avg_damping))
      }

      cat("\n")
    }
  }

  # Causality breakdown
  if ("causality" %in% names(data)) {
    cat("--- CAUSALITY ASSESSMENT ---\n")
    causality_pct <- data[, .N, by = causality][, .(causality, N, pct = N / sum(N) * 100)]
    setorder(causality_pct, -pct)
    for (i in 1:nrow(causality_pct)) {
      cat("  ", causality_pct$causality[i], ": ",
          causality_pct$N[i], " (", sprintf("%.1f%%)\n", causality_pct$pct[i]), sep = "")
    }
    cat("\n")
  }

  cat("========================================================\n")
}
