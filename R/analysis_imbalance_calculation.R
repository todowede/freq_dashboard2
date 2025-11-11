# R/analysis_imbalance_calculation.R
# Purpose: Inverse calculation of system imbalance from frequency deviations at SP boundaries.
#
# This module performs the "reverse engineering" of frequency changes to quantify the
# MW imbalance (e.g., battery switching) that caused the frequency deviation.
#
# Mathematical foundation:
# At any moment, system balance requires:
#   Generation + Response = Demand + Demand_Damping
#
# Imbalance (what we want to find):
#   Imb = Generation_base - Demand_base
#   Imb = -LF_response + Demand_damping + HF_response + RoCoF_component
#
# Where:
#   - LF_response: Low frequency response (Primary, Secondary, High, DR, DM)
#   - Demand_damping: Natural demand change due to frequency (2.5% per Hz)
#   - HF_response: High frequency response (for f > 50 Hz)
#   - RoCoF_component: Imbalance from rate of change (2H * df/dt)

# --- Dependencies ---
suppressPackageStartupMessages({
  library(data.table)
  library(lubridate)
  library(ggplot2)
})

# Helper function for null-coalescing
`%||%` <- function(x, y) if (is.null(x)) y else x


#' Main function to calculate imbalance from frequency events
#'
#' This function orchestrates the inverse imbalance calculation by:
#' 1. Loading event data and identifying which events to analyze
#' 2. Loading system condition data (inertia, demand, response holdings)
#' 3. For each event, calculating second-by-second imbalance
#' 4. Optionally validating results by forward simulation
#' 5. Saving results and generating plots
#'
#' @param processed_freq_data A data.table with per-second frequency and ROCOF data
#' @param event_results A data.table from event_detection with classified SP boundary events
#' @param config The application configuration list
#'
#' @return A data.table containing imbalance calculations for all analyzed events
#'
run_imbalance_calculation <- function(processed_freq_data, event_results, config) {

  cat("\n============================================================\n")
  cat("INFO: Starting Inverse Imbalance Calculation Module\n")
  cat("============================================================\n\n")

  # --- 1. Validate Inputs ---
  params <- config$parameters$imbalance_calculation
  if (is.null(params)) {
    stop("Configuration error: 'imbalance_calculation' section missing in config.yml", call. = FALSE)
  }

  if (!is.data.table(processed_freq_data) || nrow(processed_freq_data) == 0) {
    cat("WARN: No frequency data provided. Skipping imbalance calculation.\n")
    return(data.table())
  }

  if (!is.data.table(event_results) || nrow(event_results) == 0) {
    cat("WARN: No event data provided. Skipping imbalance calculation.\n")
    return(data.table())
  }

  # --- 2. Select Events to Analyze ---
  events_to_analyze <- select_events_for_analysis(event_results, params)

  if (nrow(events_to_analyze) == 0) {
    cat("WARN: No events selected for imbalance calculation.\n")
    return(data.table())
  }

  cat("INFO: Selected", nrow(events_to_analyze), "events for imbalance analysis.\n\n")

  # --- 3. Load System Condition Data ---
  cat("INFO: Loading system condition data...\n")
  system_data <- load_system_data(params, config)

  if (is.null(system_data)) {
    cat("ERROR: Failed to load system data. Cannot proceed with imbalance calculation.\n")
    cat("NOTE: This module requires external data files. See documentation for data requirements.\n")
    return(data.table())
  }

  # --- 4. Calculate Imbalance for Each Event ---
  cat("\nINFO: Calculating imbalance for", nrow(events_to_analyze), "events...\n")

  all_imbalances <- list()

  for (i in seq_len(nrow(events_to_analyze))) {
    event <- events_to_analyze[i]

    cat("\n--- Event", i, "of", nrow(events_to_analyze),
        ":", format(as.POSIXct(event$boundary_time), "%Y-%m-%d %H:%M"),
        "(SP", event$starting_sp, ") ---\n")

    # Calculate imbalance for this event
    event_imbalance <- calculate_event_imbalance(
      event = event,
      freq_data = processed_freq_data,
      system_data = system_data,
      params = params,
      config = config
    )

    if (!is.null(event_imbalance) && nrow(event_imbalance) > 0) {
      all_imbalances[[i]] <- event_imbalance
    }
  }

  # --- 5. Combine Results ---
  if (length(all_imbalances) == 0) {
    cat("\nWARN: No imbalance calculations completed successfully.\n")
    return(data.table())
  }

  combined_results <- rbindlist(all_imbalances, fill = TRUE)

  # --- 6. Save Results ---
  cat("\n============================================================\n")
  cat("INFO: Saving imbalance calculation results...\n")

  output_path <- file.path(config$paths$output_imbalance, "sp_boundary_imbalances.csv")
  fwrite(combined_results, output_path)
  cat("SUCCESS: Saved detailed results to:", output_path, "\n")

  # Save summary statistics
  summary_results <- create_summary_statistics(combined_results, events_to_analyze)
  summary_path <- file.path(config$paths$output_imbalance, "imbalance_summary.csv")
  fwrite(summary_results, summary_path)
  cat("SUCCESS: Saved summary statistics to:", summary_path, "\n")

  # Update event detection output with imbalance metric for every SP
  event_path <- file.path(config$paths$output_reports, "sp_boundary_events.csv")
  if (file.exists(event_path)) {
    cat("INFO: Updating SP boundary events with imbalance estimates...\n")
    events_dt <- fread(event_path)
    # Preserve original ordering for later restoration
    if ("imbalance_mw" %in% names(events_dt)) {
      events_dt[, imbalance_mw := NULL]
    }

    events_dt[, boundary_time_dt := as.POSIXct(boundary_time, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")]
    if (any(is.na(events_dt$boundary_time_dt))) {
      events_dt[, boundary_time_dt := as.POSIXct(boundary_time, tz = "UTC")]
    }

    imbalance_join <- summary_results[, .(
      boundary_time,
      starting_sp,
      imbalance_mw = round(boundary_imbalance_mw, 1)
    )]

    events_dt <- merge(
      events_dt,
      imbalance_join,
      by.x = c("starting_sp", "boundary_time_dt"),
      by.y = c("starting_sp", "boundary_time"),
      all.x = TRUE,
      sort = FALSE
    )

    events_dt[, boundary_time := format(boundary_time_dt, "%Y-%m-%dT%H:%M:%SZ")]
    events_dt[, boundary_time_dt := NULL]

    standard_order <- c(
      "date", "starting_sp", "boundary_time",
      "min_f", "max_f", "abs_freq_change", "rocof_p99",
      "trend", "event_timing", "category", "category_old",
      "severity", "imbalance_mw"
    )
    remaining_cols <- setdiff(names(events_dt), standard_order)
    setcolorder(events_dt, c(intersect(standard_order, names(events_dt)), remaining_cols))

    fwrite(events_dt, event_path)
    missing_imbalance <- events_dt[is.na(imbalance_mw), .N]
    if (missing_imbalance > 0) {
      cat("WARN:", missing_imbalance, "SP boundaries do not have imbalance estimates (check event selection settings).\n")
    }
    cat("SUCCESS: sp_boundary_events.csv updated with imbalance_mw column.\n")
  } else {
    cat("WARN: Event detection output not found; skipping imbalance column update.\n")
  }

  cat("\n============================================================\n")
  cat("SUCCESS: Imbalance calculation complete!\n")
  cat("============================================================\n\n")

  return(combined_results)
}


#' Selects which events to analyze based on configuration
#'
#' @param event_results A data.table of detected events
#' @param params The imbalance_calculation configuration parameters
#' @return A data.table of events to analyze
#'
select_events_for_analysis <- function(event_results, params) {

  calculate_red_only <- params$calculate_for_red_events_only %||% FALSE

  if (calculate_red_only) {
    cat("INFO: Filtering for Red events only (as per configuration)...\n")
    selected <- event_results[category == "Red"]
    cat("INFO: Found", nrow(selected), "Red events out of", nrow(event_results), "total events.\n")
  } else {
    cat("INFO: Analyzing all events (Red and Green)...\n")
    selected <- copy(event_results)
  }

  # Sort by severity (descending) to prioritize most significant events
  if ("severity" %in% names(selected)) {
    setorder(selected, -severity)
  } else {
    setorder(selected, -abs_freq_change)
  }

  # Apply additional selection rules from configuration
  selection_cfg <- params$event_selection %||% list()
  mode <- tolower(selection_cfg$mode %||% "all")

  # Apply severity threshold if requested and data available
  if (mode %in% c("severity_filter", "combined")) {
    min_severity <- selection_cfg$min_severity
    if (!is.null(min_severity)) {
      if ("severity" %in% names(selected)) {
        before_count <- nrow(selected)
        selected <- selected[severity >= min_severity]
        cat("INFO: Applied severity filter (>=", min_severity, ") -", before_count, "->", nrow(selected), "events.\n")
      } else {
        cat("WARN: Severity filter requested but 'severity' column missing; skipping filter.\n")
      }
    }
  }

  # Apply top-N cap if requested
  if (mode %in% c("top_n", "combined")) {
    max_events <- as.integer(selection_cfg$max_events %||% 0)
    if (!is.na(max_events) && max_events > 0 && nrow(selected) > max_events) {
      cat("INFO: Capping events to top", max_events, "based on configuration.\n")
      selected <- selected[seq_len(max_events)]
    }
  }

  return(selected)
}


#' Loads system condition data from configured sources
#'
#' @param params The imbalance_calculation configuration parameters
#' @param config The full application configuration
#' @return A list containing inertia, demand, and response data, or NULL if loading fails
#'
load_system_data <- function(params, config) {

  system_data_config <- params$system_data

  if (is.null(system_data_config)) {
    cat("ERROR: 'system_data' configuration is missing.\n")
    return(NULL)
  }

  # Initialize system data list
  system_data <- list()

  # --- Load Inertia Data ---
  inertia_path <- system_data_config$inertia_source
  if (!is.null(inertia_path) && file.exists(inertia_path)) {
    cat("  Loading inertia data from:", inertia_path, "\n")
    system_data$inertia <- tryCatch({
      dt <- fread(inertia_path)
      # Convert Settlement Date + Settlement Period to timestamp
      if ("Settlement Date" %in% names(dt) && "Settlement Period" %in% names(dt)) {
        dt[, timestamp := as.POSIXct(`Settlement Date`, format = "%Y-%m-%d") +
                         (as.numeric(`Settlement Period`) - 1) * 1800]
        # Use "Outturn Inertia" as the inertia value
        if ("Outturn Inertia" %in% names(dt)) {
          dt[, inertia_gvas := as.numeric(`Outturn Inertia`)]
        }
        dt[, .(timestamp, inertia_gvas)]
      } else {
        cat("WARN: Expected columns not found in inertia file\n")
        NULL
      }
    }, error = function(e) {
      cat("ERROR: Failed to load inertia data:", e$message, "\n")
      NULL
    })
  } else {
    cat("WARN: Inertia data file not found:", inertia_path, "\n")
    cat("NOTE: Using default inertia value of 150 GVA·s\n")
    system_data$inertia <- data.table(
      timestamp = as.POSIXct(character()),
      inertia_gvas = numeric()
    )
    system_data$default_inertia <- 150  # Default value
  }

  # --- Load Demand Data ---
  demand_path <- system_data_config$demand_source
  if (!is.null(demand_path) && file.exists(demand_path)) {
    cat("  Loading demand data from:", demand_path, "\n")
    system_data$demand <- tryCatch({
      dt <- fread(demand_path)
      # Convert SETTLEMENT_DATE + SETTLEMENT_PERIOD to timestamp
      if ("SETTLEMENT_DATE" %in% names(dt) && "SETTLEMENT_PERIOD" %in% names(dt)) {
        # Try multiple date formats (file has mixed formats: "01-JAN-2024" and "2025-05-01")
        dt[, date_parsed := as.POSIXct(SETTLEMENT_DATE, format = "%d-%b-%Y")]
        dt[is.na(date_parsed), date_parsed := as.POSIXct(SETTLEMENT_DATE, format = "%Y-%m-%d")]
        dt[, timestamp := date_parsed + (as.numeric(SETTLEMENT_PERIOD) - 1) * 1800]
        dt[, date_parsed := NULL]  # Remove temporary column
        # Use "ND" (National Demand) as the demand value
        if ("ND" %in% names(dt)) {
          dt[, demand_mw := as.numeric(ND)]
        }
        dt[, .(timestamp, demand_mw)]
      } else {
        cat("WARN: Expected columns not found in demand file\n")
        NULL
      }
    }, error = function(e) {
      cat("ERROR: Failed to load demand data:", e$message, "\n")
      NULL
    })
  } else{
    cat("WARN: Demand data file not found:", demand_path, "\n")
    cat("NOTE: Using default demand value of 35000 MW\n")
    system_data$demand <- data.table(
      timestamp = as.POSIXct(character()),
      demand_mw = numeric()
    )
    system_data$default_demand <- 35000  # Default value
  }

  # --- Load Response Holdings Data ---
  response_path <- system_data_config$response_source
  if (!is.null(response_path) && file.exists(response_path)) {
    cat("  Loading response holdings from:", response_path, "\n")
    system_data$response <- tryCatch({
      dt <- fread(response_path)
      # Convert Date + SP to timestamp
      if ("Date" %in% names(dt) && "SP" %in% names(dt)) {
        dt[, timestamp := as.POSIXct(Date) + (as.numeric(SP) - 1) * 1800]
      }
      dt
    }, error = function(e) {
      cat("ERROR: Failed to load response data:", e$message, "\n")
      NULL
    })
  } else {
    cat("WARN: Response holdings data file not found:", response_path, "\n")
    cat("NOTE: Using default response holding values\n")
    system_data$response <- data.table(
      timestamp = as.POSIXct(character()),
      primary_mw = numeric(),
      secondary_mw = numeric(),
      high_mw = numeric(),
      dr_mw = numeric(),
      dm_mw = numeric(),
      dc_mw = numeric()
    )
    # Default values (approximate typical holdings)
    system_data$default_response <- list(
      primary_mw = 500,
      secondary_mw = 300,
      high_mw = 200,
      dr_mw = 300,
      dm_mw = 400,
      dc_mw = 500
    )
  }

  cat("INFO: System data loading complete.\n")

  # Print diagnostic information
  cat("  Inertia data: ",nrow(system_data$inertia), "rows loaded\n")
  if (nrow(system_data$inertia) > 0) {
    cat("    Date range:", format(min(system_data$inertia$timestamp), "%Y-%m-%d"), "to",
        format(max(system_data$inertia$timestamp), "%Y-%m-%d"), "\n")
  }
  cat("  Demand data: ", nrow(system_data$demand), "rows loaded\n")
  if (nrow(system_data$demand) > 0) {
    cat("    Date range:", format(min(system_data$demand$timestamp), "%Y-%m-%d"), "to",
        format(max(system_data$demand$timestamp), "%Y-%m-%d"), "\n")
  }

  return(system_data)
}


#' Calculates second-by-second imbalance for a single event
#'
#' This is the core inverse calculation function that implements the mathematical model:
#'   Imb(t) = -LF_response(t) + Demand_damping(t) + HF_response(t) + RoCoF_component(t)
#'
#' @param event A single row data.table containing event information
#' @param freq_data The processed frequency data
#' @param system_data List containing system condition data
#' @param params The imbalance_calculation configuration parameters
#' @param config The full application configuration
#' @return A data.table with second-by-second imbalance calculations
#'
calculate_event_imbalance <- function(event, freq_data, system_data, params, config) {

  # --- 1. Extract Window Data ---
  window_sec <- params$window_seconds %||% 120
  # Legacy behaviour (tight ±event-detection window). Uncomment to revert:
  # window_sec <- config$parameters$event_detection$window_seconds %||% window_sec
  boundary_time <- as.POSIXct(event$boundary_time)

  window_start <- boundary_time - seconds(window_sec)
  window_end <- boundary_time + seconds(window_sec)

  window_data <- freq_data[dtm_sec >= window_start & dtm_sec <= window_end]

  if (nrow(window_data) < 2) {
    cat("WARN: Insufficient frequency data for this event window.\n")
    return(NULL)
  }

  cat("  Extracted", nrow(window_data), "seconds of frequency data.\n")

  # --- 2. Get System Conditions for this Event ---
  nominal_freq <- params$nominal_frequency_hz %||% 50.0
  demand_damping_pct <- params$demand_damping_percent_per_hz %||% 2.5

  # Get inertia (GVA·s)
  inertia <- get_system_parameter(boundary_time, system_data$inertia,
                                  "inertia_gvas", system_data$default_inertia %||% 150)

  # Get demand (MW)
  demand <- get_system_parameter(boundary_time, system_data$demand,
                                 "demand_mw", system_data$default_demand %||% 35000)

  # Get response holdings (MW)
  response_holdings <- get_response_holdings(boundary_time, system_data, params)

  cat("  System conditions: Inertia =", round(inertia, 1), "GVA·s, Demand =",
      round(demand, 0), "MW\n")

  # --- 3. Calculate Imbalance Components Second-by-Second ---
  window_data[, `:=`(
    # Frequency deviation from nominal
    df_hz = f - nominal_freq,

    # Time in seconds relative to boundary
    time_rel_s = as.numeric(difftime(dtm_sec, boundary_time, units = "secs"))
  )]

  # Calculate Low Frequency Response (activated when f < 50 Hz)
  # When frequency drops, response services ADD generation
  # Response is proportional to frequency deviation
  window_data[, lf_response_mw := fifelse(
    df_hz < -0.015,  # Below deadband
    abs(df_hz) * (response_holdings$primary_mw + response_holdings$secondary_mw +
              response_holdings$dr_mw + response_holdings$dm_mw + response_holdings$dc_mw) / 0.5,
    0
  )]

  # Calculate High Frequency Response (activated when f > 50 Hz)
  # When frequency rises, high frequency response acts like load
  window_data[, hf_response_mw := fifelse(
    df_hz > 0.015,  # Above deadband
    df_hz * response_holdings$high_mw / 0.2,
    0
  )]

  # Calculate Demand Damping
  # Natural demand change = Base_demand * (demand_damping_pct / 100) * Δf
  # When f < 50 Hz (df < 0), demand reduces (negative value), which helps like adding generation
  window_data[, demand_damping_mw := demand * (demand_damping_pct / 100) * df_hz]

  # Calculate RoCoF Component
  # This represents the imbalance needed to change frequency at the observed rate
  # Imb_rocof = (2H / f_nominal) * RoCoF * 1000
  # GVA·s * (Hz/s) * 1000 = GW * 1000 = MW
  window_data[, rocof_component_mw := (2 * inertia / nominal_freq) * rocof * 1000]

  # Replace NA values in rocof_component with 0
  window_data[is.na(rocof_component_mw), rocof_component_mw := 0]

  # --- 4. Calculate Total Imbalance ---
  # At any moment: Imbalance + Response = Demand_change + RoCoF_effect
  # Solving for Imbalance:
  # Imb = -LF_response + Demand_damping + HF_response + RoCoF_component
  # (LF_response is positive when helping, so we subtract it to get the original imbalance)
  window_data[, imbalance_mw := -lf_response_mw + hf_response_mw + demand_damping_mw + rocof_component_mw]

  # --- 5. Add Event Metadata ---
  window_data[, `:=`(
    event_id = paste0(format(boundary_time, "%Y%m%d_%H%M"), "_SP", event$starting_sp),
    boundary_time = boundary_time,
    starting_sp = event$starting_sp,
    event_category = event$category,
    event_severity = event$severity,
    system_inertia_gvas = inertia,
    system_demand_mw = demand
  )]

  # --- 6. Validate (Optional) ---
  validation_result <- NULL
  if (isTRUE(params$validation$enabled)) {
    # Prepare system conditions for validation
    system_conditions_for_validation <- list(
      inertia = inertia,
      demand = demand,
      response_holdings = response_holdings
    )

    validation_result <- validate_imbalance_calculation(
      window_data,
      system_conditions_for_validation,
      params,
      config
    )

    cat("  Validation:", validation_result$metrics$quality_rating,
        "- RMSE:", round(validation_result$metrics$rmse, 5), "Hz\n")

    # Generate validation plot if enabled
    if (isTRUE(params$validation$plot_validation %||% TRUE)) {
      plot_validation_results(validation_result, event, config)
    }
  }

  # --- 7. Generate Plot (Optional) ---
  if (isTRUE(params$output_plots$enabled)) {
    plot_event_imbalance(window_data, event, params, config)
  }

  # --- 8. Return Results ---
  output_cols <- c("event_id", "boundary_time", "starting_sp", "dtm_sec", "time_rel_s",
                   "f", "df_hz", "rocof", "imbalance_mw",
                   "lf_response_mw", "hf_response_mw", "demand_damping_mw", "rocof_component_mw",
                   "event_category", "event_severity", "system_inertia_gvas", "system_demand_mw")

  return(window_data[, ..output_cols])
}


#' Retrieves a system parameter for a given timestamp
#'
#' @param timestamp The timestamp to query
#' @param data_table A data.table with system parameter data
#' @param column_name The name of the column containing the parameter
#' @param default_value Default value if no data is available
#' @return The parameter value
#'
get_system_parameter <- function(event_timestamp, data_table, column_name, default_value) {

  if (is.null(data_table) || nrow(data_table) == 0) {
    return(default_value)
  }

  if (!"timestamp" %in% names(data_table)) {
    cat("WARN: 'timestamp' column not found in data for", column_name, ". Using default.\n")
    return(default_value)
  }

  # Ensure timestamp column is POSIXct
  if (!inherits(data_table$timestamp, "POSIXct")) {
    data_table[, timestamp := as.POSIXct(timestamp)]
  }

  # Find the row with the minimum absolute time difference to the event timestamp
  time_diffs <- abs(difftime(event_timestamp, data_table$timestamp, units = "secs"))
  min_idx <- which.min(time_diffs)
  nearest_row <- data_table[min_idx]

  if (nrow(nearest_row) > 0 && column_name %in% names(nearest_row)) {
    value <- as.numeric(nearest_row[[column_name]])
    if (!is.na(value)) {
      return(value)
    }
  }

  return(default_value)
}


#' Retrieves response holdings for a given timestamp
#'
#' @param timestamp The timestamp to query
#' @param system_data List containing system data
#' @param params Configuration parameters
#' @return A list with response holdings (MW)
#'
get_response_holdings <- function(timestamp, system_data, params) {

  default_response <- system_data$default_response %||% list(
    primary_mw = 500, secondary_mw = 300, high_mw = 200,
    dr_mw = 300, dm_mw = 400, dc_mw = 500
  )

  response_data <- system_data$response
  if (is.null(response_data) || nrow(response_data) == 0) {
    return(default_response)
  }

  if (!"timestamp" %in% names(response_data)) {
    cat("WARN: 'timestamp' column not found in response data. Using defaults.\n")
    return(default_response)
  }
  
  if (!inherits(response_data$timestamp, "POSIXct")) {
    response_data[, timestamp := as.POSIXct(timestamp)]
  }

  # Find the row with the minimum absolute time difference
  nearest_row <- response_data[which.min(abs(difftime(timestamp, response_data$timestamp, units = "secs")))]

  if (nrow(nearest_row) == 0) {
    return(default_response)
  }

  pick_value <- function(value, default) {
    if (is.null(value) || length(value) == 0 || is.na(value)) {
      default
    } else {
      as.numeric(value)
    }
  }

  # Return the values from the nearest row, falling back to defaults if a column is missing or NA
  return(list(
    primary_mw = pick_value(nearest_row$primary_mw, default_response$primary_mw),
    secondary_mw = pick_value(nearest_row$secondary_mw, default_response$secondary_mw),
    high_mw = pick_value(nearest_row$high_mw, default_response$high_mw),
    dr_mw = pick_value(nearest_row$dr_mw, default_response$dr_mw),
    dm_mw = pick_value(nearest_row$dm_mw, default_response$dm_mw),
    dc_mw = pick_value(nearest_row$dc_mw, default_response$dc_mw)
  ))
}


#' Validates the imbalance calculation by forward simulation
#'
#' This function takes the calculated imbalance and simulates what the frequency
#' should be, then compares it to the actual measured frequency. Good agreement
#' indicates that the inverse calculation is correct.
#'
#' NOTE: This function now calls the forward frequency simulator in frequency_simulator.R
#'       which must be sourced before calling this function.
#'
#' @param window_data The data.table with calculated imbalances
#' @param system_conditions List with inertia, demand, response_holdings
#' @param params Configuration parameters
#' @param config Full application configuration
#' @return A list with validation metrics (RMSE, max error, etc.)
#'
validate_imbalance_calculation <- function(window_data, system_conditions, params, config) {

  # Check if forward simulator function is available
  if (!exists("validate_imbalance_with_simulation")) {
    cat("    WARN: Forward simulator not available. Using simplified validation.\n")

    # Fallback to simple validation
    tolerance <- params$validation$tolerance_hz %||% 0.01
    rmse <- sqrt(mean((window_data$df_hz - mean(window_data$df_hz))^2, na.rm = TRUE))

    return(list(
      metrics = list(
        rmse = rmse,
        max_error = max(abs(window_data$df_hz), na.rm = TRUE),
        within_tolerance = rmse < tolerance,
        quality_rating = "Not validated"
      )
    ))
  }

  # Use the full forward simulation validation
  result <- validate_imbalance_with_simulation(
    window_data = window_data,
    system_conditions = system_conditions,
    params = params,
    config = config
  )

  return(result)
}


#' Generates a diagnostic plot for an event's imbalance calculation
#'
#' @param window_data The data.table with calculated imbalances
#' @param event The event metadata
#' @param params Configuration parameters
#' @param config Full application configuration
#'
plot_event_imbalance <- function(window_data, event, params, config) {

  # Create output directory if needed
  plot_dir <- file.path(config$paths$output_imbalance, "plots")
  if (!dir.exists(plot_dir)) {
    dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Create filename
  event_id <- window_data$event_id[1]
  plot_filename <- paste0("imbalance_", event_id, ".png")
  plot_path <- file.path(plot_dir, plot_filename)

  # Get plot parameters
  plot_width <- params$output_plots$plot_width %||% 14
  plot_height <- params$output_plots$plot_height %||% 8
  plot_dpi <- params$output_plots$plot_dpi %||% 150

  # Create multi-panel plot
  # Panel 1: Frequency over time
  p1 <- ggplot(window_data, aes(x = time_rel_s, y = f)) +
    geom_line(color = "#1f77b4", linewidth = 0.8) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "#d62728", linewidth = 1) +
    geom_hline(yintercept = 50, linetype = "dotted", color = "gray50") +
    labs(title = paste0("Event: ", event_id, " - Frequency Profile"),
         x = "Time relative to SP boundary (seconds)",
         y = "Frequency (Hz)") +
    theme_minimal(base_size = 11) +
    theme(plot.title = element_text(hjust = 0.5))

  # Panel 2: Imbalance over time
  p2 <- ggplot(window_data, aes(x = time_rel_s, y = imbalance_mw)) +
    geom_line(color = "#2ca02c", linewidth = 0.8) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "#d62728", linewidth = 1) +
    geom_hline(yintercept = 0, linetype = "dotted", color = "gray50") +
    labs(title = "Calculated Imbalance",
         x = "Time relative to SP boundary (seconds)",
         y = "Imbalance (MW)") +
    theme_minimal(base_size = 11) +
    theme(plot.title = element_text(hjust = 0.5))

  # Panel 3: Imbalance components
  components_long <- melt(window_data,
                          id.vars = "time_rel_s",
                          measure.vars = c("lf_response_mw", "hf_response_mw",
                                          "demand_damping_mw", "rocof_component_mw"),
                          variable.name = "component",
                          value.name = "mw")

  p3 <- ggplot(components_long, aes(x = time_rel_s, y = mw, color = component)) +
    geom_line(linewidth = 0.7) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "#d62728", linewidth = 1) +
    geom_hline(yintercept = 0, linetype = "dotted", color = "gray50") +
    scale_color_manual(
      values = c("lf_response_mw" = "#ff7f0e",
                 "hf_response_mw" = "#9467bd",
                 "demand_damping_mw" = "#8c564b",
                 "rocof_component_mw" = "#e377c2"),
      labels = c("LF Response", "HF Response", "Demand Damping", "RoCoF Component")
    ) +
    labs(title = "Imbalance Components",
         x = "Time relative to SP boundary (seconds)",
         y = "MW",
         color = "Component") +
    theme_minimal(base_size = 11) +
    theme(plot.title = element_text(hjust = 0.5),
          legend.position = "bottom")

  # Combine plots
  combined_plot <- gridExtra::grid.arrange(p1, p2, p3, ncol = 1)

  # Save
  tryCatch({
    ggsave(plot_path, plot = combined_plot, width = plot_width, height = plot_height, dpi = plot_dpi)
    cat("  Generated plot:", plot_filename, "\n")
  }, error = function(e) {
    cat("WARN: Failed to save plot:", e$message, "\n")
  })
}


