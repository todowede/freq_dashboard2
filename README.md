# NESO Frequency Analysis Dashboard

Interactive R Shiny dashboard for analyzing UK grid frequency data from the National Energy System Operator (NESO).

## Features

- **SP Boundary Event Detection** - Detects and classifies frequency disturbances at 30-minute settlement period boundaries
- **System Imbalance Calculation** - Computes power imbalances from frequency deviations using system inertia and response characteristics
- **Demand Analysis with Damping Separation** - Analyzes demand changes at SP boundaries, separating natural frequency damping from market-driven changes
- **Unforeseen Demand Detection** - Identifies unexpected demand changes that exceed forecasting thresholds and statistical models
- **Frequency KPI Monitoring** - Continuous monitoring of frequency quality metrics
- **Frequency Excursion Analysis** - Tracks deviations at 0.1, 0.15, and 0.2 Hz thresholds
- **Response & Holding Analysis** - Evaluates low-frequency and high-frequency system response to disturbances
- **Monthly Trend Analysis** - Aggregates key metrics (imbalance, unforeseen events, excursions) by month for trend visualization
- **Interactive Visualizations** - Real-time frequency and ROCOF plots with date filtering
- **Automated Reporting** - Generation of CSV reports and static PNG plots

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
7. Analyze system response and holding characteristics
8. Analyze demand changes with damping separation
9. Detect unforeseen demand events
10. Calculate system imbalance at SP boundaries
11. Aggregate monthly imbalance statistics
12. Generate monthly unforeseen vs total demand comparison
13. Generate static reports and CSV outputs

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

### System Imbalance Calculation
```yaml
imbalance_calculation:
  calculate_for_red_events_only: false  # Calculate at ALL SP boundaries (not just RED events)
  event_selection:
    mode: "all"                         # Options: "all", "top_n", "severity_filter", "combined"
    max_events: 0                       # Cap number of events (0 = no cap)
  demand_damping_percent_per_hz: 2.5    # Natural demand damping coefficient (2.5% per Hz)
```

**Imbalance Formula:**
```
Imbalance = -LF_response - HF_response - Demand_damping + RoCoF_component
```

Where:
- `LF_response` = Low-frequency response (slow reserves)
- `HF_response` = High-frequency response (inertial/fast reserves)
- `Demand_damping` = Natural load damping (2.5% of demand per Hz)
- `RoCoF_component` = Inertial contribution (2H × RoCoF)

### Unforeseen Demand Detection
```yaml
unforeseen_demand:
  enabled: true
  demand_damping:
    percentage_per_hz: 0.025            # 2.5% of demand per Hz (NESO standard)
    apply_direction: true               # Use frequency trend to determine damping sign
  statistical_threshold:
    sd_multiplier: 2.5                  # Flag if |change - hourly_mean| > k × hourly_SD
  causality:
    demand_threshold_mw: 800            # Threshold for "large" demand change
    freq_threshold_hz: 0.05             # Threshold for "large" frequency change
```

**Unforeseen Component Formula:**
```
Unforeseen = Total_demand_change - Demand_damping
```

An event is flagged as "unforeseen" if:
- `|Unforeseen| - hourly_mean| > 2.5 × hourly_SD`, OR
- Both demand change > 800 MW AND frequency change > 0.05 Hz

## Project Structure

```
freq_dashboard2/
├── main.R                  # Main workflow orchestrator
├── dashboard.R             # Shiny dashboard application
├── setup.R                 # Package installation script
├── config/
│   └── config.yml          # Configuration file
├── R/
│   ├── analysis_demand.R                       # Demand analysis with damping separation
│   ├── analysis_event_detection.R              # SP boundary event detection
│   ├── analysis_frequency_excursion.R          # Frequency excursion analysis
│   ├── analysis_imbalance_calculation.R        # System imbalance calculation at SP boundaries
│   ├── analysis_kpi_monitoring.R               # Frequency KPI monitoring
│   ├── analysis_monthly_imbalance.R            # Monthly imbalance aggregation
│   ├── analysis_monthly_unforeseen_comparison.R # Monthly unforeseen vs total demand comparison
│   ├── analysis_response_holding.R             # System response and holding analysis
│   ├── analysis_unforeseen_demand.R            # Unforeseen demand event detection
│   ├── data_acquistion.R                       # API data downloader
│   ├── data_loader.R                           # Data loading & cleaning
│   ├── frequency_processor.R                   # Per-second data processing
│   ├── reporting.R                             # Static plot generation
│   └── utils.R                                 # Helper functions
└── data/
    ├── input/              # Raw CSV files (fnew-YYYY-M.csv, system_inertia.csv, system_demand.csv)
    ├── processed/          # Processed data (frequency_per_second_with_rocof.csv)
    ├── output/
    │   ├── reports/        # CSV analysis results
    │   ├── plots/          # PNG static plots
    │   └── imbalance/      # Imbalance calculation results (sp_boundary_imbalances.csv)
    └── verification/       # Event verification plots
```

