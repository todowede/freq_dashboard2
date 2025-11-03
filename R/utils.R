# R/utils.R
# Purpose: General helper functions used across multiple modules.

# --- Dependencies ---
suppressPackageStartupMessages({
  library(lubridate)
})

#' Parses month-based config entries into a precise start and end date.
#'
#' This function takes the config object, reads the 'start_month' and 'end_month'
#' parameters, and calculates the first day of the start month and the *last*
#' day of the end month to create an inclusive date range.
#'
#' @param config The application configuration list.
#' @return A named list with 'start_date' and 'end_date' as Date objects.
#'
get_date_range_from_config <- function(config) {
  
  start_month_str <- config$parameters$start_month
  end_month_str <- config$parameters$end_month
  
  # Validate the format
  if (is.null(start_month_str) || is.null(end_month_str) || 
      !grepl("^\\d{4}-\\d{2}$", start_month_str) || 
      !grepl("^\\d{4}-\\d{2}$", end_month_str)) {
    stop("Configuration error: 'start_month' or 'end_month' is missing or not in YYYY-MM format.", call. = FALSE)
  }
  
  # Calculate the first day of the start month
  start_date <- ymd(paste0(start_month_str, "-01"))
  
  # Calculate the last day of the end month
  end_date <- ceiling_date(ymd(paste0(end_month_str, "-01")), "month") - days(1)
  
  if (is.na(start_date) || is.na(end_date) || start_date > end_date) {
    stop("Invalid date range calculated from start/end month. Please check config.yml.", call. = FALSE)
  }
  
  return(list(
    start_date = start_date,
    end_date = end_date
  ))
}