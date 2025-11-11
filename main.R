#!/usr/bin/env Rscript
# ===================================================================
# main.R: Main Orchestrator Script
#
# Description:
# Reads a config file to execute a defined data analysis workflow.
# The workflow can be overridden by providing specific steps as
# command-line arguments.
#
# Usage:
# 1. Run the full workflow defined in the config:
#    Rscript main.R
#
# 2. Run only specific steps, ignoring the config's workflow:
#    Rscript main.R data_loader frequency_processor
#
# 3. Use a different config file:
#    Rscript main.R --config="path/to/other.yml" reporting
# ===================================================================

# -------------------------------------------------------------------
# 1. SETUP & DEPENDENCIES
# -------------------------------------------------------------------
suppressPackageStartupMessages({
  library(optparse)
  library(yaml)
})

# -------------------------------------------------------------------
# 2. COMMAND-LINE ARGUMENT PARSING
# -------------------------------------------------------------------
option_list <- list(
  make_option(c("-c", "--config"),
              type = "character",
              default = "config/config.yml",
              help = "Path to the YAML configuration file [default: %default]",
              metavar = "path")
)
parser <- OptionParser(option_list = option_list)
opts <- parse_args(parser, positional_arguments = TRUE)
if (!file.exists(opts$options$config)) {
  stop("Error: Configuration file not found at: ", opts$options$config, call. = FALSE)
}

# -------------------------------------------------------------------
# 3. LOAD CONFIGURATION AND MODULES
# -------------------------------------------------------------------
cat("INFO: Loading configuration from:", opts$options$config, "\n")
config <- read_yaml(opts$options$config)

module_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
cat("INFO: Sourcing", length(module_files), "modules from R/ directory...\n")
sapply(module_files, source)

