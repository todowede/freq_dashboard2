# Overview Tab Documentation

## Feature Overview

The **Overview Tab** serves as the dashboard's command center, providing a consolidated view of system configuration, data coverage, and high-level performance metrics. It enables users to quickly assess system health across multiple dimensions: frequency events, quality indicators, and demand forecasting accuracy.

**Purpose:**
- Display active analysis parameters and thresholds
- Enable flexible time period filtering for analysis
- Present executive-level summaries of three key performance areas
- Provide at-a-glance insights into system stability and forecasting quality

---

## Section 1: Configuration Parameters

### Visual Description
A three-column information panel displaying the operational parameters that govern the analysis pipeline.

### Components

#### Column 1: Event Detection Thresholds
Defines the criteria for categorizing Settlement Period (SP) boundary events based on frequency disturbance severity.

**Parameters:**

1. **Analysis Window**: ±15 seconds around SP boundary
   - **Purpose**: Defines the time window for detecting frequency disturbances
   - **Technical Detail**: Analyzes 15 seconds before and after each 30-minute SP boundary

2. **RED Criteria**: |Δf| > 0.1 Hz AND p99|ROCOF| > 0.01 Hz/s
   - **Interpretation**: Significant frequency disturbance requiring investigation
   - **Components**:
     - Absolute frequency change exceeds 0.1 Hz
     - 99th percentile Rate of Change of Frequency exceeds 0.01 Hz/s
   - **Both conditions must be met** (AND logic)

3. **TUNING Criteria**: Mean |ROCOF| < 0.005 Hz/s AND SD(ROCOF) < 0.003 Hz/s
   - **Interpretation**: Slow, controlled frequency adjustment (intentional system tuning)
   - **Characteristics**: Smooth, gradual changes with low variability

4. **GREEN Criteria**: All other events
   - **Interpretation**: Normal operation within acceptable parameters

**Data Source**: Configuration file (`config/config.yml`)

#### Column 2: Frequency KPI Thresholds
Defines quality levels for per-second frequency readings based on deviation from nominal (50 Hz).

**Thresholds:**

1. **RED**: Freq deviation > 0.15 Hz OR |ROCOF| > 0.02 Hz/s
   - **Interpretation**: Critical quality concern
   - **Operational Impact**: May trigger automatic load shedding or generation response

2. **AMBER**: Freq deviation > 0.125 Hz
   - **Interpretation**: Warning level - approaching limits
   - **Operational Impact**: Increased monitoring required

3. **BLUE**: Freq deviation > 0.1 Hz
   - **Interpretation**: Elevated deviation - watch level
   - **Operational Impact**: Minor concern, trackable trend

4. **GREEN**: All other readings (acceptable performance)
   - **Interpretation**: Within normal operating envelope
   - **Frequency range**: Typically 49.9 - 50.1 Hz

**Data Source**: Configuration file (`config/config.yml`)

**Business Value**: These thresholds align with Grid Code requirements and operational standards, ensuring the dashboard highlights deviations that require operator attention.

#### Column 3: Data Coverage
Displays the extent and completeness of the input dataset.

**Fields:**

1. **Data Source**: File pattern for frequency data
   - **Example**: `data/input/fnew-*.csv`
   - **Format**: Per-second frequency measurements

2. **Start Date**: Earliest date in dataset
   - **Example**: 2024-01
   - **Derived from**: Filename parsing of input files

3. **End Date**: Latest date in dataset
   - **Example**: 2025-09

4. **Total Months**: Count of monthly data files
   - **Example**: 21 months
   - **Calculation**: Number of `fnew-YYYY-M.csv` files found

**Data Source**: Dynamically scanned from `data/input/` directory

**Business Value**: Provides immediate visibility into data availability, helping users understand the temporal scope of analysis results.

---

## Section 2: Filter Summary Period

### Visual Description
An interactive filtering panel with date range or monthly selection options.

### Components

**Filter Mode Selection:**
- **Date Range**: Select custom start and end dates
- **Month**: Select a specific month from dropdown

