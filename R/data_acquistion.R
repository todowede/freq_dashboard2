# R/data_acquistion.R
# Purpose: Functions for intelligently acquiring data from the NESO API.
# ** VERSION 1.1 - Corrected API response handling **

# --- Dependencies ---
suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
  library(lubridate)
})

#' Downloads NESO frequency data for a given date range if not already present.
#'
#' This function checks a local directory for the required monthly frequency
#' files. If any are missing, it connects to the NESO API, finds the correct
#' resource URL, and downloads the file.
#'
#' @param config A list containing the application configuration.
#' @return Invisibly returns TRUE on success.
#'
run_data_acquisition <- function(config) {
  
  # --- 1. Determine Required Files ---
  # **MODIFIED**: Use the new helper function to get the date range
  date_range <- get_date_range_from_config(config)
  start_date <- date_range$start_date
  end_date <- date_range$end_date
  
  # The rest of the logic works perfectly with the calculated dates
  required_months <- seq(start_date, end_date, by = "1 month")
  required_month_strs <- format(required_months, "%Y-%-m")
  required_files <- paste0("fnew-", required_month_strs, ".csv")
  
  cat("INFO: Required data files for date range:", paste(required_files, collapse = ", "), "\n")
  
  # --- 2. Fetch API Resource List ---
  api_url <- config$parameters$data_acquisition$api_url
  cat("INFO: Fetching available data list from NESO API...\n")
  response <- GET(api_url)
  
  if (http_error(response)) {
    stop("Failed to retrieve data from NESO API. Status: ", status_code(response), call. = FALSE)
  }
  
  content <- content(response, as = "text", encoding = "UTF-8")
  api_data <- fromJSON(content)
  
  # **FIXED**: The fromJSON function simplifies the API response into a data.frame.
  # We now handle this structure directly instead of assuming a list of lists.
  # This makes the code more robust to the API's output format.
  resources_df <- api_data$result$resources
  
  # The API might use 'url' or 'path' for the download link. We check for both.
  if ("url" %in% names(resources_df)) {
    resource_urls <- resources_df$url
  } else if ("path" %in% names(resources_df)) {
    resource_urls <- resources_df$path
  } else {
    stop("Could not find 'url' or 'path' in the API resource list.", call. = FALSE)
  }
  
  # --- 3. Check and Download Missing Files ---
  for (file_name in required_files) {
    destination_path <- file.path(config$paths$input, file_name)
    
    if (file.exists(destination_path)) {
      cat("INFO: File '", file_name, "' already exists. Skipping download.\n", sep = "")
    } else {
      cat("INFO: File '", file_name, "' is missing. Attempting to download...\n", sep = "")
      
      # Find the correct download URL from the resource list
      file_url <- resource_urls[grepl(file_name, resource_urls, fixed = TRUE)]
      
      if (length(file_url) == 1) {
        tryCatch({
          download.file(file_url, destfile = destination_path, mode = "wb", quiet = TRUE)
          cat("SUCCESS: Downloaded '", file_name, "' successfully.\n", sep = "")
        }, error = function(e) {
          cat("ERROR: Failed to download '", file_name, "'. Message: ", e$message, "\n", sep = "")
        })
      } else {
        cat("WARN: Could not find a unique download URL for '", file_name, "' on the API. Skipping.\n", sep = "")
      }
    }
  }
  
  return(invisible(TRUE))
}