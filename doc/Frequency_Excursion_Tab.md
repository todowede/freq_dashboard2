# Frequency Excursion Tab Documentation

## Overview

The Frequency Excursion tab analyzes how often and how long frequency deviates beyond specified thresholds from the nominal 50 Hz. It tracks excursion events at three severity levels (0.1 Hz, 0.15 Hz, 0.2 Hz) and provides daily statistics on frequency deviation extremes.

---

## Features

### 1. Filter by Date Range

Controls for selecting analysis period:

- **Start Date**
  - Date input field (format: YYYY-MM-DD)
  - Default: First day of selected month

- **End Date**
  - Date input field (format: YYYY-MM-DD)
  - Default: Last day of selected month

- **Update Plots Button**
  - Applies date filter and refreshes all visualizations
  - Instruction text: "Select date range and click 'Update Plots' to refresh visualizations."

---

### 2. Number of Excursions

**Purpose**: Shows daily count of frequency excursion events for each threshold level.

**Visual Design**:
- **Chart Type**: Multi-line time series
- **X-Axis**: Date (e.g., May 4 2025, May 11, May 18, May 25)
- **Y-Axis**: Number of Excursions (count)
  - Scale: 0-700 (typical range)

**Lines**:
- **Orange line**: 0.1 Hz threshold excursions
  - Highest frequency (400-700 excursions per day)
  - Represents minor frequency deviations

- **Green line**: 0.15 Hz threshold excursions
  - Moderate frequency (50-200 excursions per day)
  - Represents significant frequency deviations

- **Blue line**: 0.2 Hz threshold excursions
  - Lowest frequency (0-50 excursions per day)
  - Represents severe frequency deviations

**Data Source**:
- Input: `data/processed/frequency_excursion_analysis.csv`
- Excursion events detected when frequency crosses threshold boundaries
- Counted daily for each threshold level

**Interpretation**:
- **0.1 Hz line (orange)**: Most common, captures all moderate-to-severe deviations
- **0.15 Hz line (green)**: Fewer events, indicates more serious control issues
- **0.2 Hz line (blue)**: Rare, indicates system stress or major disturbances

**Pattern Recognition**:
- **Spikes in all lines**: Day with generally poor frequency control
- **0.1 Hz spike only**: Day with many small deviations but few severe ones
- **Green/Blue spikes**: Days requiring investigation for severe events
- **Consistent high counts**: Systematic issue with frequency management

**Business Value**:
- Identify days with excessive frequency deviations
- Track frequency control performance trends
- Set targets for maximum acceptable excursion counts
- Prioritize days for detailed event analysis

---

### 3. Total Duration of Excursions

**Purpose**: Shows cumulative time spent in excursion state each day for each threshold.

**Visual Design**:
- **Chart Type**: Multi-line time series
- **X-Axis**: Date
- **Y-Axis**: Duration (seconds)
  - Scale: 0-30,000 seconds (0-8.3 hours)

**Lines**:
- **Orange line**: 0.1 Hz threshold duration
  - Highest values (8,000-30,000 seconds per day)
  - Can represent up to 35% of the day

- **Green line**: 0.15 Hz threshold duration
  - Lower values (0-5,000 seconds per day)

- **Blue line**: 0.2 Hz threshold duration
  - Minimal values (near 0 seconds most days)

**Data Source**:
- Input: `data/processed/frequency_excursion_analysis.csv`
- Sums total seconds frequency was beyond each threshold per day
- Maximum possible: 86,400 seconds (24 hours)

**Interpretation**:
- **High duration at 0.1 Hz**: Frequency spent significant time outside tight control band
- **High duration at 0.15 Hz**: Serious control issues, extended periods of poor quality
- **Any significant 0.2 Hz duration**: Critical control problem requiring immediate attention

**Example Reading**:
- Day with 30,000 seconds at 0.1 Hz: Frequency was ±0.1 Hz or worse for 8.3 hours
- Day with 5,000 seconds at 0.15 Hz: Frequency was ±0.15 Hz or worse for 1.4 hours