**Controls:**
- **Start Date**: Calendar picker (when Date Range mode selected)
- **End Date**: Calendar picker (when Date Range mode selected)
- **Update Summary Button**: Applies filter and recalculates all summary statistics

### Methodology

**Data Processing:**
1. User selects filter mode (Date Range or Month)
2. User specifies time period parameters
3. User clicks "Update Summary"
4. Dashboard filters three data sources:
   - SP boundary events (`data/output/reports/sp_boundary_events.csv`)
   - Frequency KPI data (`data/output/reports/frequency_kpi_by_sp.csv`)
   - Unforeseen demand events (`data/output/reports/unforeseen_demand_events.csv`)
5. Summary boxes update with filtered statistics

**Inputs:**
- User-selected date range or month
- Unfiltered event, KPI, and unforeseen demand datasets

**Outputs:**
- Filtered datasets passed to three summary boxes below
- Updated statistics reflecting selected time period

### Interpretation Guide

**Use Cases:**
1. **Monthly Performance Review**: Select specific month to assess that period's performance
2. **Incident Analysis**: Narrow to specific date range when investigating known issues
3. **Trend Comparison**: Change filter to compare different time periods
4. **Report Generation**: Filter to reporting period for executive summaries

**Business Value**: Enables flexible temporal analysis without re-running the entire processing pipeline, supporting both operational reviews and incident investigations.

---

## Section 3: SP Boundary Events Summary

### Visual Description
Red-bordered box displaying categorized event counts and percentages.

### Metrics

1. **Total Events**: Count of all SP boundaries analyzed
   - **Example**: 1,488 boundaries
   - **Context**: 31 days × 48 SP/day = 1,488 total possible boundaries

2. **RED**: Count and percentage of significant disturbances
   - **Example**: 46 (3.1%)
   - **Interpretation**: 46 SP boundaries had significant frequency events
   - **Operational Meaning**: ~1.5 events per day requiring investigation

3. **TUNING**: Count and percentage of controlled adjustments
   - **Example**: 1,095 (73.6%)
   - **Interpretation**: Majority of boundaries show intentional frequency management
   - **Operational Meaning**: System control is actively managing frequency

4. **GREEN**: Count and percentage of normal operations
   - **Example**: 347 (23.3%)
   - **Interpretation**: Boundaries with minimal frequency disturbance

### Data Source
**File**: `data/output/reports/sp_boundary_events.csv`

**Generated By**: Event detection module (`R/analysis_event_detection.R`)

**Processing Steps:**
1. Analyze ±15-second window around each SP boundary
2. Calculate frequency deviation and ROCOF statistics
3. Apply classification thresholds (RED/TUNING/GREEN)
4. Aggregate counts by category for filtered period

### Interpretation Guide

**Healthy System Indicators:**
- RED events < 5%
- TUNING events 60-80% (shows active management)
- GREEN events 15-35%

**Concerning Patterns:**
- RED events > 10%: Indicates frequent system disturbances
- TUNING events < 40%: May indicate insufficient active management
- GREEN events > 50%: Could mask underlying issues (not enough sensitivity)

### Business Value

**Operational Benefits:**
- **Performance Monitoring**: Track frequency stability over time
- **Incident Prioritization**: RED events require immediate review
- **Resource Planning**: High TUNING % indicates high control usage
- **Regulatory Compliance**: Evidence of Grid Code adherence

**Decision Support:**
- Identify periods of system stress
- Assess effectiveness of frequency control measures
- Support capacity planning for balancing services

---

## Section 4: Frequency KPI Summary

### Visual Description
Cyan-bordered box displaying quality distribution of per-second frequency readings.

### Metrics

1. **Settlement Periods**: Count of analyzed settlement periods
   - **Example**: 1,488 SPs
   - **Note**: Each SP contains ~1,800 seconds (30 minutes)