# -------------------------------------------------------------------
# 4. MAIN WORKFLOW EXECUTION
# -------------------------------------------------------------------
main <- function(config, cli_steps) {

  cat("INFO: Starting analysis workflow...\n")

  # --- Ensure output directories exist ---
  cat("INFO: Creating output directories if they don't exist...\n")
  required_dirs <- c(
    config$paths$processed,
    config$paths$output_reports,
    config$paths$output_plots,
    config$paths$output_imbalance
  )
  for (dir_path in required_dirs) {
    if (!dir.exists(dir_path)) {
      dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
      cat("  - Created:", dir_path, "\n")
    }
  }

  # --- Determine which steps to run ---
  steps_to_run <- NULL
  if (length(cli_steps) > 0) {
    cat("INFO: Overriding config workflow with steps from command line.\n")
    steps_to_run <- cli_steps
  } else {
    cat("INFO: Using workflow defined in config file.\n")
    steps_to_run <- config$workflow_steps
  }
  
  if (is.null(steps_to_run) || length(steps_to_run) == 0) {
    cat("WARN: No workflow steps to execute. Exiting.\n")
    return(invisible(NULL))
  }
  
  cat("INFO: Steps to be executed:", paste(steps_to_run, collapse = " -> "), "\n")
  
  # This environment will store results from one step to pass to the next
  workflow_env <- new.env()
  
  for (step_name in steps_to_run) {
    
    cat("-------------------------------------------------\n")
    cat("INFO: Running Step ->", step_name, "\n")
    
    # **FINALIZED**: The switch now calls all the completed functions.
    switch(step_name,
           
           "data_acquisition" = {
             run_data_acquisition(config)
           },
           
           "data_loader" = {
             workflow_env$raw_data <- load_raw_data(config)
           },
           
           "frequency_processor" = {
             if (exists("raw_data", envir = workflow_env)) {
               workflow_env$processed_data <- process_frequency_data(workflow_env$raw_data$frequency, config)
             } else {
               stop("ERROR: Cannot run 'frequency_processor'. 'data_loader' must be run first.", call. = FALSE)
             }
           },
           
           "event_detection" = {
             if (exists("processed_data", envir = workflow_env)) {
               workflow_env$event_results <- run_event_detection(workflow_env$processed_data, config)
             } else {
               stop("ERROR: Cannot run 'event_detection'. 'frequency_processor' must be run first.", call. = FALSE)
             }
           },

           "red_event_correlation" = {
             run_red_event_correlation(config)
           },
           
           "kpi_monitoring" = {
             if (exists("processed_data", envir = workflow_env)) {
               run_kpi_monitoring(workflow_env$processed_data, config)
             } else {
               stop("ERROR: Cannot run 'kpi_monitoring'. 'frequency_processor' must be run first.", call. = FALSE)
             }
           },

           "frequency_excursion" = {
             if (exists("processed_data", envir = workflow_env)) {
               run_frequency_excursion_analysis(workflow_env$processed_data, config)
             } else {
               stop("ERROR: Cannot run 'frequency_excursion'. 'frequency_processor' must be run first.", call. = FALSE)
             }
           },

           "response_holding" = {
             run_response_holding(config)
           },

           "demand_analysis" = {
             # Load event results if available for correlation
             event_path <- file.path(config$paths$output_reports, "sp_boundary_events.csv")
             event_results <- if (file.exists(event_path)) {
               fread(event_path)
             } else {
               NULL
             }
             run_demand_analysis(event_results, config)
           },

           "unforeseen_demand" = {
             # Requires both demand_analysis and event_detection outputs
             run_unforeseen_demand_analysis(config)
           },

           "imbalance_calculation" = {
             # Requires processed frequency data and event results
             if (!exists("processed_data", envir = workflow_env)) {
               cat("WARN: Loading processed frequency data from file...\n")
               freq_path <- file.path(config$paths$processed, "frequency_per_second_with_rocof.csv")
               if (file.exists(freq_path)) {
                 workflow_env$processed_data <- fread(freq_path)
                 workflow_env$processed_data[, dtm_sec := as.POSIXct(dtm_sec)]
               } else {
                 stop("ERROR: Cannot run 'imbalance_calculation'. Frequency data not found.", call. = FALSE)
               }
             }

             event_path <- file.path(config$paths$output_reports, "sp_boundary_events.csv")
             if (!file.exists(event_path)) {
               stop("ERROR: Cannot run 'imbalance_calculation'. Event detection must be run first.", call. = FALSE)
             }

             event_results <- fread(event_path)
             run_imbalance_calculation(workflow_env$processed_data, event_results, config)
           },

           "monthly_imbalance" = {
             # Requires processed frequency data
             if (!exists("processed_data", envir = workflow_env)) {
               cat("WARN: Loading processed frequency data from file...\n")
               freq_path <- file.path(config$paths$processed, "frequency_per_second_with_rocof.csv")
               if (file.exists(freq_path)) {
                 workflow_env$processed_data <- fread(freq_path)
                 workflow_env$processed_data[, dtm_sec := as.POSIXct(dtm_sec)]
               } else {
                 stop("ERROR: Cannot run 'monthly_imbalance'. Frequency data not found.", call. = FALSE)
               }
             }

             run_monthly_imbalance_analysis(workflow_env$processed_data, config)
           },

           "monthly_unforeseen_comparison" = {
             # Requires processed frequency data (for compatibility)
             if (!exists("processed_data", envir = workflow_env)) {
               cat("WARN: Loading processed frequency data from file...\n")
               freq_path <- file.path(config$paths$processed, "frequency_per_second_with_rocof.csv")
               if (file.exists(freq_path)) {
                 workflow_env$processed_data <- fread(freq_path)
                 workflow_env$processed_data[, dtm_sec := as.POSIXct(dtm_sec)]
               } else {
                 stop("ERROR: Cannot run 'monthly_unforeseen_comparison'. Frequency data not found.", call. = FALSE)
               }
             }

             run_monthly_unforeseen_comparison(workflow_env$processed_data, config)
           },

           "reporting" = {
             generate_reports(config)
           },
           
           {
             cat("WARN: Step '", step_name, "' is not recognized. Skipping.\n", sep = "")
           }
    )
    cat("SUCCESS: Step '", step_name, "' complete.\n", sep = "")
  }
  
  cat("-------------------------------------------------\n")
  cat("INFO: Workflow finished successfully.\n")
}

# -------------------------------------------------------------------
# 5. SCRIPT EXECUTION
# -------------------------------------------------------------------
main(config, opts$args)
