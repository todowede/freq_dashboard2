# R/analysis_response_holding.R
# Purpose: Functions to calculate system response holding per SP.

# --- Dependencies ---
suppressPackageStartupMessages({
  library(data.table)
  library(lubridate)
})

#' Calculates system response holding by combining MFR and EAC data.
#'
#' This function loads MFR and EAC data, processes both to a per-SP
#' granularity, joins them, and calculates the total low and high frequency
#' response holding (SysDyn_LP and SysDyn_H).
#'
#' @param config The application configuration list.
#'
#' @return A data.table containing the combined system dynamics review.
#'
run_response_holding <- function(config) {
  
  cat("INFO: Starting system response holding analysis...\n")
  input_dir <- config$paths$input
  
  # --- 1. Load and Process MFR Data ---
  mfr_files <- list.files(input_dir, pattern = "^MFR.*\\.csv$", full.names = TRUE)
  if (length(mfr_files) == 0) {
    cat("WARN: No MFR*.csv files found in", input_dir, ". Skipping analysis.\n")
    return(data.table())
  }
  
  cat("INFO: Loading", length(mfr_files), "MFR file(s)...\n")
  mfr_raw <- rbindlist(lapply(mfr_files, fread, showProgress = FALSE), use.names = TRUE, fill = TRUE)
  
  # The parse_robust_timestamp function is available as it was sourced by main.R
  mfr_raw[, dtm := parse_robust_timestamp(DATETIME_FROM, tz = "UTC")]
  mfr_raw <- mfr_raw[!is.na(dtm)]
  
  # Aggregate per-minute MFR data to per-SP averages
  mfr_agg <- mfr_raw[, .(
    P = mean(P_SYS5, na.rm = TRUE),
    S = mean(S_SYS5, na.rm = TRUE),
    H = mean(H_SYS5, na.rm = TRUE),
    Demand = mean(DEMAND, na.rm = TRUE)
  ), by = .(Date = as.Date(dtm), SP = hour(dtm) * 2L + (minute(dtm) %/% 30L) + 1L)]
  
  # --- 2. Load and Process EAC Data ---
  eac_path <- file.path(input_dir, "EAC_result.csv")
  if (!file.exists(eac_path)) {
    cat("WARN: EAC_result.csv not found in", input_dir, ". Proceeding without demand response data.\n")
    eac_expanded <- data.table(Date = as.Date(character()), SP = integer())
  } else {
    cat("INFO: Loading and processing EAC_result.csv...\n")
    eac_raw <- fread(eac_path)
    
    # Pivot from long to wide format
    eac_wide <- dcast(eac_raw, deliveryStart ~ auctionProduct, value.var = "clearedVolume", fill = 0)
    
    # Ensure all expected response type columns exist
    for (col in c("DRL","DRH","DML","DMH","DCL","DCH")) {
      if (!col %in% names(eac_wide)) eac_wide[, (col) := 0]
    }
    
    eac_wide[, deliveryStart := ymd_hms(deliveryStart, tz = "UTC")]

    # Remove rows where deliveryStart failed to parse
    eac_wide <- eac_wide[!is.na(deliveryStart)]

    if (nrow(eac_wide) == 0) {
      cat("WARN: No valid EAC delivery times after parsing. Proceeding without demand response data.\n")
      eac_expanded <- data.table(Date = as.Date(character()), SP = integer())
    } else {
      # Expand each 4-hour EFA block row into 8 separate 30-min SP rows
      eac_expanded <- eac_wide[, {
        start_date <- as.Date(deliveryStart)
        start_sp_index <- hour(deliveryStart) * 2L + minute(deliveryStart) %/% 30L
        .(
          base_date = start_date,
          sp_index = start_sp_index:(start_sp_index + 7L),
          DRL, DRH, DML, DMH, DCL, DCH
        )
      }, by = 1:nrow(eac_wide)]

      # Calculate the final Date and SP (1-48), handling midnight rollovers
      eac_expanded[, `:=`(
        Date = base_date + (sp_index %/% 48L),
        SP = (sp_index %% 48L) + 1L,
        base_date = NULL, # Drop temporary columns
        sp_index = NULL,
        nrow = NULL
      )]

      # Summarize in case multiple products cover the same SP
      eac_expanded <- eac_expanded[, lapply(.SD, sum, na.rm = TRUE), by = .(Date, SP)]
    }
  }
  
  # --- 3. Join MFR and EAC Data ---
  cat("INFO: Joining MFR and EAC data...\n")
  # Perform a left join to keep all MFR records
  full_data <- merge(mfr_agg, eac_expanded, by = c("Date", "SP"), all.x = TRUE)
  
  # Replace NAs in demand response columns with 0 after the join
  response_cols <- c("DRL","DRH","DML","DMH","DCL","DCH")
  for (col in response_cols) {
    if (col %in% names(full_data)) full_data[is.na(get(col)), (col) := 0]
  }
  
  # --- 4. Calculate System Dynamics and Finalize ---
  cat("INFO: Calculating final System Dynamics metrics...\n")
  
  # Use coalesce-like behavior to handle cases where columns might not exist
  safe_get <- function(dt, col_name) if (col_name %in% names(dt)) dt[[col_name]] else 0
  
  full_data[, `:=`(
    SysDyn_LP = safe_get(.SD, "P") + 1.67 * (safe_get(.SD, "DRL") + safe_get(.SD, "DML")),
    SysDyn_H  = safe_get(.SD, "H") + 1.67 * (safe_get(.SD, "DRH") + safe_get(.SD, "DMH"))
  )]
  
  setorder(full_data, Date, SP)
  
  # --- 5. Save Output ---
  out_path <- file.path(config$paths$output_reports, "system_dynamics_review.csv")
  cat("INFO: Saving response holding results to:", out_path, "\n")
  fwrite(full_data, out_path)
  
  cat("SUCCESS: Response holding analysis complete.\n")
  return(full_data)
}