## Dashboard Tabs

### 1. Overview
Configuration parameters and summary statistics

### 2. SP Boundary Events
Browse and filter detected events with severity classification

### 3. System Dynamics
- **Response & Holding Analysis** - System response characteristics (LF/HF response, holding times)
- **Imbalance Calculation** - Power imbalances at SP boundaries
- **Demand vs Frequency** - Scatter plots showing demand-frequency relationships

### 4. Demand Analysis
- **Daily Demand Overview** - Daily demand profiles for selected metrics (ND, TSD, ENGLAND_WALES_DEMAND)
- **Demand Changes at SP Boundaries** - Visualization of demand changes with damping separation
- **Demand vs Frequency Correlation** - Correlation analysis between demand and frequency changes

### 5. Unforeseen Patterns
- **Daily Event Count** - Bar chart of unforeseen demand events by day
- **Event Distribution by Hour** - Hourly distribution showing peak times for unforeseen events
- **Severity Distribution** - Distribution of unforeseen event magnitudes
- **Time Series Analysis** - Detailed view of unforeseen vs damping components over time

### 6. Frequency & ROCOF
Interactive time series plots of frequency and Rate of Change of Frequency

### 7. Frequency KPI
Quality monitoring metrics by settlement period

### 8. Frequency Excursion
Daily excursion counts and durations at 0.1, 0.15, and 0.2 Hz thresholds

### 9. Monthly Trends
Aggregated monthly metrics with 8 analysis panels:
1. **Monthly Quality Metrics** - Frequency quality categories (RED/AMBER/BLUE/GREEN) over time
2. **Monthly Excursion Counts** - Count of excursions by severity level
3. **Monthly Excursion Duration** - Total duration of excursions
4. **Monthly Response Characteristics** - LF/HF response trends
5. **Monthly Average Demand** - Demand trends by metric
6. **Monthly Unforeseen Event Count** - Count of unforeseen demand events
7. **Monthly System Imbalance Level** - Mean, max, and P95 absolute imbalance (MW)
8. **Monthly Unforeseen vs Total Demand Change** - Comparison of total demand changes vs unforeseen (market-driven) component

### 10. Monthly Red Ratio
Static monthly trend plots (legacy view)

## Data Format

### Input Files

**Frequency Data** (`data/input/fnew-YYYY-M.csv`):
- `dtm` or `datetime` - Timestamp
- `f` or `frequency` - Frequency in Hz

Example: `fnew-2025-5.csv`
```csv
dtm,f
2025-05-01 00:00:00,50.012
2025-05-01 00:00:01,50.015
...
```

**System Inertia Data** (`data/input/system_inertia.csv`):
- `dtm_sec` - Timestamp (UTC)
- `inertia_gvas` - System inertia in GVA·s

**System Demand Data** (`data/input/system_demand.csv`):
- `SETTLEMENT_DATE`, `SETTLEMENT_PERIOD` - Time identifiers
- `ND` - National Demand (MW)
- `TSD` - Transmission System Demand (MW)
- `ENGLAND_WALES_DEMAND` - England & Wales Demand (MW)

### Output Files

**Analysis Results** (`data/output/reports/`):
- `sp_boundary_events.csv` - Detected frequency events at SP boundaries
- `frequency_kpi_by_sp.csv` - Frequency quality metrics per settlement period
- `frequency_excursion_daily.csv` - Daily excursion counts and durations
- `system_dynamics_review.csv` - System response and holding characteristics
- `demand_changes.csv` - Demand changes at SP boundaries with damping separation
- `unforeseen_demand_events.csv` - Unforeseen demand events with statistical flags
- `monthly_excursion_summary.csv` - Monthly aggregated excursion statistics
- `monthly_imbalance_summary.csv` - Monthly aggregated imbalance statistics
- `monthly_unforeseen_comparison.csv` - Monthly comparison of total vs unforeseen demand changes

