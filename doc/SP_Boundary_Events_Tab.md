# SP Boundary Events Tab Documentation

## Overview

The SP Boundary Events tab provides detailed analysis of frequency disturbances that occur at Settlement Period (SP) boundaries. It contains three sub-tabs for exploring events through different lenses: Event Table, Event Plots, and Imbalance.

---

## Sub-Tab 1: Event Table

### Purpose
Displays a filterable table of all detected SP boundary events with key characteristics.

### Features

#### 1. Filter Events Section
Controls to narrow down the events displayed:

- **Select Category**
  - Dropdown with options: All, RED, TUNING, GREEN
  - Filters events by classification severity
  - Default: Shows all categories

- **Date Range**
  - Slider control with start and end dates
  - Filters events within selected time period
  - Displays selected range above slider

#### 2. Frequency Event Details Table
Data table showing all filtered events with the following columns:

| Column | Description | Unit |
|--------|-------------|------|
| **date** | Event date | YYYY-MM-DD |
| **starting_sp** | Settlement Period number when event occurred | 1-48 |
| **boundary_time** | Exact timestamp of SP boundary | HH:MM:SS |
| **min_f** | Minimum frequency during event | Hz |
| **max_f** | Maximum frequency during event | Hz |
| **abs_freq_change** | Absolute frequency change (Δf) | Hz |
| **rocof_p99** | 99th percentile Rate of Change of Frequency | Hz/s |
| **trend** | Frequency direction (Up/Down) | - |
| **event_timing** | Classification by frequency recovery timing | - |
| **category** | Event severity (RED/TUNING/GREEN) | - |
| **severity** | Numerical severity score | - |

### Data Source
- Input: `data/processed/sp_boundary_events_enriched.csv`
- Generated during SP boundary detection step

### Interpretation
- **RED events**: Significant disturbances requiring investigation
- **TUNING events**: Controlled frequency adjustments
- **GREEN events**: Normal frequency variations
- Higher severity scores indicate larger frequency disturbances
- Trend shows whether frequency was rising or falling at the boundary

### Business Value
- Quickly identify problematic SP boundaries
- Filter events by severity for targeted analysis
- Export event list for compliance reporting
- Track event frequency over time periods

---

## Sub-Tab 2: Event Plots

### Purpose
Visualize frequency behavior around selected SP boundary events through verification plots.

### Features

#### 1. Plot Selection Options
Controls how events are selected for plotting:

- **Selection Strategy**
  - Dropdown: Worst N by Severity
  - Selects events with highest severity scores

- **Number of Events (N)**
  - Numeric input (default: 10)
  - Determines how many events to plot

- **Sort By**
  - Dropdown: Severity Score
  - Orders events by severity for selection

- **Load Plots Button**
  - Triggers plot generation with selected parameters

#### 2. Verification Plots Gallery
Displays individual frequency time series plots for each selected event.

**Each Plot Shows:**
- **Title Bar**: Event metadata
  - Event number (e.g., "Event #1: 2025-05-29 19:00 (SP 38)")
  - Frequency change (Δf = 0.186 Hz)
  - ROCOF value (p99 ROCOF = -0.051700 Hz/s)
  - Trend direction
  - Severity score

- **X-Axis**: Time (HH:MM:SS format)
  - Shows ±15 seconds around SP boundary

- **Y-Axis**: Frequency (Hz)
  - Typically ranges around 49.9-50.1 Hz

- **Visual Elements**:
  - Blue line: Frequency time series
  - Red dashed vertical line: SP boundary timestamp
  - Green triangle marker: Event start point

### Data Source
- Input: `data/processed/frequency_per_second_with_rocof.csv`
- Time window: ±15 seconds around each SP boundary
- Event metadata from: `data/processed/sp_boundary_events_enriched.csv`

### Interpretation
- The red dashed line marks the exact SP boundary (00:00 or 00:30)
- Frequency drop before boundary indicates event caused by SP transition
- Steep slopes indicate high ROCOF (rapid frequency change)
- Recovery pattern shows system response effectiveness

### Business Value
- Visual verification of automated event detection
- Understand event context (pre/post boundary behavior)
- Identify patterns in frequency disturbances
- Support root cause analysis investigations
- Quality assurance for event classification

---

## Sub-Tab 3: Imbalance

### Purpose
Analyze power imbalance calculations for individual SP boundary events, showing both frequency behavior and calculated MW imbalance.

### Features

#### 1. Select Event to Analyze
Controls for choosing which event to visualize:

- **Filter by Category**
  - Dropdown: Top 10 Severity
  - Pre-filters events by severity ranking

- **Filter by Date Range**
  - Start and end date inputs
  - Narrows event list to specific time period

- **Select Event**
  - Dropdown showing individual events with timestamp and severity
  - Format: "YYYY-MM-DD HH:MM:SS (SP ##)"

- **Load Event Data Button**
  - Triggers plot generation for selected event

#### 2. Frequency Event (±15 seconds around SP boundary)
Dual-axis plot showing frequency and ROCOF behavior.

**Left Y-Axis**: Frequency (Hz)
- Blue line showing frequency time series
- Typically ranges 49.9-50.1 Hz

**Right Y-Axis**: RoCoF (Hz/s)
- Orange line showing Rate of Change of Frequency
- Indicates speed of frequency change

