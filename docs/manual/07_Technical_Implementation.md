# PART 7: TECHNICAL IMPLEMENTATION

---

## 7.1 Architecture & Workflow

### 7.1.1 System Architecture

The dashboard is built using **R Shiny** with a modular analysis pipeline:

```
┌─────────────────────────────────────────────────────┐
│          NESO Frequency Analysis Dashboard          │
└─────────────────────────────────────────────────────┘
                          ▲
                          │
┌─────────────────────────┴─────────────────────────┐
│           Data Layer (Processed CSVs)              │
│  - Frequency Events                                │
│  - Imbalance Calculations                          │
│  - Demand Analysis                                 │
│  - Unforeseen Demand                               │
└─────────────────────────┬─────────────────────────┘
                          ▲
                          │
┌─────────────────────────┴─────────────────────────┐
│         Analysis Pipeline (R Scripts)              │
│  Step 1: data_acquisition                          │
│  Step 2: data_loader                               │
│  Step 3: frequency_processor                       │
│  Step 4: event_detection                           │
│  Step 5: kpi_monitoring                            │
│  Step 6: frequency_excursion                       │
│  Step 7: response_holding                          │
│  Step 8: demand_analysis                           │
│  Step 9: unforeseen_demand                         │
│  Step 10: imbalance_calculation                    │
│  Step 11: reporting                                │
└─────────────────────────┬─────────────────────────┘
                          ▲
                          │
┌─────────────────────────┴─────────────────────────┐
│           Raw Data Sources                         │
│  - NESO Frequency Data (API)                       │
│  - Demand Data (CSV)                               │
│  - Inertia Data (CSV)                              │
│  - Response Holdings (MFR/EAC)                     │
└────────────────────────────────────────────────────┘
```

---

### 7.1.2 Data Processing Workflow

**STAGE 1: Data Acquisition**
```
Script: R/analysis_data_acquisition.R

Process:
1. Connect to NESO API
2. Fetch monthly frequency files (fnew-YYYY-M.csv)
3. Store in data/input/
4. Validate file integrity

Output: Raw frequency CSV files
```

**STAGE 2: Data Loading**
```
Script: R/analysis_data_loader.R

Process:
1. Load all monthly frequency files
2. Load demand data (system_demand.csv)
3. Combine and validate
4. Create unified timestamp index

Output: data/processed/frequency_combined.csv
```

**STAGE 3: Frequency Processing**
```
Script: R/analysis_frequency_processor.R

Process:
1. Calculate RoCoF (numerical derivative)
2. Detect data quality issues
3. Flag anomalies
4. Generate summary statistics

Output: data/processed/frequency_processed.csv
```

**STAGE 4: Event Detection**
```
Script: R/analysis_event_detection.R

Process:
1. Generate SP boundary timeline (all 48 SPs × days)
2. For each boundary:
   a. Extract ±60 second window
   b. Calculate |Δf| and RoCoF_p99
   c. Apply detection thresholds
   d. Classify severity (Red/Amber/Blue)
3. Generate verification plots

Output: data/output/reports/frequency_events_detail.csv
```

**STAGE 5-7: KPI & Capacity Analysis**
```
Scripts:
  - R/analysis_kpi_monitoring.R
  - R/analysis_frequency_excursion.R
  - R/analysis_response_holding.R

Outputs:
  - KPI metrics and monthly trends
  - Excursion statistics
  - Response holdings review
```

**STAGE 8-9: Demand Analysis**
```
Scripts:
  - R/analysis_demand_analysis.R
  - R/analysis_unforeseen_demand.R

Process:
1. Calculate demand changes at SP boundaries
2. Extract frequency at boundaries
3. Calculate demand damping
4. Compute unforeseen demand
5. Statistical flagging (>2.5σ)

Outputs:
  - data/output/reports/demand_analysis_sp_summary.csv
  - data/output/reports/unforeseen_demand_detail.csv
```

**STAGE 10: Imbalance Calculation** (Most Complex)
```
Script: R/analysis_imbalance_calculation.R

Process:
1. Load system data (inertia, demand, response holdings)
2. Select events for analysis (Red events only, configurable)
3. For each event:
   a. Extract ±15 second frequency window
   b. Get system conditions (inertia, demand) for that SP
   c. Calculate second-by-second components:
      - LF Response
      - HF Response
      - Demand Damping
      - RoCoF Component
   d. Calculate imbalance = -LF - HF - Damping + RoCoF
   e. Generate summary statistics
4. Create validation plots (optional)

Outputs:
  - data/output/imbalance/sp_boundary_imbalances.csv (detailed)
  - data/output/imbalance/imbalance_summary.csv (aggregated)
```