**Imbalance Data** (`data/output/imbalance/`):
- `sp_boundary_imbalances.csv` - Second-by-second imbalance calculations at SP boundaries (182,840 seconds)

**Static Plots** (`data/output/plots/`):
- Various PNG files showing monthly trends and summaries

## Key Concepts

### System Imbalance
System imbalance represents the mismatch between generation and demand that causes frequency deviations. The analysis calculates imbalance at each Settlement Period (SP) boundary using:

```
Imbalance = -LF_response - HF_response - Demand_damping + RoCoF_component
```

**Physical Interpretation:**
- **Negative imbalance** = Generation deficit (demand > generation) → frequency drops
- **Positive imbalance** = Generation excess (generation > demand) → frequency rises
- Typical values: 100-500 MW for normal operation, up to 1000+ MW for major disturbances

### Demand Damping
Natural load response to frequency changes. As frequency drops, demand naturally decreases (motors slow down, heating elements draw less power). NESO uses **2.5% per Hz** as the standard damping coefficient.

```
Damping = Demand × 0.025 × (f_end - f_start)
```

**Example:** If demand is 40,000 MW and frequency drops 0.1 Hz:
- Damping = 40,000 × 0.025 × (-0.1) = -100 MW (demand reduces by 100 MW)

### Unforeseen Demand Changes: Detailed Explanation

#### What is "Unforeseen Demand"?

Unforeseen demand changes represent **market-driven demand changes at SP boundaries that were NOT predicted in the trading process**. These are demand deviations that cannot be explained by the natural physical response of the system to frequency changes (demand damping).

#### The UK Electricity Market and Forecasting

**How the Market Works:**

1. **Day-Ahead Trading (Gate Closure):** Market participants (suppliers, generators, traders) submit forecasts and trading positions for each 30-minute Settlement Period (SP) typically 1 hour before real-time.

2. **Contract Positions:** Based on these forecasts, they establish:
   - **Generation schedules:** How much each power plant will produce
   - **Demand forecasts:** Expected consumption for each SP
   - **Import/Export schedules:** Cross-border flows

3. **Physical Reality at SP Boundary:** When the SP boundary arrives (e.g., 14:00:00), the actual demand may differ from the forecast due to:
   - Weather changes (temperature affecting heating/cooling)
   - Industrial load variations
   - Behavioral patterns (TV pickup events)
   - Forecast model errors

4. **The Gap = Imbalance:** The difference between forecasted and actual demand creates a **power imbalance** that NESO must manage in real-time using balancing services.

#### Why Unforeseen Demand Relates to Forecasting Errors

**The Critical Connection:**

At each SP boundary (e.g., 14:00:00 → 14:00:01), we observe a **step change in demand**. This step change has two components:

```
Total_demand_change = Market_component + Damping_component
```

**Component 1: Damping Component (Physical, Predictable)**
- This is the **natural load response to frequency changes**
- If frequency drops 0.1 Hz, demand automatically decreases by ~2.5% × Demand × 0.1 Hz
- This is a **physical phenomenon**, not a market decision
- It happens automatically due to the relationship between voltage, frequency, and power consumption
- **This is predictable and should NOT cause system imbalance**

**Component 2: Market Component (Unforeseen)**
- This is the **change in underlying demand** independent of frequency
- Represents the difference between:
  - What market participants forecasted would happen
  - What actually happened in the physical system
- **This IS a forecasting error and DOES cause system imbalance**

**The Formula:**
```
Unforeseen_component = Total_demand_change - Demand_damping
                     = Market_driven_change
                     = Forecasting_error
```

#### Step-by-Step Example: How Unforeseen Demand Reveals Forecasting Errors

**Scenario:** SP 28 boundary (13:30 → 14:00)

**Market Forecast (submitted at Gate Closure):**
- Forecasted demand at 14:00:00: **40,000 MW**
- Generators scheduled to produce: **40,000 MW**
- Expected system to be balanced