2. **Average Quality Distribution**: Percentage of time spent in each quality band
   - **RED**: 1.40% (critical deviations)
   - **AMBER**: 4.11% (warning level)
   - **BLUE**: 12.44% (elevated deviations)
   - **GREEN**: 82.06% (acceptable performance)

### Data Source
**File**: `data/output/reports/frequency_kpi_by_sp.csv`

**Generated By**: KPI monitoring module (`R/analysis_kpi_monitoring.R`)

**Processing Steps:**
1. Read per-second frequency data (`data/processed/frequency_per_second_with_rocof.csv`)
2. For each second, calculate deviation from 50 Hz
3. Classify second into RED/AMBER/BLUE/GREEN based on thresholds
4. Aggregate by SP: calculate percentage of seconds in each quality band
5. Average across all SPs in filtered period

### Interpretation Guide

**Understanding Percentages:**
- Values represent **percentage of time** (seconds) in each quality band
- Sum of all percentages = 100%
- **Example**: 1.40% RED means ~25 seconds per SP in critical state

**Calculation Example:**
```
SP 1 (1,800 seconds):
- RED: 25 seconds → 1.39%
- AMBER: 75 seconds → 4.17%
- BLUE: 220 seconds → 12.22%
- GREEN: 1,480 seconds → 82.22%

Average across all SPs in period = displayed percentages
```

**Healthy System Indicators:**
- GREEN > 80%
- RED < 2%
- AMBER + BLUE < 15%

**Concerning Patterns:**
- RED > 5%: Frequent critical deviations
- GREEN < 70%: System struggling to maintain nominal frequency
- AMBER + BLUE > 25%: Persistent elevated deviations

### Business Value

**Operational Benefits:**
- **Quality Tracking**: Continuous monitoring of frequency stability
- **Performance Trends**: Compare quality across months/seasons
- **Early Warning**: Gradual deterioration visible before critical events
- **Benchmarking**: Compare periods or compare to industry standards

**Regulatory Compliance:**
- Evidence of frequency quality for regulatory reporting
- Demonstrates adherence to Grid Code performance standards
- Supports license compliance documentation

**Cost Implications:**
- High AMBER/BLUE %: May indicate need for more balancing services
- Persistent RED: Could trigger penalties or regulatory action
- Trend analysis: Supports investment decisions for control systems

---

## Section 5: Unforeseen Demand Events Summary

### Visual Description
Green-bordered box displaying unforeseen demand change detection statistics.

### Metrics

1. **SP Boundaries**: Count of analyzed settlement period boundaries
   - **Example**: 1,488 boundaries

2. **Total Unforeseen Events**: Count and percentage of unforeseen demand changes
   - **Example**: 29 (1.9%)
   - **Interpretation**: 29 SP boundaries had unexpected demand changes that cannot be explained by natural frequency damping

3. **Events by Metric**: Breakdown of unforeseen events by demand measure
   - **ND (National Demand)**: 12 events
   - **TSD (Transmission System Demand)**: 17 events

### Data Source
**File**: `data/output/reports/unforeseen_demand_events.csv`

**Generated By**: Unforeseen demand module (`R/analysis_unforeseen_demand.R`)

**Processing Steps:**
1. For each SP boundary, calculate total demand change
2. Calculate expected demand damping (2.5% per Hz frequency change)
3. Subtract damping from total change to get "unforeseen" component
4. Flag as unforeseen event if:
   - **Statistical outlier**: |Unforeseen - hourly_mean| > 2.5 × hourly_SD
   - **OR Causality threshold**: |Demand_change| > 800 MW AND |Freq_change| > 0.05 Hz
5. Count flagged events by metric

### Interpretation Guide

**Understanding Unforeseen Demand:**

**What It Represents:**
- Market-driven demand changes not predicted in forecasts
- Difference between actual demand and what was contracted/scheduled
- Essentially, **forecasting errors** that create system imbalance

**Physical vs Market Components:**
```
Total_demand_change = Market_component + Physical_component
                    = Unforeseen + Demand_damping

Where:
- Demand_damping = Predictable response to frequency (2.5% per Hz)
- Unforeseen = Forecasting error (unpredictable market-driven)
```

