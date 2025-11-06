# R/analysis_monthly_unforeseen_comparison.R
# Purpose: Calculate monthly comparison between total demand changes and unforeseen components
# This shows the deviation of unforeseen (market-driven) changes from total demand changes

# --- Dependencies ---
suppressPackageStartupMessages({
  library(data.table)
  library(lubridate)
})

# Helper function for null-coalescing
`%||%` <- function(x, y) if (is.null(x)) y else x


#' Main function to calculate monthly unforeseen vs total change comparison
#'
#' This function aggregates demand changes and unforeseen components by month
#' to show how much of the demand change is NOT explained by frequency damping.
#'
#' @param processed_freq_data Not used (kept for compatibility)
#' @param config The application configuration list
#'
#' @return A data.table containing monthly comparison statistics
#'
run_monthly_unforeseen_comparison <- function(processed_freq_data, config) {

  cat("\n============================================================\n")
  cat("INFO: Starting Monthly Unforeseen vs Total Change Comparison\n")
  cat("============================================================\n\n")

  # --- 1. Load Unforeseen Demand Data ---
  unforeseen_path <- file.path(config$paths$output_reports, "unforeseen_demand_events.csv")

  if (!file.exists(unforeseen_path)) {
    cat("ERROR: Unforeseen demand data not found at:", unforeseen_path, "\n")
    cat("NOTE: Run 'unforeseen_demand' step first to generate this data.\n")
    return(data.table())
  }

  cat("INFO: Loading unforeseen demand data from:", unforeseen_path, "\n")
  unforeseen_data <- fread(unforeseen_path)

  if (nrow(unforeseen_data) == 0) {
    cat("WARN: No unforeseen demand data available.\n")
    return(data.table())
  }

  cat("INFO: Loaded", nrow(unforeseen_data), "SP boundary records.\n\n")

  # --- 2. Parse dates and extract months ---
  unforeseen_data[, date := as.Date(Date)]
  unforeseen_data[, month := format(date, "%Y-%m")]

  # Calculate absolute values for all metrics
  for (metric in c("ND", "TSD", "ENGLAND_WALES_DEMAND")) {
    delta_col <- paste0("Delta_", metric)
    unforeseen_col <- paste0(metric, "_unforeseen")

    if (delta_col %in% names(unforeseen_data) && unforeseen_col %in% names(unforeseen_data)) {
      unforeseen_data[, paste0("abs_delta_", metric) := abs(get(delta_col))]
      unforeseen_data[, paste0("abs_unforeseen_", metric) := abs(get(unforeseen_col))]
    }
  }

  # --- 3. Aggregate by Month for Each Metric ---
  cat("INFO: Aggregating by month for each demand metric...\n")

  monthly_results <- list()

  for (metric in c("ND", "TSD", "ENGLAND_WALES_DEMAND")) {
    delta_col <- paste0("Delta_", metric)
    unforeseen_col <- paste0(metric, "_unforeseen")
    abs_delta_col <- paste0("abs_delta_", metric)
    abs_unforeseen_col <- paste0("abs_unforeseen_", metric)

    if (all(c(delta_col, unforeseen_col) %in% names(unforeseen_data))) {

      # Filter out NA values for this metric
      metric_data <- unforeseen_data[!is.na(get(delta_col)) & !is.na(get(unforeseen_col))]

      monthly_summary <- metric_data[, .(
        n_sp_boundaries = as.double(.N),

        # Total demand change statistics
        mean_total_change_mw = as.double(mean(get(abs_delta_col), na.rm = TRUE)),
        median_total_change_mw = as.double(median(get(abs_delta_col), na.rm = TRUE)),
        max_total_change_mw = as.double(max(get(abs_delta_col), na.rm = TRUE)),
        p95_total_change_mw = as.double(quantile(get(abs_delta_col), 0.95, na.rm = TRUE)),

        # Unforeseen component statistics
        mean_unforeseen_mw = as.double(mean(get(abs_unforeseen_col), na.rm = TRUE)),
        median_unforeseen_mw = as.double(median(get(abs_unforeseen_col), na.rm = TRUE)),
        max_unforeseen_mw = as.double(max(get(abs_unforeseen_col), na.rm = TRUE)),
        p95_unforeseen_mw = as.double(quantile(get(abs_unforeseen_col), 0.95, na.rm = TRUE)),

        # Deviation metrics
        mean_deviation_mw = as.double(mean(get(abs_unforeseen_col) - get(abs_delta_col), na.rm = TRUE)),
        unforeseen_ratio_pct = as.double(mean(get(abs_unforeseen_col) / ifelse(get(abs_delta_col) == 0, 1, get(abs_delta_col)), na.rm = TRUE) * 100)

      ), by = month]

      monthly_summary[, metric := metric]
      setcolorder(monthly_summary, c("month", "metric"))

      monthly_results[[metric]] <- monthly_summary

      cat("  -", metric, ":", nrow(monthly_summary), "months aggregated.\n")
    }
  }

  # Combine all metrics
  monthly_comparison <- rbindlist(monthly_results)
  setorder(monthly_comparison, metric, month)

  cat("  Total:", nrow(monthly_comparison), "monthly records across all metrics.\n")

  # --- 4. Save Results ---
  cat("\n============================================================\n")
  cat("INFO: Saving monthly unforeseen comparison results...\n")

  output_path <- file.path(config$paths$output_reports, "monthly_unforeseen_comparison.csv")
  fwrite(monthly_comparison, output_path)
  cat("SUCCESS: Saved monthly comparison to:", output_path, "\n")

  cat("\n============================================================\n")
  cat("SUCCESS: Monthly unforeseen comparison analysis complete!\n")
  cat("============================================================\n\n")

  return(monthly_comparison)
}