**STAGE 11: Reporting**
```
Script: R/analysis_reporting.R

Process:
1. Generate monthly trend plots
2. Create summary statistics
3. Export visualizations
```

---

### 7.1.3 File Structure

```
freq_dashboard2/
├── config/
│   └── config.yml                    # Central configuration
├── data/
│   ├── input/                        # Raw data
│   │   ├── fnew-2025-5.csv          # Frequency data (monthly)
│   │   ├── system_demand.csv         # Demand data
│   │   └── system_inertia.csv        # Inertia data
│   ├── processed/                    # Intermediate processing
│   │   ├── frequency_combined.csv
│   │   └── frequency_processed.csv
│   └── output/
│       ├── reports/                  # Analysis results
│       │   ├── frequency_events_detail.csv
│       │   ├── demand_analysis_sp_summary.csv
│       │   ├── unforeseen_demand_detail.csv
│       │   └── system_dynamics_review.csv
│       ├── imbalance/                # Imbalance calculations
│       │   ├── sp_boundary_imbalances.csv
│       │   └── imbalance_summary.csv
│       └── plots/                    # Verification plots
├── R/
│   ├── analysis_*.R                  # Analysis modules
│   └── utils_*.R                     # Utility functions
├── docs/
│   └── manual/                       # This documentation
├── main.R                            # Pipeline orchestrator
├── dashboard.R                       # Shiny dashboard UI/Server
└── setup.R                           # Dependency installation
```

---

## 7.2 Mathematical Formulas & Algorithms

### 7.2.1 Core Frequency Metrics

**Rate of Change of Frequency (RoCoF)**
```r
# Numerical derivative (central difference)
rocof[i] = (f[i+1] - f[i-1]) / (2 × Δt)

Where:
  Δt = 1 second (sampling interval)

# First and last points (forward/backward difference)
rocof[1] = (f[2] - f[1]) / Δt
rocof[n] = (f[n] - f[n-1]) / Δt
```

**Frequency Deviation**
```r
# Deviation from nominal
Δf = f - 50.0

# Absolute change in window
Δf_abs = max(f) - min(f)
```

---

### 7.2.2 Event Detection Algorithms

**Threshold-Based Detection**
```r
detect_event <- function(freq_window) {
  # Extract frequency range
  f_min <- min(freq_window$f)
  f_max <- max(freq_window$f)
  delta_f <- abs(f_max - f_min)

  # Calculate RoCoF
  rocof <- calculate_rocof(freq_window$f)
  rocof_p99 <- quantile(abs(rocof), 0.99, na.rm = TRUE)

  # Detection criteria
  freq_event <- delta_f > 0.10  # Hz
  rocof_event <- rocof_p99 > 0.01  # Hz/s

  # Event detected if EITHER criterion met
  is_event <- freq_event | rocof_event

  return(list(
    is_event = is_event,
    delta_f = delta_f,
    rocof_p99 = rocof_p99
  ))
}
```

**Severity Classification**
```r
classify_severity <- function(delta_f, rocof_p99) {
  # Red thresholds
  is_red <- (abs(delta_f) > 0.15) | (rocof_p99 > 0.02)

  # Amber thresholds
  is_amber <- ((abs(delta_f) > 0.125) & (abs(delta_f) <= 0.15)) |
              ((rocof_p99 > 0.015) & (rocof_p99 <= 0.02))

  # Classification
  if (is_red) {
    category <- "Red"
  } else if (is_amber) {
    category <- "Amber"
  } else {
    category <- "Blue"
  }

  return(category)
}
```

**Severity Score Calculation**
```r
calculate_severity_score <- function(delta_f, rocof_p99) {
  # Frequency component (0-10 scale)
  freq_score <- min(10, abs(delta_f) / 0.02)

  # RoCoF component (0-10 scale)
  rocof_score <- min(10, rocof_p99 / 0.002)

  # Combined score (weighted average)
  severity <- (freq_score * 0.5) + (rocof_score * 0.5)

  return(severity)
}
```

---

### 7.2.3 Unforeseen Demand Calculation