**Business Value**:
- Quantify severity of poor frequency control in time terms
- Distinguish between "many short excursions" vs "few long excursions"
- Support compliance reporting (regulatory limits on excursion duration)
- Identify sustained vs transient frequency issues

---

### 4. Percentage of Time in Excursion

**Purpose**: Normalizes excursion duration as percentage of each day for easier comparison.

**Visual Design**:
- **Chart Type**: Multi-line time series
- **X-Axis**: Date
- **Y-Axis**: Percentage of Time (%)
  - Scale: 0-35%

**Lines**:
- **Orange line**: 0.1 Hz threshold percentage
  - Typical range: 10-35%
  - Shows what proportion of day had ±0.1 Hz or worse deviation

- **Green line**: 0.15 Hz threshold percentage
  - Typical range: 0-6%

- **Blue line**: 0.2 Hz threshold percentage
  - Typically near 0%

**Data Source**:
- Calculated from Total Duration of Excursions
- Formula: (Duration in seconds / 86,400) × 100%

**Interpretation**:
- **0.1 Hz at 35%**: Frequency was outside ±0.1 Hz for over 8 hours (poor control)
- **0.15 Hz at 5%**: Frequency was outside ±0.15 Hz for ~1.2 hours (significant issue)
- **0.2 Hz above 1%**: Critical control problem (>14 minutes at severe deviation)

**Target Benchmarks** (example):
- 0.1 Hz: Below 20% (good), 20-30% (acceptable), above 30% (poor)
- 0.15 Hz: Below 2% (good), 2-5% (acceptable), above 5% (poor)
- 0.2 Hz: Below 0.5% (good), above 1% (investigate)

**Business Value**:
- Set percentage-based performance targets
- Compare days of different months on normalized scale
- Quick assessment: "Was today better or worse than average?"
- Regulatory reporting in percentage terms

---

### 5. Daily Frequency Deviation Statistics

**Purpose**: Shows the extreme frequency deviations (both positive and negative) experienced each day.

**Visual Design**:
- **Chart Type**: Dual-line time series
- **X-Axis**: Date (May 4 2025 to Jun 1)
- **Y-Axis**: Frequency Deviation from 50 Hz (Hz)
  - Scale: -0.2 Hz to +0.2 Hz
  - Zero line at 50 Hz (nominal frequency)

**Lines**:
- **Red line**: Max Deviation
  - Shows highest frequency reached each day (above 50 Hz)
  - Typically +0.1 to +0.2 Hz
  - Indicates over-frequency events

- **Blue line**: Min Deviation
  - Shows lowest frequency reached each day (below 50 Hz)
  - Typically -0.1 to -0.2 Hz
  - Indicates under-frequency events

**Data Source**:
- Input: `data/processed/frequency_per_second_with_rocof.csv`
- Daily aggregation: `max(frequency - 50)` and `min(frequency - 50)`

**Interpretation**:
- **Symmetric lines** (equal magnitude): Balanced over/under-frequency events
- **Red line higher than blue line is lower**: More severe under-frequency than over-frequency
- **Lines close to zero**: Day with tight frequency control
- **Lines at ±0.2 Hz**: Day reached severe deviation thresholds

**Example Readings**:
- Red line at +0.2 Hz, Blue line at -0.17 Hz: Maximum was 50.2 Hz, minimum was 49.83 Hz
- Day with red at +0.11 Hz, blue at -0.10 Hz: Tight control, stayed within ±0.11 Hz

**Pattern Recognition**:
- **Both lines trending away from zero**: General deterioration in control
- **Blue line dropping significantly**: Increasing under-frequency risk (generation shortfall)
- **Red line rising significantly**: Increasing over-frequency risk (generation surplus)
- **Sudden changes**: Correlation with major grid events or configuration changes

