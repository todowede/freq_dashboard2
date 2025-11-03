# R/frequency_processor.R
# Purpose: Functions to process raw frequency data into an analysis-ready format.

# --- Dependencies ---
suppressPackageStartupMessages({
  library(data.table)
  library(lubridate)
})

#' Processes raw frequency data to a per-second series with ROCOF.
#'
#' This function takes the clean, raw frequency data.table, aggregates it to
#' find the mean frequency for each second, and then calculates the
#' Rate of Change of Frequency (ROCOF) between each one-second interval.
#'
#' @param raw_freq_dt A data.table containing the columns 'dtm' (POSIXct) and 'f' (numeric).
#' @param config The application configuration list (currently unused but included for future-proofing).
#'
#' @return A data.table with the columns 'dtm_sec', 'f', and 'rocof'.
#'
process_frequency_data <- function(raw_freq_dt, config) {
  
  # Robustness Check: Ensure input is a data.table and has data
  if (!is.data.table(raw_freq_dt) || nrow(raw_freq_dt) == 0) {
    cat("WARN: No frequency data provided to process. Skipping.\n")
    return(data.table(dtm_sec = as.POSIXct(character()), f = numeric(), rocof = numeric()))
  }
  
  # --- 1. Aggregate to Per-Second Frequency ---
  cat("INFO: Aggregating raw data to a per-second average frequency...\n")
  
  # Create a new column by flooring the timestamp to the second
  raw_freq_dt[, dtm_sec := floor_date(dtm, "second")]
  
  # Calculate the mean frequency for each second. data.table is highly efficient here.
  processed_dt <- raw_freq_dt[, .(f = mean(f, na.rm = TRUE)), by = dtm_sec]
  setorder(processed_dt, dtm_sec)
  
  cat("SUCCESS: Aggregated", format(nrow(raw_freq_dt), big.mark = ","), 
      "raw records into", format(nrow(processed_dt), big.mark = ","), "per-second records.\n")
  
  # --- 2. Calculate Rate of Change of Frequency (ROCOF) ---
  cat("INFO: Calculating per-second ROCOF...\n")
  
  # Use the shift() function to get the previous row's frequency and time
  processed_dt[, f_lag := shift(f, type = "lag")]
  processed_dt[, dtm_lag := shift(dtm_sec, type = "lag")]
  
  # Calculate the difference in time (in seconds) and frequency
  processed_dt[, dt_s := as.numeric(difftime(dtm_sec, dtm_lag, units = "secs"))]
  processed_dt[, df_hz := f - f_lag]
  
  # Calculate ROCOF, ensuring we only divide where dt_s > 0 to avoid Inf or NaN
  processed_dt[, rocof := fifelse(dt_s > 0, df_hz / dt_s, NA_real_)]
  
  # --- 3. Finalize and Return ---
  # Select only the required columns for the final analysis-ready dataset
  final_dt <- processed_dt[, .(dtm_sec, f, rocof)]
  
  # Save the processed data for auditing and potential reuse by other tools
  out_path <- file.path(config$paths$processed, "frequency_per_second_with_rocof.csv")
  cat("INFO: Saving processed data to:", out_path, "\n")
  fwrite(final_dt, out_path)
  
  cat("SUCCESS: Frequency processing complete.\n")
  return(final_dt)
}