**X-Axis**: Time
- Shows ±15 second window around SP boundary

**Visual Elements**:
- Red dashed vertical line: SP Boundary timestamp
- Green triangle: Event detection point
- Tooltip on hover: Shows exact timestamp and values

**Title Bar Shows**:
- Event date and SP number
- Frequency change (Δf)
- ROCOF magnitude
- Trend direction
- Severity score

### Interpretation
- When blue line drops and orange line goes negative: Under-frequency event with rapid decline
- SP boundary (red line) marks the transition point
- ROCOF magnitude shows how quickly frequency changed
- Frequency recovery after the event indicates system stability

#### 3. Power Imbalance Time Series (±15 seconds around SP boundary)
Shows calculated power imbalance derived from frequency changes.

**Y-Axis**: Power Imbalance (MW)
- Negative values: Generation deficit (under-frequency)
- Positive values: Generation surplus (over-frequency)

**X-Axis**: Time
- Same ±15 second window as frequency plot

**Visual Elements**:
- Red line: Calculated imbalance time series
- Red dashed vertical line: SP Boundary

**Title Bar Shows**:
- Event identification (date and SP)

### Calculation Method
Power imbalance is calculated using:
- **Frequency deviation**: Difference from 50 Hz nominal
- **System inertia**: GB system inertia at event time (GVA·s)
- **Natural damping**: System load damping coefficient
- **Time derivative**: ROCOF values

Formula: `Imbalance (MW) = -[2H × df/dt + D × Δf]`

Where:
- H = System inertia (GVA·s)
- df/dt = ROCOF (Hz/s)
- D = Damping factor
- Δf = Frequency deviation from 50 Hz

### Data Source
- Input: `data/output/imbalance/sp_boundary_imbalance_results.csv`
- Generated during imbalance calculation step
- Uses system inertia and demand data for calculations

### Interpretation
- **Negative imbalance**: System experienced generation shortfall
  - Frequency drops as load exceeds generation
  - Typical at start of high-demand SPs

- **Positive imbalance**: System experienced generation excess
  - Frequency rises as generation exceeds load
  - Can occur when large load suddenly drops

- **Magnitude**: Shows MW mismatch between generation and demand
  - Larger values indicate more significant disturbances
  - Helps quantify the size of the event

- **Recovery pattern**: How quickly imbalance returns to zero
  - Fast recovery indicates good response holdings
  - Slow recovery may indicate insufficient reserves

### Business Value
- **Quantify event severity** in MW terms (operational language)
- **Validate balancing actions** taken during events
- **Assess response performance** through recovery patterns
- **Support post-event analysis** with quantitative data
- **Identify trends** in generation-demand mismatches at SP boundaries
- **Compliance reporting** for frequency event investigations

---

## Cross-Feature Workflow

### Typical Analysis Flow
1. **Event Table**: Filter events by category and date to identify interesting cases
2. **Event Plots**: Visualize top severity events to understand frequency patterns
3. **Imbalance**: Deep-dive into specific events to quantify MW imbalance and assess system response

### Use Cases

#### Use Case 1: Investigating High Severity Events
1. Filter Event Table to show only RED events in last month
2. Note events with highest severity scores
3. Load verification plots in Event Plots tab
4. Select specific event in Imbalance tab for detailed MW analysis

#### Use Case 2: Monthly Compliance Reporting
1. Set date range to reporting month in Event Table
2. Export filtered event list
3. Generate verification plots for top 10 events
4. Analyze imbalance calculations for any events exceeding thresholds

#### Use Case 3: Root Cause Investigation
1. Identify event of interest from Event Table (date/time)
2. Check verification plot to confirm frequency behavior
3. Review imbalance plot to see:
   - Magnitude of generation-demand mismatch
   - Speed of system response
   - Recovery effectiveness

---

## Technical Details

### Event Detection
- Events detected by analyzing frequency changes at SP boundaries (HH:00:00 and HH:30:00)
- Classification based on frequency deviation magnitude and ROCOF
- Severity scoring considers multiple factors (Δf, ROCOF, trend, timing)

### Time Windows
- All plots use ±15 second windows around SP boundaries
- Ensures context before and after the transition is visible
- Sufficient time to observe frequency recovery

### Data Quality
- 1-second resolution frequency data
- ROCOF calculated using appropriate filtering
- Imbalance calculations use actual system parameters (inertia, demand)

---

## Best Practices

1. **Start broad, narrow down**: Use Event Table filters before detailed plotting
2. **Verify visually**: Always check Event Plots before trusting automated classification
3. **Understand context**: Review both frequency and imbalance plots for complete picture
4. **Export data**: Use table export for offline analysis and reporting
5. **Track patterns**: Look for recurring issues at specific times or days

---

## Troubleshooting

### No events showing in table
- Check date range includes actual data dates
- Verify category filter is not excluding all events
- Confirm SP boundary detection step completed successfully

### Plots not loading
- Ensure "Load Plots" button clicked after changing parameters
- Check Number of Events (N) is reasonable (1-50)
- Verify frequency data files exist in `data/processed/`

### Imbalance values seem incorrect
- Verify system data (inertia, demand) loaded correctly
- Check event timestamp matches available system parameter data
- Review console output for calculation warnings