**Demand Damping Formula**
```r
calculate_damping <- function(demand_mw, freq_current, freq_prev) {
  # Parameters
  pph <- 0.025  # 2.5% per Hz (NESO standard)

  # Frequency change
  delta_f <- freq_current - freq_prev

  # Damping calculation
  # Uses previous period demand as baseline
  damping_mw <- demand_mw * pph * delta_f

  return(damping_mw)
}
```

**Unforeseen Demand Calculation**
```r
calculate_unforeseen <- function(sp_current, sp_previous, freq_data) {
  # Observed demand change
  delta_nd <- sp_current$ND - sp_previous$ND

  # Get frequency at boundary
  boundary_time <- sp_current$timestamp
  freq_before <- freq_data[timestamp == boundary_time - 1]$f
  freq_at <- freq_data[timestamp == boundary_time]$f

  # Calculate damping
  damping_mw <- calculate_damping(
    demand_mw = sp_previous$ND,
    freq_current = freq_at,
    freq_prev = freq_before
  )

  # Unforeseen demand = Observed - Damping
  unforeseen_mw <- delta_nd - damping_mw

  return(list(
    delta_nd = delta_nd,
    damping_mw = damping_mw,
    unforeseen_mw = unforeseen_mw
  ))
}
```

**Statistical Flagging**
```r
flag_unforeseen_events <- function(unforeseen_data) {
  # Group by hour of day
  unforeseen_data[, hour := hour(timestamp)]

  # Calculate hourly statistics
  hourly_stats <- unforeseen_data[, .(
    mean_unforeseen = mean(unforeseen_mw, na.rm = TRUE),
    sd_unforeseen = sd(unforeseen_mw, na.rm = TRUE)
  ), by = hour]

  # Join back
  unforeseen_data <- merge(unforeseen_data, hourly_stats, by = "hour")

  # Flag if deviation > 2.5 standard deviations
  unforeseen_data[, deviation := unforeseen_mw - mean_unforeseen]
  unforeseen_data[, is_flagged := abs(deviation) > (2.5 * sd_unforeseen)]

  return(unforeseen_data)
}
```

---

### 7.2.4 Imbalance Calculation Formulas

**Low Frequency Response**
```r
calculate_lf_response <- function(df_hz, response_holdings) {
  # Deadband
  deadband <- -0.015  # Hz

  # Droop
  droop <- 0.5  # Hz for full response

  # Total LF holdings
  total_lf <- response_holdings$primary_mw +
              response_holdings$secondary_mw +
              response_holdings$dr_mw +
              response_holdings$dm_mw +
              response_holdings$dc_mw

  # Calculate response
  if (df_hz < deadband) {
    lf_response <- abs(df_hz) / droop * total_lf
  } else {
    lf_response <- 0
  }

  return(lf_response)
}
```

**High Frequency Response**
```r
calculate_hf_response <- function(df_hz, response_holdings) {
  # Deadband
  deadband <- 0.015  # Hz

  # Droop
  droop <- 0.2  # Hz for full response

  # Calculate response
  if (df_hz > deadband) {
    hf_response <- df_hz / droop * response_holdings$high_mw
  } else {
    hf_response <- 0
  }

  return(hf_response)
}
```

**Demand Damping (for imbalance)**
```r
calculate_demand_damping <- function(df_hz, demand_mw) {
  # Damping coefficient
  damping_pct_per_hz <- 2.5  # % per Hz

  # Calculate damping
  demand_damping_mw <- demand_mw * (damping_pct_per_hz / 100) * df_hz

  return(demand_damping_mw)
}
```

**RoCoF Component**
```r
calculate_rocof_component <- function(rocof_hz_s, inertia_gvas) {
  # System frequency
  system_freq <- 50.0  # Hz

  # Formula: P = 2 × H × f0 × df/dt
  rocof_component_mw <- 2 * inertia_gvas * system_freq * rocof_hz_s

  return(rocof_component_mw)
}
```

**Complete Imbalance**
```r
calculate_imbalance <- function(freq_data, system_data, response_holdings) {
  # For each second in the event window
  for (i in 1:nrow(freq_data)) {
    # Frequency deviation
    df_hz <- freq_data$f[i] - 50.0

    # Calculate components
    lf_resp <- calculate_lf_response(df_hz, response_holdings)
    hf_resp <- calculate_hf_response(df_hz, response_holdings)
    damping <- calculate_demand_damping(df_hz, system_data$demand_mw)
    rocof_comp <- calculate_rocof_component(
      freq_data$rocof[i],
      system_data$inertia_gvas
    )

    # Imbalance equation
    imbalance_mw <- -lf_resp - hf_resp - damping + rocof_comp

    freq_data$imbalance_mw[i] <- imbalance_mw
  }

  return(freq_data)
}
```

