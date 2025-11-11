# R/red_event_correlation.R
# Purpose: Prepare REMIT outage data for correlation work by extracting
#          sudden unplanned trips that are most likely to drive imbalance events.

suppressPackageStartupMessages({
  library(data.table)
  library(lubridate)
})

`%||%` <- function(x, y) if (is.null(x)) y else x

REMIT_OUTPUT_COLUMNS <- c(
  "remit_id", "dataset", "mrid", "revision_number",
  "publish_time", "created_time",
  "event_start_time", "event_end_time",
  "duration_minutes", "announcement_delay_minutes",
  "message_type", "message_heading",
  "event_type", "unavailability_type", "event_status",
  "participant_id", "registration_code",
  "asset_id", "asset_type",
  "affected_unit", "affected_unit_eic", "affected_area",
  "bidding_zone", "fuel_type",
  "normal_capacity", "available_capacity", "unavailable_capacity", "lost_capacity_mw",
  "duration_uncertainty", "cause", "related_information", "outage_profile"
)

write_empty_remit_output <- function(path) {
  empty_cols <- setNames(rep(list(character()), length(REMIT_OUTPUT_COLUMNS)),
                         REMIT_OUTPUT_COLUMNS)
  empty_dt <- as.data.table(empty_cols)
  fwrite(empty_dt, path)
}

DEMAND_OUTPUT_COLUMNS <- c("Date", "Datetime", "Settlement_Period", "Absolute_Error")

write_empty_demand_output <- function(path) {
  empty_cols <- setNames(rep(list(character()), length(DEMAND_OUTPUT_COLUMNS)),
                         DEMAND_OUTPUT_COLUMNS)
  empty_dt <- as.data.table(empty_cols)
  fwrite(empty_dt, path)
}