**Business Value**:
- Monitor extreme frequency deviations daily
- Assess whether system is approaching statutory limits (±0.5 Hz in UK)
- Identify asymmetric issues (e.g., more under-frequency than over-frequency)
- Support grid security assessments
- Track improvement initiatives (tighter max/min over time)

---

## Excursion Threshold Definitions

The three threshold levels detect progressively more severe frequency deviations:

| Threshold | Deviation | Frequency Range | Severity | Typical Daily Count |
|-----------|-----------|----------------|----------|-------------------|
| **0.1 Hz** | ±0.1 Hz | 49.9 - 50.1 Hz | Minor | 400-700 |
| **0.15 Hz** | ±0.15 Hz | 49.85 - 50.15 Hz | Significant | 50-200 |
| **0.2 Hz** | ±0.2 Hz | 49.8 - 50.2 Hz | Severe | 0-50 |

**Excursion Event**:
- Begins when frequency crosses threshold boundary (e.g., drops below 49.9 Hz)
- Continues while frequency remains beyond threshold
- Ends when frequency returns within threshold band
- Each crossing = one excursion event

**Example**:
- Frequency timeline: 50.0 → 49.88 → 49.92 → 50.01 Hz
- This creates one 0.1 Hz excursion (49.88 and 49.92 both < 49.9 Hz)

---

## Cross-Plot Analysis

### Typical Analysis Workflow

1. **Review Number of Excursions**: Identify days with high excursion counts
2. **Check Total Duration**: Determine if high counts are due to many short events or few long events
3. **Examine Percentage of Time**: Assess overall severity in normalized terms
4. **Review Daily Deviation Statistics**: Understand the magnitude of worst-case deviations

### Interpretation Patterns

#### Pattern 1: Many Short Excursions
- **High number of excursions** (e.g., 700 at 0.1 Hz)
- **Moderate duration** (e.g., 15,000 seconds)
- **Moderate percentage** (e.g., 17%)
- **Interpretation**: Frequency oscillating around threshold boundary, frequent but brief deviations
- **Action**: Review control system tuning, check for oscillatory behavior

#### Pattern 2: Few Long Excursions
- **Low number of excursions** (e.g., 100 at 0.1 Hz)
- **High duration** (e.g., 25,000 seconds)
- **High percentage** (e.g., 29%)
- **Interpretation**: Extended periods of poor frequency control, sustained deviations
- **Action**: Investigate major events causing prolonged imbalance

#### Pattern 3: Severe Event Day
- **0.1 Hz excursions**: High (600+)
- **0.15 Hz excursions**: Elevated (150+)
- **0.2 Hz excursions**: Present (20+)
- **Max/Min deviation**: Approaching ±0.2 Hz
- **Interpretation**: Day with severe frequency disturbances, possibly multiple RED events
- **Action**: Conduct detailed event investigation, review SP Boundary Events tab

#### Pattern 4: Good Control Day
- **0.1 Hz excursions**: Low (200-300)
- **0.15 Hz excursions**: Minimal (0-50)
- **0.2 Hz excursions**: Zero
- **Percentage at 0.1 Hz**: Below 15%
- **Max/Min deviation**: Within ±0.12 Hz
- **Interpretation**: Excellent frequency control, well-managed system
- **Action**: Document as best practice day for comparison

---

## Use Cases

### Use Case 1: Daily Performance Review
**Objective**: Assess yesterday's frequency control performance

**Steps**:
1. Set date range to yesterday only
2. Click Update Plots
3. Check Number of Excursions: Compare to typical range
4. Check Percentage of Time at 0.1 Hz: Is it below target (e.g., 20%)?
5. Review Daily Deviation Statistics: Did max/min exceed concern thresholds?
6. If any metrics exceed targets, investigate specific events

### Use Case 2: Monthly Trend Analysis
**Objective**: Identify improving or deteriorating frequency control trends

