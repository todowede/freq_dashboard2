# R/data_loader.R
# Purpose: Functions to robustly load and clean raw data from the input directory.
# ** VERSION 1.2 - Corrected a typo in the timestamp parsing call **

# --- Dependencies ---
suppressPackageStartupMessages({
  library(data.table)
  library(lubridate)
})


#' An enhanced, robust timestamp parser.
#'
#' @param time_vector A character vector of timestamps.
#' @param tz The timezone to apply (e.g., "Europe/London").
#' @return A POSIXct vector of parsed timestamps.
#'
parse_robust_timestamp <- function(time_vector, tz = "Europe/London") {
  time_vector <- trimws(as.character(time_vector))
  parsed_dates <- parse_date_time(
    time_vector,
    orders = c("Ymd HMS", "Ymd HM", "dmy HMS", "dmy HM"),
    tz = tz, quiet = TRUE
  )
  
  na_indices <- which(is.na(parsed_dates))
  if (length(na_indices) == 0) return(parsed_dates)
  
  # Fallback 1: UNIX epoch (seconds or milliseconds)
  numeric_vals <- suppressWarnings(as.numeric(time_vector[na_indices]))
  is_num <- !is.na(numeric_vals)
  if (any(is_num)) {
    num_idx <- na_indices[is_num]
    vals <- numeric_vals[is_num]
    is_ms <- vals > 1e11
    
    parsed_dates[num_idx[is_ms]] <- as.POSIXct(vals[is_ms] / 1000, origin = "1970-01-01", tz = tz)
    parsed_dates[num_idx[!is_ms]] <- as.POSIXct(vals[!is_ms], origin = "1970-01-01", tz = tz)
  }
  
  na_indices <- which(is.na(parsed_dates))
  if (length(na_indices) == 0) return(parsed_dates)
  
  # Fallback 2: Excel serial dates (days since 1899-12-30)
  numeric_vals <- suppressWarnings(as.numeric(time_vector[na_indices]))
  is_num <- !is.na(numeric_vals)
  if (any(is_num)) {
    excel_idx <- na_indices[is_num]
    vals <- numeric_vals[is_num]
    # Filter for plausible Excel date range (e.g., year > 2000)
    plausible_excel_dates <- vals > 36526 
    if(any(plausible_excel_dates)){
      excel_idx_plausible <- excel_idx[plausible_excel_dates]
      vals_plausible <- vals[plausible_excel_dates]
      parsed_dates[excel_idx_plausible] <- as.POSIXct(vals_plausible * 86400, origin = "1899-12-30", tz = tz)
    }
  }
  
  return(parsed_dates)
}