**What Actually Happened:**

**At 13:59:55 (end of SP 28):**
- Frequency: 49.95 Hz (below nominal)
- Measured demand: 39,800 MW

**At 14:00:05 (start of SP 29):**
- Frequency: 50.02 Hz (above nominal)
- Measured demand: 40,600 MW

**Observed Change:**
- Frequency change: +0.07 Hz (from 49.95 to 50.02)
- Demand change: +800 MW (from 39,800 to 40,600)

**Question:** Is this 800 MW demand increase unforeseen, or just natural damping?

**Analysis:**

**Step 1: Calculate Natural Damping**
```
Damping = 40,000 MW × 0.025 (per Hz) × 0.07 Hz
        = 70 MW

Since frequency INCREASED (+0.07 Hz), demand should naturally INCREASE by 70 MW
```

**Step 2: Calculate Unforeseen Component**
```
Unforeseen = Total_change - Damping
           = 800 MW - 70 MW
           = 730 MW
```

**Step 3: Interpret the Result**

**The 730 MW unforeseen component means:**
- Market participants forecasted demand would be ~40,000 MW at 14:00
- Actual underlying demand (excluding frequency effects) was ~40,730 MW
- **This is a 730 MW forecasting error**

**What Caused This?**
Possible reasons:
1. **Weather forecast error:** Temperature was higher than predicted, increasing air conditioning load
2. **Industrial load variation:** A large factory increased production unexpectedly
3. **Behavioral patterns:** More people than expected turned on appliances at 14:00
4. **Model errors:** Demand forecasting models didn't capture the true pattern

#### Why This Matters for System Operation

**1. System Imbalance Creation:**
- Forecasting errors directly create **power imbalances**
- If demand is 730 MW higher than forecast, and generation was scheduled based on forecast:
  - **Generation deficit of 730 MW** → frequency would drop
  - NESO must activate reserve services to balance
  - Costs are passed to market participants via imbalance charges

**2. Frequency Impact:**
- Unforeseen demand changes are the **root cause** of many frequency deviations
- The larger the forecasting error, the larger the frequency excursion
- Better forecasting = more stable frequency

**3. Balancing Cost:**
- Market participants pay **imbalance prices** for forecast errors
- Unforeseen demand analysis identifies which SPs have high forecasting uncertainty
- Helps NESO understand:
  - When forecast errors are largest (time of day patterns)
  - Which demand metrics are hardest to predict
  - Whether forecast quality is improving or degrading

**4. Distinguishing Market from Physical Effects:**
- Without separating damping, we can't tell:
  - Did demand change because the market got it wrong? (unforeseen)
  - Or did demand change because frequency changed? (damping)
- Only unforeseen component reveals **true market forecasting quality**

#### What the Data Shows: ~100% Unforeseen Ratio

**Typical Finding:** Monthly unforeseen ratio ≈ 100%

**What This Means:**
```
Unforeseen / Total_change ≈ 100%
```

**Interpretation:**
- Almost ALL demand changes at SP boundaries are market-driven (unforeseen)
- Natural frequency damping contributes very little (~0-5%)
- This tells us:
  1. **Frequency changes at SP boundaries are typically small** (0-0.05 Hz)
  2. **Demand changes are primarily due to forecast errors**, not frequency response
  3. **Market forecasting is the dominant driver** of SP boundary demand changes

**Physical Explanation:**
- SP boundaries occur every 30 minutes at fixed times (00:00, 00:30, 01:00, etc.)
- These times are **arbitrary** from a frequency perspective
- Frequency doesn't "know" when SP boundaries occur
- Therefore, frequency is usually in a relatively stable state at SP boundaries
- Most demand change is the step from "old forecast" to "new forecast"
- This step is a **market artifact** (change in contracted positions), not a physical frequency response

#### Detection Logic and Thresholds

**Formula:**
```
Unforeseen_component = Total_demand_change - Demand_damping
```

**An unforeseen event is flagged when either condition is met:**

**Condition 1: Statistical Outlier**
```
|Unforeseen - hourly_mean| > 2.5 × hourly_SD
```
- Compares unforeseen component to typical hourly variations
- Flags if deviation is more than 2.5 standard deviations from mean
- Identifies **statistically unusual** forecast errors

