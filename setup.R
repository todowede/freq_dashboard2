#!/usr/bin/env Rscript
# setup.R
# Run this script once to install all required packages for the NESO Frequency Analysis Dashboard
#
# Usage:
#   Rscript setup.R

cat("==================================================\n")
cat("NESO Frequency Analysis Dashboard - Setup\n")
cat("==================================================\n\n")

# List of required packages
required_packages <- c(
  # Command line and configuration
  "optparse",
  "yaml",

  # Data manipulation
  "data.table",
  "dplyr",

  # Date/time handling
  "lubridate",

  # Visualization
  "ggplot2",
  "scales",

  # Interactive plots
  "plotly",
  "htmlwidgets",

  # Shiny dashboard
  "shiny",
  "shinydashboard",
  "shinyjs",
  "DT",

  # Data download
  "httr",
  "jsonlite"
)

cat("Checking and installing required packages...\n\n")

# Function to install missing packages
install_if_missing <- function(package) {
  if (!require(package, character.only = TRUE, quietly = TRUE)) {
    cat(paste0("Installing: ", package, "...\n"))
    install.packages(package, repos = "https://cloud.r-project.org/",
                     dependencies = TRUE, quiet = FALSE)

    # Verify installation
    if (require(package, character.only = TRUE, quietly = TRUE)) {
      cat(paste0("  SUCCESS: ", package, " installed\n\n"))
      return(TRUE)
    } else {
      cat(paste0("  ERROR: Failed to install ", package, "\n\n"))
      return(FALSE)
    }
  } else {
    cat(paste0("  Already installed: ", package, "\n"))
    return(TRUE)
  }
}

# Install all packages
success_count <- 0
fail_count <- 0

for (pkg in required_packages) {
  if (install_if_missing(pkg)) {
    success_count <- success_count + 1
  } else {
    fail_count <- fail_count + 1
  }
}

cat("\n==================================================\n")
cat("Setup Summary:\n")
cat("==================================================\n")
cat(paste0("Total packages: ", length(required_packages), "\n"))
cat(paste0("Successfully installed/verified: ", success_count, "\n"))
cat(paste0("Failed: ", fail_count, "\n\n"))

if (fail_count == 0) {
  cat("SUCCESS: All packages installed successfully!\n")
  cat("\nYou can now run the analysis pipeline:\n")
  cat("  Rscript main.R\n\n")
  cat("Or launch the dashboard:\n")
  cat("  Rscript -e \"shiny::runApp('dashboard.R')\"\n\n")
} else {
  cat("WARNING: Some packages failed to install.\n")
  cat("Please install them manually using:\n")
  cat("  install.packages('package_name')\n\n")
}

cat("==================================================\n")