#' Loads and validates a single frequency data file with detailed logging.
#'
#' @param file_path The full path to the CSV file.
#' @param config The application configuration list.
#' @return A cleaned data.table for the single file.
#'
load_single_frequency_file <- function(file_path, config) {
  cat(paste0("Loading: ", basename(file_path), "\n"))
  
  verbose <- config$parameters$verbose_logging
  if (is.null(verbose)) {
    verbose <- FALSE
  }
  
  dt <- tryCatch({
    fread(file_path, showProgress = FALSE)
  }, error = function(e) {
    cat(paste0("  ❌ ERROR: Failed to read file. Message: ", e$message, "\n"))
    return(NULL)
  })
  
  if (is.null(dt) || nrow(dt) == 0) return(data.table())
  
  initial_count <- nrow(dt)
  if (verbose) cat(paste0("  Initial raw records: ", format(initial_count, big.mark = ","), "\n"))
  
  setnames(dt, tolower(trimws(names(dt))))
  time_col <- intersect(c("dtm", "datetime", "timestamp", "time"), names(dt))[1]
  freq_col <- intersect(c("f", "freq", "frequency", "hz"), names(dt))[1]
  
  if (is.na(time_col) || is.na(freq_col)) {
    cat("  ❌ ERROR: Missing required 'dtm' or 'f' columns. Skipping file.\n")
    return(data.table())
  }
  
  dt <- dt[, .SD, .SDcols = c(time_col, freq_col)]
  setnames(dt, c("dtm_str", "f_str"))
  
  # **FIXED**: Corrected typo to use `dtm_str` as the input for parsing.
  dt[, dtm := parse_robust_timestamp(dtm_str, tz = "Europe/London")]
  
  valid_timestamps <- dt[!is.na(dtm), .N]
  if (verbose) cat(paste0("  Valid timestamps: ", format(valid_timestamps, big.mark = ","), " (", round(100 * valid_timestamps / initial_count, 1), "%)\n"))
  dt <- dt[!is.na(dtm)]
  if(nrow(dt) == 0) return(data.table())
  
  dt[, f := suppressWarnings(as.numeric(f_str))]
  valid_freq <- dt[is.finite(f), .N]
  if (verbose) cat(paste0("  Valid frequencies: ", format(valid_freq, big.mark = ","), " (", round(100 * valid_freq / nrow(dt), 1), "%)\n"))
  dt <- dt[is.finite(f)]
  if(nrow(dt) == 0) return(data.table())
  
  plausible_range <- c(47, 52)
  outliers <- dt[f < plausible_range[1] | f > plausible_range[2], .N]
  if (outliers > 0) {
    if (verbose) cat(paste0("  Extreme outliers removed (<", plausible_range[1], " or >", plausible_range[2], " Hz): ", format(outliers, big.mark = ","), "\n"))
    dt <- dt[between(f, plausible_range[1], plausible_range[2])]
  }
  
  setorder(dt, dtm)
  pre_dedup_count <- nrow(dt)
  dt <- unique(dt, by = "dtm", fromLast = TRUE)
  duplicates_removed <- pre_dedup_count - nrow(dt)
  if (duplicates_removed > 0) {
    if (verbose) cat(paste0("  Duplicate timestamps removed: ", format(duplicates_removed, big.mark = ","), "\n"))
  }
  
  final_count <- nrow(dt)
  cat(paste0("  Final valid records: ", format(final_count, big.mark = ","), " (", round(100 * final_count / initial_count, 1), "% of original)\n\n"))
  
  return(dt[, .(dtm, f)])
}


#' Main data loading function called by the orchestrator.
#'
load_raw_data <- function(config) {
  
  cat("INFO: Starting robust data loading process...\n")
  input_dir <- config$paths$input
  
  # **MODIFIED**: Use the new helper function to get the date range
  date_range <- get_date_range_from_config(config)
  start_date <- date_range$start_date
  end_date <- date_range$end_date

  # Generate list of specific year-month combinations needed
  months_seq <- seq(floor_date(start_date, "month"), floor_date(end_date, "month"), by = "month")

  # Create patterns for both padded and unpadded months (e.g., "2025-5" and "2025-05")
  file_patterns <- character()
  for (ym in months_seq) {
    ym <- as.Date(ym, origin = "1970-01-01")  # Convert back to Date from numeric
    yr <- year(ym)
    mo <- month(ym)
    file_patterns <- c(file_patterns,
                      paste0("fnew-", yr, "-", mo, "\\.csv$"),          # unpadded
                      paste0("fnew-", yr, "-", sprintf("%02d", mo), "\\.csv$"))  # padded
  }

  all_freq_files <- list.files(input_dir, pattern = paste(file_patterns, collapse = "|"), full.names = TRUE)

  cat(paste0("INFO: Config date range: ", start_date, " to ", end_date, "\n"))
  cat(paste0("INFO: Found ", length(all_freq_files), " file(s) matching date range: ",
             paste(basename(all_freq_files), collapse = ", "), "\n"))

  if (length(all_freq_files) == 0) {
    cat("WARN: No frequency files found in", input_dir, "for the specified date range.\n")
    return(list(frequency = data.table()))
  }
  
  dt_list <- lapply(all_freq_files, load_single_frequency_file, config = config)
  frequency_data <- rbindlist(dt_list)
  
  if (nrow(frequency_data) > 0) {
    frequency_data <- frequency_data[between(as.Date(dtm), start_date, end_date)]
    setorder(frequency_data, dtm)
  }
  
  cat("-------------------------------------------------\n")
  cat("SUCCESS: Total valid frequency records loaded:", format(nrow(frequency_data), big.mark = ","), "\n")
  
  return(
    list(
      frequency = frequency_data
    )
  )
}