**Condition 2: Causality Threshold**
```
|Demand_change| > 800 MW  AND  |Frequency_change| > 0.05 Hz
```
- Flags **large concurrent changes** in both demand and frequency
- Indicates significant system disturbance
- Suggests **major forecasting error or unexpected event**

#### Examples of Unforeseen Events

**Example 1: Weather Forecast Error**
- Forecast: 15°C at 17:00
- Actual: 10°C at 17:00
- Result: 500 MW higher heating demand than forecast
- Type: Unforeseen demand increase
- Impact: Generation deficit → frequency drop → reserve activation

**Example 2: TV Pickup Event (Underestimated)**
- Forecast: World Cup final at 20:00, expected 800 MW pickup at halftime
- Actual: 1,200 MW pickup (higher viewership than expected)
- Result: 400 MW unforeseen increase
- Type: Behavioral forecasting error

**Example 3: Industrial Load Trip**
- Forecast: Steel mill operating normally (250 MW load)
- Actual: Steel mill tripped at SP boundary (0 MW load)
- Result: 250 MW unforeseen decrease
- Type: Sudden load change
- Impact: Generation excess → frequency rise

#### Summary: Why Unforeseen Demand = Forecasting Error

1. **Market participants forecast demand** for each SP
2. **Generation is scheduled** to match these forecasts
3. **Actual demand differs** from forecast due to various factors
4. **The difference (after removing natural damping) is the forecasting error**
5. **This forecasting error creates system imbalance** that NESO must manage
6. **Unforeseen component quantifies this error**, separating it from predictable physical responses
7. **High unforeseen events indicate poor forecast quality** for that particular SP
8. **Monitoring unforeseen patterns helps improve forecasting** and reduce system costs

### System Response Components
The analysis separates system response into two categories:

1. **Low-Frequency (LF) Response** (0-10 seconds)
   - Primary frequency response from governors
   - Fast reserve services
   - Measured as frequency stabilization in first 10 seconds

2. **High-Frequency (HF) Response** (10-30 seconds)
   - Secondary frequency response
   - Additional reserve deployment
   - Measured as continued frequency recovery

### Settlement Period (SP) Boundaries
The UK electricity market operates in 30-minute settlement periods. Each day has 48 SPs:
- SP 1: 00:00-00:30
- SP 2: 00:30-01:00
- ...
- SP 48: 23:30-00:00

Market participants submit demand forecasts and generation schedules for each SP. Deviations from these forecasts at SP boundaries create imbalances that must be managed by the system operator.

## Usage Examples

### Running Individual Analysis Steps

```bash
# Calculate system imbalance at all SP boundaries (not just RED events)
Rscript main.R imbalance_calculation

# Generate monthly imbalance aggregation
Rscript main.R monthly_imbalance

# Detect unforeseen demand events
Rscript main.R unforeseen_demand

# Generate monthly unforeseen vs total demand comparison
Rscript main.R monthly_unforeseen_comparison

# Run complete demand analysis pipeline
Rscript main.R demand_analysis unforeseen_demand
```

### Analyzing Specific Time Periods

Edit `config/config.yml`:
```yaml
parameters:
  start_month: "2025-05"
  end_month: "2025-08"
```

Then run the full pipeline:
```bash
Rscript main.R
```

### Adjusting Imbalance Calculation Scope

To calculate imbalance only for RED events (high severity):
```yaml
imbalance_calculation:
  calculate_for_red_events_only: true
  event_selection:
    mode: "severity_filter"
    min_severity: 5
```

To calculate for all SP boundaries (recommended for comprehensive analysis):
```yaml
imbalance_calculation:
  calculate_for_red_events_only: false
  event_selection:
    mode: "all"
    max_events: 0  # 0 = no cap
```

### Customizing Unforeseen Detection Sensitivity

More sensitive (flag more events):
```yaml
unforeseen_demand:
  statistical_threshold:
    sd_multiplier: 2.0  # Lower threshold
  causality:
    demand_threshold_mw: 500  # Lower threshold
```

Less sensitive (flag only major events):
```yaml
unforeseen_demand:
  statistical_threshold:
    sd_multiplier: 3.0  # Higher threshold
  causality:
    demand_threshold_mw: 1000  # Higher threshold
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