---

## 7.3 Event Detection Logic

### 7.3.1 SP Boundary Timeline Generation

```r
generate_sp_timeline <- function(start_date, end_date) {
  # Generate all dates in range
  dates <- seq.Date(start_date, end_date, by = "day")

  # For each date, generate 48 SPs
  sp_timeline <- data.table()

  for (date in dates) {
    for (sp in 1:48) {
      # SP start time
      sp_start <- as.POSIXct(date) + (sp - 1) * 1800  # 30 minutes

      sp_timeline <- rbind(sp_timeline, data.table(
        date = date,
        sp = sp,
        boundary_time = sp_start
      ))
    }
  }

  return(sp_timeline)
}
```

### 7.3.2 Event Detection Per Boundary

```r
detect_event_at_boundary <- function(boundary_time, freq_data, params) {
  # Extract ±60 second window
  window_start <- boundary_time - 60
  window_end <- boundary_time + 60

  window_data <- freq_data[
    dtm >= window_start & dtm <= window_end
  ]

  # Validate sufficient data
  if (nrow(window_data) < 100) {  # Expect ~120 seconds
    return(NULL)  # Skip this boundary
  }

  # Calculate metrics
  f_min <- min(window_data$f, na.rm = TRUE)
  f_max <- max(window_data$f, na.rm = TRUE)
  abs_freq_change <- abs(f_max - f_min)

  # Calculate RoCoF
  window_data[, rocof := c(0, diff(f) / diff(as.numeric(dtm)))]
  rocof_p99 <- quantile(abs(window_data$rocof), 0.99, na.rm = TRUE)

  # Detection thresholds (from config)
  delta_f_threshold <- params$delta_f_hz  # 0.1 Hz
  rocof_threshold <- params$rocof_p99_hz_s  # 0.01 Hz/s

  # Event detection
  is_event <- (abs_freq_change >= delta_f_threshold) |
              (rocof_p99 >= rocof_threshold)

  if (!is_event) {
    return(NULL)  # No event detected
  }

  # Classify severity
  category <- classify_severity(abs_freq_change, rocof_p99)

  # Calculate severity score
  severity <- calculate_severity_score(abs_freq_change, rocof_p99)

  # Create event record
  event <- data.table(
    event_id = format(boundary_time, "%Y%m%d_%H%M"),
    boundary_time = boundary_time,
    starting_sp = hour(boundary_time) * 2 + minute(boundary_time) / 30 + 1,
    min_freq_hz = f_min,
    max_freq_hz = f_max,
    abs_freq_change = abs_freq_change,
    rocof_p99 = rocof_p99,
    category = category,
    severity = severity
  )

  return(event)
}
```

### 7.3.3 Complete Detection Pipeline

```r
run_event_detection <- function(freq_data, params, config) {
  # Generate SP timeline
  sp_timeline <- generate_sp_timeline(
    start_date = as.Date(params$start_month),
    end_date = as.Date(params$end_month)
  )

  cat("INFO: Analyzing", nrow(sp_timeline), "SP boundaries\n")

  # Detect events at each boundary
  all_events <- list()

  for (i in 1:nrow(sp_timeline)) {
    boundary <- sp_timeline[i]

    event <- detect_event_at_boundary(
      boundary_time = boundary$boundary_time,
      freq_data = freq_data,
      params = params
    )

    if (!is.null(event)) {
      all_events[[length(all_events) + 1]] <- event
    }
  }

  # Combine results
  events_df <- rbindlist(all_events, fill = TRUE)

  cat("SUCCESS: Detected", nrow(events_df), "events\n")

  # Save results
  output_path <- file.path(
    config$paths$output_reports,
    "frequency_events_detail.csv"
  )
  fwrite(events_df, output_path)

  return(events_df)
}
```

---

## 7.4 Validation & Quality Assurance

### 7.4.1 Data Quality Checks

