# NESO Frequency Analysis Dashboard

Interactive R Shiny dashboard for analyzing UK grid frequency data from the National Energy System Operator (NESO).

## Features

- **SP Boundary Event Detection** - Detects and classifies frequency disturbances at 30-minute settlement period boundaries
- **Frequency KPI Monitoring** - Continuous monitoring of frequency quality metrics
- **Frequency Excursion Analysis** - Tracks deviations at 0.1, 0.15, and 0.2 Hz thresholds
- **Interactive Visualizations** - Real-time frequency and ROCOF plots with date filtering
- **Monthly Reporting** - Automated generation of static PNG plots

## Prerequisites

- **R version 4.0 or higher**
- **Windows, Linux, or macOS**

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/todowede/freq_dashboard2.git
cd freq_dashboard2
```

### 2. Install required packages

Run the setup script to install all dependencies:

```bash
Rscript setup.R
```

This will install:
- `optparse`, `yaml` - Configuration management
- `data.table`, `dplyr` - Data manipulation
- `lubridate` - Date/time handling
- `ggplot2`, `scales`, `plotly`, `htmlwidgets` - Visualization
- `shiny`, `shinydashboard`, `shinyjs`, `DT` - Dashboard
- `httr`, `jsonlite` - API data download

## Quick Start

### Option 1: Run the full analysis pipeline

```bash
Rscript main.R
```

This will:
1. Download frequency data from NESO API (if not present)
2. Load and clean raw data
3. Process to per-second frequency with ROCOF
4. Detect SP boundary events
5. Calculate frequency KPIs
6. Analyze frequency excursions
7. Generate static reports

### Option 2: Run specific steps

```bash
# Run only data loading and processing
Rscript main.R data_loader frequency_processor

# Run only reporting
Rscript main.R reporting
```

### Option 3: Launch the interactive dashboard

```bash
Rscript -e "shiny::runApp('dashboard.R')"
```

Then open your browser to: `http://localhost:XXXX` (port number will be shown in console)

## Configuration

Edit `config/config.yml` to customize:

### Date Range
```yaml
parameters:
  start_month: "2025-05"
  end_month: "2025-08"
```

### Event Detection Thresholds
```yaml
event_detection:
  window_seconds: 15      # Analysis window (±seconds around SP boundary)
  delta_f_hz: 0.1         # RED threshold: absolute frequency change
  rocof_p99_hz_s: 0.01    # RED threshold: 99th percentile ROCOF
```

### Verification Plots
```yaml
verification_plots:
  enabled: true
  strategy: "worst_N"     # Options: "all", "top_N", "random_N", "worst_N", "best_N"
  count: 10               # Number of plots to generate
  sort_by: "severity"     # Options: "severity", "abs_freq_change", "rocof_p99"
```

### Frequency Excursion Thresholds
The analysis tracks excursions at **0.1, 0.15, and 0.2 Hz** deviations from 50 Hz (defined in `R/analysis_frequency_excursion.R` line 32).

## Project Structure

```
freq_dashboard2/
├── main.R                  # Main workflow orchestrator
├── dashboard.R             # Shiny dashboard application
├── setup.R                 # Package installation script
├── config/
│   └── config.yml          # Configuration file
├── R/
│   ├── analysis_event_detection.R         # SP boundary event detection
│   ├── analysis_frequency_excursion.R     # Frequency excursion analysis
│   ├── analysis_kpi_monitoring.R          # Frequency KPI monitoring
│   ├── data_acquistion.R                  # API data downloader
│   ├── data_loader.R                      # Data loading & cleaning
│   ├── frequency_processor.R              # Per-second data processing
│   ├── reporting.R                        # Static plot generation
│   └── utils.R                            # Helper functions
└── data/
    ├── input/              # Raw CSV files (fnew-YYYY-M.csv)
    ├── processed/          # Processed data (frequency_per_second_with_rocof.csv)
    ├── output/
    │   ├── reports/        # CSV analysis results
    │   └── plots/          # PNG static plots
    └── verification/       # Event verification plots
```

## Dashboard Tabs

1. **Overview** - Configuration parameters and summary statistics
2. **SP Boundary Events** - Browse and filter detected events
3. **Frequency & ROCOF** - Interactive time series plots
4. **Frequency KPI** - Quality monitoring by settlement period
5. **Frequency Excursion** - Daily excursion counts and durations
6. **Monthly Red Ratio** - Static monthly trend plots

## Data Format

Input files should be CSV with columns:
- `dtm` or `datetime` - Timestamp
- `f` or `frequency` - Frequency in Hz

Example: `fnew-2025-5.csv`
```csv
dtm,f
2025-05-01 00:00:00,50.012
2025-05-01 00:00:01,50.015
...
```

## Troubleshooting

### Package installation fails
If `setup.R` fails to install a package, install it manually:
```r
install.packages("package_name")
```

### Dashboard won't launch
Check that all packages are installed:
```r
required_packages <- c("shiny", "shinydashboard", "data.table", "plotly", "ggplot2", "DT", "lubridate", "shinyjs", "scales")
missing <- required_packages[!sapply(required_packages, require, character.only = TRUE, quietly = TRUE)]
if (length(missing) > 0) {
  cat("Missing packages:", paste(missing, collapse = ", "), "\n")
}
```

### No data files found
The workflow expects CSV files named `fnew-YYYY-M.csv` in `data/input/`. Either:
- Run `Rscript main.R data_acquisition` to download from NESO API
- Or manually place your CSV files in `data/input/`

## License

MIT License - See LICENSE file for details

## Acknowledgments

- Data source: [NESO System Frequency Data](https://data.nationalgrideso.com/)
- Dashboard framework: R Shiny
