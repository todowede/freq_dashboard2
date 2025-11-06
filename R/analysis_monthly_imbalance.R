# R/analysis_monthly_imbalance.R
# Purpose: Calculate continuous system imbalance from all frequency data (not just SP boundaries)
# and aggregate by month for trend analysis.

# --- Dependencies ---
suppressPackageStartupMessages({
  library(data.table)
  library(lubridate)
})

# Helper function for null-coalescing
`%||%` <- function(x, y) if (is.null(x)) y else x


#' Main function to calculate monthly imbalance statistics from EVENT data
#'
#' This function aggregates existing event-based imbalance calculations by month.
#' It uses the imbalance data from SP boundary events (not continuous calculation).
#'
#' @param processed_freq_data Not used (kept for compatibility)
#' @param config The application configuration list
#'
#' @return A data.table containing monthly imbalance statistics
#'
run_monthly_imbalance_analysis <- function(processed_freq_data, config) {

  cat("\n============================================================\n")
  cat("INFO: Starting Monthly Imbalance Analysis (from events)\n")
  cat("============================================================\n\n")

  # --- 1. Load Event-Based Imbalance Data ---
  imbalance_path <- file.path(config$paths$output_imbalance, "sp_boundary_imbalances.csv")

  if (!file.exists(imbalance_path)) {
    cat("ERROR: Event imbalance data not found at:", imbalance_path, "\n")
    cat("NOTE: Run 'imbalance_calculation' step first to generate event imbalance data.\n")
    return(data.table())
  }

  cat("INFO: Loading event imbalance data from:", imbalance_path, "\n")
  imbalance_data <- fread(imbalance_path)

  if (nrow(imbalance_data) == 0) {
    cat("WARN: No imbalance data available.\n")
    return(data.table())
  }

  cat("INFO: Loaded", nrow(imbalance_data), "seconds of event imbalance data.\n\n")

  # --- 2. Parse dates and extract months ---
  imbalance_data[, dtm := as.POSIXct(dtm_sec, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")]
  imbalance_data[, month := format(as.Date(dtm), "%Y-%m")]
  imbalance_data[, abs_imbalance_mw := abs(imbalance_mw)]

  # --- 3. Aggregate by Month ---
  cat("INFO: Aggregating imbalance by month...\n")

  monthly_summary <- imbalance_data[, .(
    n_seconds = .N,
    n_events = length(unique(event_id)),
    mean_imbalance_mw = mean(imbalance_mw, na.rm = TRUE),
    mean_abs_imbalance_mw = mean(abs_imbalance_mw, na.rm = TRUE),
    median_imbalance_mw = median(imbalance_mw, na.rm = TRUE),
    median_abs_imbalance_mw = median(abs_imbalance_mw, na.rm = TRUE),
    max_imbalance_mw = max(imbalance_mw, na.rm = TRUE),
    min_imbalance_mw = min(imbalance_mw, na.rm = TRUE),
    max_abs_imbalance_mw = max(abs_imbalance_mw, na.rm = TRUE),
    sd_imbalance_mw = sd(imbalance_mw, na.rm = TRUE),
    p95_abs_imbalance_mw = quantile(abs_imbalance_mw, 0.95, na.rm = TRUE),
    p99_abs_imbalance_mw = quantile(abs_imbalance_mw, 0.99, na.rm = TRUE)
  ), by = month]

  # Sort by month
  setorder(monthly_summary, month)

  cat("  Aggregated into", nrow(monthly_summary), "monthly summaries.\n")

  # --- 4. Save Results ---
  cat("\n============================================================\n")
  cat("INFO: Saving monthly imbalance results...\n")

  output_path <- file.path(config$paths$output_reports, "monthly_imbalance_summary.csv")
  fwrite(monthly_summary, output_path)
  cat("SUCCESS: Saved monthly summary to:", output_path, "\n")

  cat("\n============================================================\n")
  cat("SUCCESS: Monthly imbalance analysis complete!\n")
  cat("============================================================\n\n")

  return(monthly_summary)
}