**Why It Matters:**
- Unforeseen changes create power imbalances
- Imbalances must be corrected by NESO using balancing services
- Costs passed to market participants via imbalance charges

**Healthy System Indicators:**
- Unforeseen events < 5% of SP boundaries
- Similar counts across ND and TSD (consistency)
- Random distribution (not clustered in specific hours)

**Concerning Patterns:**
- Unforeseen events > 10%: Systematic forecasting issues
- Large discrepancy between ND and TSD: Data quality concerns
- Clustering in specific times: Predictable forecast weakness

### Calculation Example

**Scenario**: SP 28 → SP 29 (13:30 → 14:00)

**Observed:**
- Demand change: +800 MW
- Frequency change: +0.07 Hz

**Analysis:**
```
Natural damping = 40,000 MW × 0.025 × 0.07 Hz = 70 MW
Unforeseen component = 800 MW - 70 MW = 730 MW
```

**Interpretation:**
- 70 MW change explained by physics (frequency damping)
- 730 MW change is market-driven (forecasting error)
- This represents a 730 MW gap between forecast and actual demand

### Business Value

**For NESO (System Operator):**
- **Forecasting Quality Assessment**: Identify when/where forecasts are weakest
- **Reserve Optimization**: Better predict when extra reserves needed
- **Cost Driver Analysis**: Understand root causes of balancing costs
- **Operational Planning**: Anticipate challenging periods

**For Market Participants:**
- **Forecast Improvement**: Identify systematic errors in demand predictions
- **Cost Reduction**: Better forecasts → lower imbalance charges
- **Competitive Advantage**: Accurate forecasting reduces financial risk

**System-Wide Benefits:**
- **Stability**: Better forecasting → smaller imbalances → more stable frequency
- **Efficiency**: Reduced need for expensive emergency balancing actions
- **Cost Savings**: Lower overall system balancing costs

---

## Cross-Feature Insights

### Integrated Analysis

**Correlation Between Summaries:**

1. **RED Events ↔ RED KPI**:
   - RED events should correlate with elevated RED KPI %
   - Disconnect may indicate threshold misalignment

2. **RED Events ↔ Unforeseen Demand**:
   - Unforeseen events may trigger RED boundary events
   - High unforeseen % with low RED events: Good response capability
   - High unforeseen % with high RED events: Insufficient control

3. **TUNING Events ↔ GREEN KPI**:
   - High TUNING should maintain high GREEN %
   - Shows effectiveness of active frequency management

### Temporal Analysis Workflow

**Using Filter for Different Purposes:**

1. **Daily Operations**: Filter to "Today" → assess current performance
2. **Weekly Review**: Filter to past 7 days → identify trends
3. **Monthly Report**: Filter by month → generate executive summary
4. **Incident Investigation**: Filter to specific dates → analyze specific events
5. **Seasonal Comparison**: Compare Winter vs Summer months → identify patterns

---

## Technical Details

### Data Flow

```
Input Data:
├── data/input/fnew-*.csv (per-second frequency)
├── data/input/system_demand.csv (SP-level demand)
└── config/config.yml (thresholds)

Processing:
├── Frequency Processor → frequency_per_second_with_rocof.csv
├── Event Detection → sp_boundary_events.csv
├── KPI Monitoring → frequency_kpi_by_sp.csv
└── Unforeseen Demand → unforeseen_demand_events.csv

Dashboard:
└── Overview Tab → Filtered summaries
```

### Refresh Rates

- **Configuration Parameters**: Static (loaded from config file)
- **Data Coverage**: Dynamic (scanned on dashboard load)
- **Summary Statistics**: User-triggered (via "Update Summary" button)
- **Underlying Data**: Batch processed (run `Rscript main.R` to regenerate)

### Performance Considerations

- **Filtering**: Fast (in-memory filtering of pre-processed data)
- **Date Range**: No practical limit (tested with 2+ years of data)
- **Response Time**: < 1 second for typical filtering operations

