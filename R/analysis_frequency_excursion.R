# R/analysis_frequency_excursion.R
# Purpose: Analyze frequency excursions at multiple deviation thresholds
#
# Tracks excursions at: 0.1, 0.12, 0.14, 0.16, 0.18, 0.2 Hz from 50 Hz
# Separates High (>50 Hz) and Low (<50 Hz) excursions

# --- Dependencies ---
suppressPackageStartupMessages({
  library(data.table)
  library(lubridate)
})


#' Runs frequency excursion analysis on per-second frequency data
#'
#' This function reads processed frequency data, calculates deviations from 50 Hz,
#' detects excursions at multiple thresholds, and generates summary statistics.
#'
#' @param freq_data A data.table with columns: dtm_sec, f, rocof
#' @param config The application configuration list
#' @return Invisibly returns TRUE on success
#'
run_frequency_excursion_analysis <- function(freq_data, config) {
  cat("INFO: Starting frequency excursion analysis...\n")

  # --- 1. Calculate Deviations ---
  freq_data[, deviation := abs(f - 50)]
  freq_data[, date := as.Date(dtm_sec)]
  freq_data[, month := floor_date(as.Date(dtm_sec), "month")]

  # Define thresholds
  thresholds <- c(0.1, 0.15, 0.2)

  cat("INFO: Analyzing excursions at thresholds:", paste(thresholds, collapse = ", "), "Hz\n")

  # --- 2. Detect Excursions for Each Threshold ---
  excursion_results <- list()

  for (threshold in thresholds) {
    cat("INFO: Processing threshold", threshold, "Hz...\n")

    # Mark points exceeding threshold
    freq_data[, exceeds := deviation >= threshold]

    # Create excursion groups (combined High and Low)
    freq_data[, excursion_id := cumsum(c(1, diff(exceeds) != 0))]
    freq_data[, is_excursion := exceeds == TRUE]

    # Calculate excursion statistics
    excursions <- freq_data[is_excursion == TRUE, .(
      start_time = min(dtm_sec),
      end_time = max(dtm_sec),
      duration_sec = .N,
      max_deviation = max(deviation),
      avg_frequency = mean(f)
    ), by = .(excursion_id, date, month)]

    if (nrow(excursions) > 0) {
      excursions[, threshold := threshold]
      excursion_results[[paste0("t", threshold*100)]] <- excursions
    }
  }

  # Combine all excursion results
  all_excursions <- rbindlist(excursion_results, fill = TRUE)

  # --- 3. Generate Summary Statistics ---

  # Overall summary by threshold
  summary_overall <- all_excursions[, .(
    num_excursions = .N,
    total_duration_sec = sum(duration_sec),
    avg_duration_sec = mean(duration_sec),
    max_duration_sec = max(duration_sec),
    max_deviation_hz = max(max_deviation)
  ), by = .(threshold)]

  setorder(summary_overall, threshold)

  # Daily summary
  summary_daily <- all_excursions[, .(
    num_excursions = .N,
    total_duration_sec = sum(duration_sec),
    avg_duration_sec = mean(duration_sec)
  ), by = .(date, threshold)]

  setorder(summary_daily, date, threshold)

  # Monthly summary (for backwards compatibility)
  summary_monthly <- all_excursions[, .(
    num_excursions = .N,
    total_duration_sec = sum(duration_sec),
    avg_duration_sec = mean(duration_sec)
  ), by = .(month, threshold)]

  setorder(summary_monthly, month, threshold)

  # --- 4. Calculate Percentage Time in Each Frequency State ---

  # Total seconds in dataset
  total_seconds <- nrow(freq_data)

  # Count seconds in each frequency zone (no direction separation)
  freq_zones <- data.table(
    zone = c("0-0.1", "0.1-0.15", "0.15-0.2", "0.2+"),
    lower = c(0, 0.1, 0.15, 0.2),
    upper = c(0.1, 0.15, 0.2, Inf)
  )

  state_percentages <- rbindlist(lapply(1:nrow(freq_zones), function(i) {
    zone_name <- freq_zones$zone[i]
    lower <- freq_zones$lower[i]
    upper <- freq_zones$upper[i]

    # Count all excursions in this zone
    count <- freq_data[deviation >= lower & deviation < upper, .N]

    data.table(
      zone = zone_name,
      count = count,
      percentage = (count / total_seconds) * 100
    )
  }))

  # Monthly state percentages
  monthly_state_percentages <- rbindlist(lapply(unique(freq_data$month), function(m) {
    month_data <- freq_data[month == m]
    month_total <- nrow(month_data)

    rbindlist(lapply(1:nrow(freq_zones), function(i) {
      zone_name <- freq_zones$zone[i]
      lower <- freq_zones$lower[i]
      upper <- freq_zones$upper[i]

      count <- month_data[deviation >= lower & deviation < upper, .N]

      data.table(
        month = m,
        zone = zone_name,
        count = count,
        percentage = (count / month_total) * 100
      )
    }))
  }))

  # --- 5. Save Outputs ---
  output_dir <- config$paths$output_reports

  cat("INFO: Saving frequency excursion summary...\n")
  fwrite(summary_overall, file.path(output_dir, "frequency_excursion_summary.csv"))

  cat("INFO: Saving daily excursion summary...\n")
  fwrite(summary_daily, file.path(output_dir, "frequency_excursion_daily.csv"))

  cat("INFO: Saving monthly excursion summary...\n")
  fwrite(summary_monthly, file.path(output_dir, "frequency_excursion_monthly.csv"))

  cat("INFO: Saving frequency state percentages...\n")
  fwrite(state_percentages, file.path(output_dir, "frequency_state_percentages.csv"))

  cat("INFO: Saving monthly state percentages...\n")
  fwrite(monthly_state_percentages, file.path(output_dir, "frequency_state_percentages_monthly.csv"))

  cat("SUCCESS: Frequency excursion analysis complete.\n")
  cat("  - Total excursions detected:", nrow(all_excursions), "\n")
  cat("  - Thresholds analyzed:", paste(thresholds, collapse = ", "), "Hz\n")
  cat("  - Date range:", format(min(freq_data$date), "%Y-%m-%d"), "to", format(max(freq_data$date), "%Y-%m-%d"), "\n")

  return(invisible(TRUE))
}