#' Prepares REMIT outage notifications for downstream correlation analysis.
#'
#' The function focuses on sudden unplanned generation trips by applying a set
#' of filters (unplanned, production, high-capacity, short duration, and sudden
#' announcement) and outputs the curated dataset as a CSV.
#'
#' @param config Application configuration list.
run_red_event_correlation <- function(config) {

  remit_path <- file.path(config$paths$input, "remit.csv")
  out_file <- file.path(config$paths$output_reports, "red_events_remit_matches.csv")
  demand_path <- file.path(config$paths$input, "1b-incentive.csv")
  demand_out_file <- file.path(config$paths$output_reports, "red_event_demand.csv")

  filter_defaults <- list(
    min_trip_capacity_mw = 100,
    max_duration_minutes = 30,
    max_announcement_delay_minutes = 5,
    require_event_status = "Active"
  )
  filter_overrides <- config$parameters$remit_filters %||% list()
  filter_params <- modifyList(filter_defaults, filter_overrides)
  min_capacity_threshold <- filter_params$min_trip_capacity_mw %||% filter_params$min_capacity_mw %||% 100
  max_duration_threshold <- filter_params$max_duration_minutes
  max_delay_threshold <- filter_params$max_announcement_delay_minutes
  required_status <- tolower(filter_params$require_event_status %||% "")

  if (!file.exists(remit_path)) {
    cat("WARN: REMIT file not found at", remit_path, "- skipping correlation prep.\n")
    write_empty_remit_output(out_file)
    write_empty_demand_output(demand_out_file)
    return(invisible(NULL))
  }

  cat("INFO: Loading REMIT outage data from:", remit_path, "\n")
  remit_raw <- fread(remit_path)
  if (nrow(remit_raw) == 0) {
    cat("WARN: REMIT file is empty. Nothing to process.\n")
    write_empty_remit_output(out_file)
    write_empty_demand_output(demand_out_file)
    return(invisible(NULL))
  }

  cat(sprintf("INFO: Filter thresholds -> Lost Capacity >= %s MW | Duration <= %s min | Announcement delay <= %s min\n",
              min_capacity_threshold,
              max_duration_threshold,
              max_delay_threshold))

  parse_time <- function(x) {
    suppressWarnings(as.POSIXct(x, tz = "UTC"))
  }

  remit <- remit_raw[, .(
    remit_id = id,
    dataset = dataset,
    mrid = mrid,
    revision_number = revisionNumber,
    publish_time = publishTime,
    created_time = createdTime,
    message_type = messageType,
    message_heading = messageHeading,
    event_type = eventType,
    unavailability_type = unavailabilityType,
    participant_id = participantId,
    registration_code = registrationCode,
    asset_id = assetId,
    asset_type = assetType,
    affected_unit = affectedUnit,
    affected_unit_eic = affectedUnitEIC,
    affected_area = affectedArea,
    bidding_zone = biddingZone,
    fuel_type = fuelType,
    normal_capacity = as.numeric(normalCapacity),
    available_capacity = as.numeric(availableCapacity),
    unavailable_capacity = as.numeric(unavailableCapacity),
    event_status = eventStatus,
    event_start_time = eventStartTime,
    event_end_time = eventEndTime,
    duration_uncertainty = durationUncertainty,
    cause = cause,
    related_information = relatedInformation,
    outage_profile = outageProfile
  )]

  remit[, created_time := parse_time(created_time)]
  remit[, publish_time := parse_time(publish_time)]
  remit[is.na(publish_time), publish_time := created_time]
  remit[, event_start_time := parse_time(event_start_time)]
  remit[, event_end_time := parse_time(event_end_time)]
  remit[is.na(event_end_time), event_end_time := event_start_time]
  remit[event_end_time < event_start_time, event_end_time := event_start_time]

  remit <- remit[!is.na(event_start_time)]
  if (nrow(remit) == 0) {
    cat("WARN: No REMIT rows with valid start times after parsing.\n")
    write_empty_remit_output(out_file)
    write_empty_demand_output(demand_out_file)
    return(invisible(NULL))
  }

  remit[, duration_minutes := as.numeric(difftime(event_end_time, event_start_time, units = "mins"))]
  remit[, announcement_delay_minutes := as.numeric(difftime(event_start_time, publish_time, units = "mins"))]
  remit[, lost_capacity_mw := fifelse(
    !is.na(normal_capacity) & !is.na(available_capacity),
    pmax(normal_capacity - available_capacity, 0),
    NA_real_
  )]

  initial_count <- nrow(remit)
  cat("INFO: Initial records:", format(initial_count, big.mark = ","), "\n\n")

  remit <- remit[tolower(unavailability_type) == "unplanned"]
  cat(sprintf("INFO: Filter 1 (Unplanned): %s records (%.1f%% of initial)\n",
              format(nrow(remit), big.mark = ","),
              if (initial_count == 0) 0 else (nrow(remit) / initial_count) * 100))

  remit <- remit[tolower(event_type) == "production unavailability"]
  cat(sprintf("INFO: Filter 2 (Production): %s records (%.1f%% of initial)\n",
              format(nrow(remit), big.mark = ","),
              if (initial_count == 0) 0 else (nrow(remit) / initial_count) * 100))

  remit <- remit[(!is.na(lost_capacity_mw) & lost_capacity_mw >= min_capacity_threshold) |
                   (!is.na(unavailable_capacity) & unavailable_capacity >= min_capacity_threshold)]
  cat(sprintf("INFO: Filter 3 (Lost capacity >= %s MW): %s records (%.1f%% of initial)\n",
              min_capacity_threshold,
              format(nrow(remit), big.mark = ","),
              if (initial_count == 0) 0 else (nrow(remit) / initial_count) * 100))

  remit <- remit[!is.na(duration_minutes) & duration_minutes <= max_duration_threshold]
  cat(sprintf("INFO: Filter 4 (<%s min duration): %s records (%.1f%% of initial)\n",
              max_duration_threshold,
              format(nrow(remit), big.mark = ","),
              if (initial_count == 0) 0 else (nrow(remit) / initial_count) * 100))

  remit <- remit[!is.na(announcement_delay_minutes) &
                   abs(announcement_delay_minutes) <= max_delay_threshold]
  cat(sprintf("INFO: Filter 5 (<%s min announcement delay): %s records (%.1f%% of initial)\n\n",
              max_delay_threshold,
              format(nrow(remit), big.mark = ","),
              if (initial_count == 0) 0 else (nrow(remit) / initial_count) * 100))

  if (required_status != "") {
    remit <- remit[tolower(event_status) == required_status]
    cat(sprintf("INFO: Filter 6 (event status == %s): %s records (%.1f%% of initial)\n\n",
                required_status,
                format(nrow(remit), big.mark = ","),
                if (initial_count == 0) 0 else (nrow(remit) / initial_count) * 100))
  } else {
    cat("INFO: Filter 6 skipped (no status requirement configured).\n\n")
  }

  if (nrow(remit) == 0) {
    cat("WARN: No REMIT rows remain after filters.\n")
    write_empty_remit_output(out_file)
    write_empty_demand_output(demand_out_file)
    return(invisible(NULL))
  }

  setorderv(remit, c("remit_id", "revision_number"))
  remit <- remit[remit[, .I[.N], by = remit_id]$V1]
  cat("INFO: Records after deduplicating by remit_id:", format(nrow(remit), big.mark = ","), "\n")

  remit <- remit[bidding_zone %in% c(NA_character_, "", "10YGB----------A")]
  cat("INFO: Filter 7 (GB bidding zone/unspecified):", format(nrow(remit), big.mark = ","), "records remain.\n\n")

  if (nrow(remit) == 0) {
    cat("WARN: No REMIT rows remain after bidding zone filter.\n")
    write_empty_remit_output(out_file)
    write_empty_demand_output(demand_out_file)
    return(invisible(NULL))
  }

  # Ensure all requested columns exist before writing.
  missing_cols <- setdiff(REMIT_OUTPUT_COLUMNS, names(remit))
  if (length(missing_cols) > 0) {
    stop("Missing expected columns in REMIT data: ", paste(missing_cols, collapse = ", "))
  }

  output <- remit[, ..REMIT_OUTPUT_COLUMNS]
  fwrite(output, out_file)

  cat("INFO:", format(nrow(output), big.mark = ","), "sudden unplanned REMIT trips saved to:", out_file, "\n")

  # --- Demand Forecast Error Extraction ---
  if (!file.exists(demand_path)) {
    cat("WARN: Demand forecast file not found at", demand_path, "- writing empty demand output.\n")
    write_empty_demand_output(demand_out_file)
    return(invisible(list(remit = output, demand = data.table())))
  }

  demand_raw <- fread(demand_path)
  if (nrow(demand_raw) == 0) {
    cat("WARN: Demand forecast file is empty. Writing empty demand output.\n")
    write_empty_demand_output(demand_out_file)
    return(invisible(list(remit = output, demand = data.table())))
  }

  required_demand_cols <- c("Date", "Datetime", "Settlement_Period", "Absolute_Error")
  missing_demand_cols <- setdiff(required_demand_cols, names(demand_raw))
  if (length(missing_demand_cols)) {
    stop("Demand forecast file missing required columns: ", paste(missing_demand_cols, collapse = ", "))
  }

  demand_processed <- copy(demand_raw[, ..required_demand_cols])
  demand_processed[, Date := as.Date(Date)]
  demand_processed[, Datetime := suppressWarnings(as.POSIXct(Datetime, tz = "UTC"))]
  demand_processed[, Settlement_Period := as.integer(Settlement_Period)]
  demand_processed[, Absolute_Error := as.numeric(Absolute_Error)]

  fwrite(demand_processed, demand_out_file)
  cat("INFO:", format(nrow(demand_processed), big.mark = ","), "demand forecast rows saved to:", demand_out_file, "\n")

  invisible(list(remit = output, demand = demand_processed))
}