**Steps**:
1. Set date range to last complete month
2. Review all three excursion plots for trends:
   - Is Number of Excursions increasing or decreasing over the month?
   - Is Total Duration trending up or down?
   - Are there clusters of bad days or isolated incidents?
3. Check Daily Deviation Statistics for any worsening extremes
4. Report findings: "May showed 15% improvement in 0.1 Hz excursion time vs April"

### Use Case 3: Threshold Compliance Verification
**Objective**: Verify system meets internal or regulatory excursion limits

**Steps**:
1. Set date range to compliance reporting period (e.g., quarter)
2. Identify any days where:
   - 0.2 Hz percentage exceeds 1% (severe)
   - 0.15 Hz percentage exceeds 5% (significant)
   - Max/Min deviation exceeds ±0.3 Hz (critical)
3. For non-compliant days, use SP Boundary Events tab to document specific incidents
4. Compile compliance report with excursion statistics

### Use Case 4: System Stress Identification
**Objective**: Find days when system experienced unusual frequency stress

**Steps**:
1. Filter to period of interest (e.g., winter month)
2. Look for simultaneous spikes in:
   - All three threshold levels (0.1, 0.15, 0.2 Hz)
   - Both max and min deviations reaching extremes
3. Correlate with external factors:
   - High demand days
   - Generation outages
   - Weather events
4. Use findings for capacity planning and risk assessment

---

## Technical Details

### Excursion Detection Algorithm
- Frequency data sampled at 1-second resolution
- Each second classified as in-excursion or normal for each threshold
- Consecutive excursion seconds grouped into events
- Daily metrics aggregated from second-level data

### Duration Calculation
- Sum of all seconds where `|frequency - 50| > threshold`
- Separate calculation for each threshold level
- Reported in seconds, convertible to hours or percentage

### Daily Aggregation
- Day defined as midnight to midnight (00:00:00 to 23:59:59)
- 86,400 seconds per day maximum
- Max Deviation: Highest frequency value recorded during day minus 50 Hz
- Min Deviation: Lowest frequency value recorded during day minus 50 Hz

---

## Best Practices

1. **Set Performance Targets**: Define acceptable thresholds for each metric
   - Example: "0.1 Hz excursions should be <300/day and <15% of time"

2. **Regular Monitoring**: Review daily to catch trends early
   - Morning review of previous day's performance
   - Weekly trend analysis

3. **Investigate Anomalies**: When metrics exceed targets by significant margin
   - Don't just note the number, investigate root cause
   - Use SP Boundary Events tab for detailed analysis

4. **Compare Like Periods**: Account for seasonal and demand variations
   - Compare weekdays with weekdays, weekends with weekends
   - Consider demand level when benchmarking

5. **Track Improvement Initiatives**: Use as KPIs for operational changes
   - Before/after comparison when implementing new control strategies
   - Document successful interventions that reduce excursions

6. **Correlation Analysis**: Cross-reference with other data
   - Weather patterns
   - Renewable generation levels
   - Major system events or outages

---

## Troubleshooting

### No data showing in plots
- Verify date range contains data (check input files cover those dates)
- Ensure frequency_excursion_analysis.csv exists in data/processed/
- Click "Update Plots" button after setting date range

### Unexpectedly high excursion counts
- Check if data quality issues causing false excursions (sensor noise)
- Verify thresholds configured correctly in config.yml
- Review raw frequency data for that period

### 0.2 Hz excursions but no RED events
- Excursion thresholds differ from RED event classification criteria
- RED events consider multiple factors beyond just frequency magnitude
- Cross-reference with SP Boundary Events tab for event classification

### Duration values seem too high
- Remember: values in seconds, not minutes
- 30,000 seconds = 8.3 hours = 34.7% of day (normal for 0.1 Hz threshold)
- Check if multiple thresholds breached simultaneously (expected)

### Max/Min deviation lines are flat
- Indicates data aggregation issue or missing data
- Check frequency_per_second_with_rocof.csv for completeness
- Verify date filter includes correct dates
