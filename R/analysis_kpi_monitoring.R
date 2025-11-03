# R/analysis_kpi_monitoring.R
# Purpose: Functions for continuous frequency quality KPI monitoring.

# --- Dependencies ---
suppressPackageStartupMessages({
  library(data.table)
  library(lubridate)
})

#' Performs incremental, second-by-second frequency KPI classification.
#'
#' This function classifies every second of data into categories (Red, Amber,
#' Blue, Green) based on thresholds. It aggregates these into percentages per SP
#' and intelligently appends only new days' data to the output file.
#'
#' @param processed_data A data.table from `frequency_processor`.
#' @param config The application configuration list.
#'
#' @return A data.table containing the newly processed daily percentages.
#'
run_kpi_monitoring <- function(processed_data, config) {
  
  # --- 1. Get Parameters and Set Up Paths ---
  cat("INFO: Starting incremental KPI monitoring analysis...\n")
  
  params <- config$parameters$kpi_monitoring
  out_path <- file.path(config$paths$output_reports, "sp_category_percentages.csv")
  
  # **NEW**: Add validation checks for required config parameters
  required_params <- c("rocof_ref_hz_s", "freq_dev_red", "freq_dev_amber", "freq_dev_blue")
  if (is.null(params) || !all(required_params %in% names(params))) {
    stop("Configuration error: 'kpi_monitoring' section or one of its required keys is missing in config.yml.", call. = FALSE)
  }
  
  # --- 2. Determine Date Range for Incremental Processing ---
  start_date_to_process <- as.Date(min(processed_data$dtm_sec))
  
  if (file.exists(out_path)) {
    tryCatch({
      # Read only the 'date' column of the existing file to find the last entry
      existing_dates <- fread(out_path, select = "date", showProgress = FALSE)
      if (nrow(existing_dates) > 0) {
        last_date_processed <- max(as.Date(existing_dates$date))
        start_date_to_process <- last_date_processed + 1
      }
    }, error = function(e) {
      cat("WARN: Could not read existing KPI file at", out_path, ". Reprocessing all data.\n")
    })
  }
  
  # Filter the main dataset to only new data
  data_to_process <- processed_data[as.Date(dtm_sec) >= start_date_to_process]
  
  if (nrow(data_to_process) == 0) {
    cat("INFO: No new data to process since", as.character(start_date_to_process - 1), ". Skipping.\n")
    return(data.table())
  }
  
  cat("INFO: Processing new data from", as.character(start_date_to_process), "onwards.\n")
  
  # --- 3. Per-Second Classification ---
  data_to_process[, freq_dev := abs(f - 50)]
  
  # Use data.table::fcase for highly efficient conditional classification
  data_to_process[, category := fcase(
    is.na(rocof) | is.na(freq_dev),                              "Unknown",
    abs(rocof) > params$rocof_ref_hz_s | freq_dev > params$freq_dev_red, "Red",
    freq_dev > params$freq_dev_amber,                           "Amber",
    freq_dev > params$freq_dev_blue,                            "Blue",
    default = "Green"
  )]
  
  # --- 4. Aggregate by Settlement Period ---
  data_to_process[, `:=`(
    date = as.Date(dtm_sec),
    sp = hour(dtm_sec) * 2L + (minute(dtm_sec) %/% 30L) + 1L
  )]
  
  # Count the number of seconds in each category for each SP
  sp_counts <- data_to_process[category != "Unknown", .N, by = .(date, sp, category)]
  
  # --- 5. Pivot to Wide Format and Calculate Percentages ---
  sp_wide <- dcast(sp_counts, date + sp ~ category, value.var = "N", fill = 0)
  
  # Ensure all category columns exist, even if none were found
  for (cat_col in c("Red", "Amber", "Blue", "Green")) {
    if (!cat_col %in% names(sp_wide)) {
      sp_wide[, (cat_col) := 0L]
    }
  }
  
  sp_wide[, total := Red + Amber + Blue + Green]
  
  sp_wide[, `:=`(
    pct_red = round(100 * Red / total, 3),
    pct_amber = round(100 * Amber / total, 3),
    pct_blue = round(100 * Blue / total, 3),
    pct_green = round(100 * Green / total, 3)
  )]
  
  # --- 6. Format and Save Output (Append) ---
  output_dt <- sp_wide[order(date, sp), .(
    date,
    settlement_period = sp,
    percentage_red = pct_red,
    percentage_amber = pct_amber,
    percentage_blue = pct_blue,
    percentage_green = pct_green
  )]
  
  # The append=TRUE flag is key to the incremental logic.
  # col.names=!file.exists() writes the header only on the first run.
  cat("INFO: Appending", nrow(output_dt), "rows to:", out_path, "\n")
  fwrite(output_dt, out_path, append = TRUE, col.names = !file.exists(out_path))
  
  cat("SUCCESS: KPI monitoring analysis complete.\n")
  return(output_dt)
}