---

## Use Cases & Scenarios

### Scenario 1: Monthly Performance Review

**Objective**: Assess May 2025 system performance

**Workflow:**
1. Navigate to Overview tab
2. Select "Month" filter mode
3. Choose "May 2025"
4. Click "Update Summary"

**Analysis:**
- RED events: 3.1% → Acceptable (< 5%)
- GREEN KPI: 82.06% → Good frequency stability
- Unforeseen events: 1.9% → Good forecast quality

**Outcome**: May 2025 shows healthy system operation

### Scenario 2: Incident Investigation

**Objective**: Investigate high RED events on June 15, 2025

**Workflow:**
1. Select "Date Range" filter mode
2. Set both Start and End Date to 2025-06-15
3. Click "Update Summary"

**Analysis:**
- RED events: 15.6% (elevated)
- RED KPI: 8.3% (significantly elevated)
- Unforeseen events: 6.2% (elevated)

**Outcome**: June 15 had significant issues; investigate specific RED events in "SP Boundary Events" tab

### Scenario 3: Forecasting Quality Assessment

**Objective**: Compare forecasting accuracy across Q2 2025

**Workflow:**
1. Filter to April 2025: Note unforeseen %
2. Filter to May 2025: Note unforeseen %
3. Filter to June 2025: Note unforeseen %

**Analysis:**
- April: 2.8%
- May: 1.9%
- June: 3.5%

**Outcome**: Forecasting quality varies; June may have had unusual events or forecast model issues

---

## Best Practices

### For Operations Teams

1. **Daily Check**: Review previous day's summary each morning
2. **Threshold Review**: If RED events consistently near thresholds, discuss recalibration
3. **Trend Tracking**: Monitor month-over-month changes in quality distribution
4. **Incident Documentation**: Screenshot filtered summaries for incident reports

### For Analysts

1. **Baseline Establishment**: Calculate typical ranges for each metric
2. **Statistical Testing**: Use historical data to set anomaly detection thresholds
3. **Seasonal Analysis**: Compare same months across different years
4. **Root Cause Analysis**: Link high unforeseen % to specific weather or market events

### For Management

1. **Executive Summaries**: Monthly filtered view provides KPI reporting data
2. **Performance Tracking**: Use GREEN % as primary stability indicator
3. **Investment Justification**: High RED or unforeseen % supports balancing service expansion
4. **Regulatory Reporting**: Quality distribution supports Grid Code compliance evidence

---

## Troubleshooting

### Common Issues

1. **"No data available for selected period"**
   - **Cause**: Selected dates outside available data range
   - **Solution**: Check "Data Coverage" panel for valid date range

2. **Summaries show 0 events**
   - **Cause**: Very narrow date filter with no events
   - **Solution**: Expand date range or verify data processing completed

3. **Percentages don't sum to 100%**
   - **Cause**: Rounding or missing categories
   - **Solution**: Normal for display; underlying data is accurate

4. **Data Coverage shows wrong dates**
   - **Cause**: Input files renamed or misplaced
   - **Solution**: Verify `data/input/fnew-*.csv` files present and correctly named

---

## Future Enhancements

### Potential Additions

1. **Graphical Trends**: Add sparklines showing metric trends over time
2. **Comparison Mode**: Side-by-side comparison of two time periods
3. **Export Function**: Download filtered summary as CSV or PDF
4. **Automated Alerts**: Highlight when metrics exceed expected ranges
5. **Weather Overlay**: Show weather conditions for correlation analysis

---

## Summary

The Overview Tab provides executive-level visibility into three critical aspects of power system operation:
1. **Frequency Events**: How often and how severe are disturbances?
2. **Quality Distribution**: How much time is spent in each quality band?
3. **Forecasting Accuracy**: How well are demand changes predicted?

By consolidating these metrics with flexible filtering, the tab enables both high-level performance monitoring and detailed incident investigation, supporting operational excellence and regulatory compliance.