#' Creates summary statistics from imbalance calculations
#'
#' @param imbalance_results The combined imbalance results
#' @param events_analyzed The events that were analyzed
#' @return A data.table with summary statistics
#'
create_summary_statistics <- function(imbalance_results, events_analyzed) {

  # Calculate summary stats per event
  summary <- imbalance_results[, .(
    n_seconds = .N,
    min_imbalance_mw = min(imbalance_mw, na.rm = TRUE),
    max_imbalance_mw = max(imbalance_mw, na.rm = TRUE),
    mean_imbalance_mw = mean(imbalance_mw, na.rm = TRUE),
    median_imbalance_mw = median(imbalance_mw, na.rm = TRUE),
    sd_imbalance_mw = sd(imbalance_mw, na.rm = TRUE),
    p05_imbalance_mw = quantile(imbalance_mw, 0.05, na.rm = TRUE),
    p95_imbalance_mw = quantile(imbalance_mw, 0.95, na.rm = TRUE),
    max_abs_imbalance_mw = max(abs(imbalance_mw), na.rm = TRUE),
    boundary_imbalance_mw = imbalance_mw[which.min(abs(time_rel_s))],
    mean_freq_hz = mean(f, na.rm = TRUE),
    min_freq_hz = min(f, na.rm = TRUE),
    max_freq_hz = max(f, na.rm = TRUE),
    system_inertia_gvas = first(system_inertia_gvas),
    system_demand_mw = first(system_demand_mw)
  ), by = .(event_id, boundary_time, starting_sp, event_category, event_severity)]

  # Sort by severity
  setorder(summary, -event_severity)

  return(summary)
}