**Frequency Data Validation**
```r
validate_frequency_data <- function(freq_data) {
  # Check 1: Frequency range
  invalid_freq <- freq_data[f < 47.0 | f > 53.0]
  if (nrow(invalid_freq) > 0) {
    warning("Found ", nrow(invalid_freq), " records with invalid frequency")
  }

  # Check 2: Timestamp continuity
  freq_data[, time_diff := c(NA, diff(as.numeric(dtm)))]
  gaps <- freq_data[time_diff > 10]  # Gaps > 10 seconds
  if (nrow(gaps) > 0) {
    warning("Found ", nrow(gaps), " data gaps")
  }

  # Check 3: Missing values
  missing <- sum(is.na(freq_data$f))
  if (missing > 0) {
    warning("Found ", missing, " missing frequency values")
  }

  return(list(
    valid = (nrow(invalid_freq) == 0) & (missing == 0),
    issues = list(
      invalid_freq = invalid_freq,
      gaps = gaps,
      missing_count = missing
    )
  ))
}
```

**Imbalance Calculation Validation**
```r
validate_imbalance_calculation <- function(imbalance_data, event_info) {
  # Check: Energy balance
  # Imbalance should integrate to match frequency change

  # Simplified check: stabilized imbalance should be reasonable
  stable_period <- imbalance_data[time_rel_s >= 10 & time_rel_s <= 15]
  avg_imbalance <- mean(stable_period$imbalance_mw, na.rm = TRUE)

  # Reasonableness: |Imbalance| should be < 3000 MW (largest generator)
  if (abs(avg_imbalance) > 3000) {
    warning("Event ", event_info$event_id,
            ": Imbalance suspiciously large (",
            round(avg_imbalance), " MW)")
  }

  # Check: Components should sum to imbalance
  calc_imbalance <- -stable_period$lf_response_mw[1] -
                    stable_period$hf_response_mw[1] -
                    stable_period$demand_damping_mw[1] +
                    stable_period$rocof_component_mw[1]

  error <- abs(calc_imbalance - stable_period$imbalance_mw[1])

  if (error > 1.0) {  # > 1 MW error
    warning("Event ", event_info$event_id,
            ": Component sum error = ", round(error, 2), " MW")
  }

  return(list(
    valid = (abs(avg_imbalance) < 3000) & (error < 1.0),
    avg_imbalance = avg_imbalance,
    component_error = error
  ))
}
```

### 7.4.2 Verification Plots

The system generates verification plots for top N events to enable manual validation:

```r
plot_event_verification <- function(event, freq_data, imbalance_data) {
  library(ggplot2)
  library(gridExtra)

  # Plot 1: Frequency + RoCoF
  p1 <- ggplot(freq_data, aes(x = time_rel_s)) +
    geom_line(aes(y = f, color = "Frequency"), size = 1) +
    geom_vline(xintercept = 0, linetype = "dashed") +
    labs(title = paste("Event:", event$event_id),
         x = "Time (s)", y = "Frequency (Hz)")

  # Plot 2: Imbalance Components
  p2 <- ggplot(imbalance_data, aes(x = time_rel_s)) +
    geom_line(aes(y = imbalance_mw, color = "Total Imbalance"), size = 1.2) +
    geom_line(aes(y = -lf_response_mw, color = "LF Response")) +
    geom_line(aes(y = -demand_damping_mw, color = "Demand Damping")) +
    geom_line(aes(y = rocof_component_mw, color = "RoCoF Component")) +
    geom_vline(xintercept = 0, linetype = "dashed") +
    labs(x = "Time (s)", y = "Power (MW)")

  # Combine
  grid.arrange(p1, p2, ncol = 1)
}
```

---

### 7.4.3 Known Limitations & Assumptions

**Limitation 1: System Data Granularity**
```
Assumption: Inertia and demand constant during 30-minute SP
Reality: Both can vary second-by-second
Impact: Imbalance calculation uses nearest SP value
Mitigation: Conservative assumption; errors typically <5%
```

**Limitation 2: Response Holdings**
```
Assumption: Contracted holdings = activated capacity
Reality: Actual activation may differ due to:
  - Service provider availability
  - Technical constraints
  - Droop settings
Impact: Response component may be overestimated
Mitigation: Use monthly average; cross-validate with major events
```

**Limitation 3: Demand Damping Coefficient**
```
Assumption: 2.5% per Hz is constant
Reality: Varies with load composition (motors, lighting, heating)
Impact: ±0.5% uncertainty in damping calculation
Mitigation: Standard NESO value; widely accepted
```

**Limitation 4: Event Detection Scope**
```
Assumption: Only SP boundaries analyzed
Reality: Events can occur anytime
Impact: Mid-SP random events not captured
Mitigation: Explicitly documented scope; focus on preventable events
```

---

**Next**: [Part 8: Interpretation Guide & Business Cases](08_Interpretation_Guide.md)
