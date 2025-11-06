# Unforeseen Demand Tab Documentation

## Overview

The Unforeseen Demand tab analyzes frequency events caused by unexpected demand changes that cannot be explained by natural frequency damping alone. It separates total demand changes into "damping component" (expected response to frequency changes) and "unforeseen component" (forecasting errors or unexpected load changes). The tab has two sub-tabs: Event Analysis for detailed single-day analysis and Patterns for long-term trend identification.

---

## Sub-Tab 1: Event Analysis

### Purpose
Provides detailed analysis of unforeseen demand events for a specific day, showing the separation between natural damping and true unforeseen demand changes.

### Features

#### 1. Filter Options

Controls for selecting analysis parameters:

- **Demand Metric**
  - Dropdown: ND (National Demand), TSD (Transmission System Demand)
  - Selects which demand metric to analyze

- **Event Filter**
  - Dropdown: All Events, Unforeseen Only, etc.
  - Filters which SP boundaries to display

- **Start Date**
  - Date input (format: YYYY-MM-DD)
  - Selects day for detailed analysis

- **End Date**
  - Date input (format: YYYY-MM-DD)
  - For single-day analysis, typically matches Start Date

---

#### 2. Demand Changes Over Time (with Damping Separation)

**Purpose**: Shows total demand change at each SP boundary and highlights the unforeseen component.

**Visual Design**:
- **Chart Type**: Dual-component line chart with scatter overlay
- **X-Axis**: Settlement Period (SP) 1-48
  - Represents 48 half-hour periods across the day
  - Black dashed vertical lines mark specific SP boundaries

- **Y-Axis**: ND change (MW)
  - Scale: -2000 to +2500 MW (typical range)
  - Positive values: Demand increase
  - Negative values: Demand decrease

**Lines/Markers**:
- **Blue line**: Total Change
  - Complete demand change at each SP boundary
  - Includes both damping and unforeseen components

- **Red dots**: Unforeseen Component
  - Portion of demand change NOT explained by frequency damping
  - Only plotted when unforeseen component is significant

**Interactive Elements**:
- Tooltip on hover shows:
  - Settlement Period number
  - Total Change value (MW)
  - Unforeseen Component value (MW)
  - Example: "SP 22, Total Change: -689, Unforeseen C...: -733.5916"

**Data Source**:
- Input: `data/processed/unforeseen_demand_analysis.csv`
- Calculated during unforeseen demand analysis step

**Interpretation**:
- **Blue line alone**: Demand change fully explained by natural damping (frequency-led)
- **Red dots present**: Demand change includes unexpected component (demand-led or forecasting error)
- **Large red dots**: Significant unforeseen demand events requiring investigation

**Calculation Method**:
- Total Change = Observed demand change at SP boundary
- Expected Damping = Frequency change × Damping coefficient D
- Unforeseen Component = Total Change - Expected Damping

**Example Reading**:
- SP 22: Total Change = -689 MW (demand dropped)
- Unforeseen = -733.6 MW (larger than total because damping partially offset it)
- This means: Demand unexpectedly dropped by 734 MW, but frequency rise (+damping effect) added 45 MW back

**Business Value**:
- Identify forecasting errors or unexpected load changes
- Distinguish between frequency-led and demand-led events
- Quantify magnitude of unforeseen demand in MW terms
- Support demand forecasting improvement initiatives

---

#### 3. SP Frequency Event Categories

**Purpose**: Shows frequency at each SP boundary color-coded by event severity category.

**Visual Design**:
- **Chart Type**: Line chart with category markers
- **X-Axis**: Settlement Period (SP) 1-48
- **Y-Axis**: Frequency (Hz)
  - Scale: 49.85 - 50.2 Hz

**Lines/Markers**:
- **Purple line**: Frequency values at SP boundaries
- **Green dots**: Specific categories (e.g., events meeting certain criteria)
- Color coding indicates event classification

**Data Source**:
- Input: `data/processed/frequency_per_second_with_rocof.csv`
- Extracted at SP boundary timestamps

**Interpretation**:
- **Frequency above 50 Hz**: Over-frequency (generation surplus)
- **Frequency below 50 Hz**: Under-frequency (generation deficit)
- **Green dots**: Highlight significant events or categories
- Provides context for demand changes shown in top plot

**Business Value**:
- Correlate frequency events with demand changes
- Understand whether frequency drove demand (damping) or vice versa
- Identify SP boundaries with poor frequency control

---

#### 4. Frequency Profile for Selected Day

**Purpose**: Shows continuous frequency profile across all 48 SP boundaries for the selected day.

**Visual Design**:
- **Chart Type**: Multi-line time series
- **X-Axis**: Settlement Period (SP) 1-48
- **Y-Axis**: Frequency (Hz)
  - Scale: 49.8 - 50.2 Hz

**Lines**:
- **Dashed gray line**: 50 Hz nominal frequency reference
- **Red line**: One metric (e.g., maximum frequency per SP)
- **Blue line**: Another metric (e.g., minimum frequency per SP)

**Data Source**:
- Input: `data/processed/frequency_per_second_with_rocof.csv`
- Aggregated by settlement period

**Interpretation**:
- **Lines close to 50 Hz**: Good frequency control
- **Wide spread between red and blue**: High frequency variability within SPs
- **Deviations from 50 Hz**: Imbalance between generation and demand
- Compare with demand changes to understand causality

**Business Value**:
- Assess overall frequency quality for the day
- Identify periods with poor control
- Support root cause analysis for unforeseen demand events

---

#### 5. Unforeseen Demand Events Details Table

**Purpose**: Provides detailed data table of all SP boundaries with unforeseen demand metrics and classifications.

**Table Controls**:
- **Show dropdown**: Select number of entries to display (10, 15, 25, etc.)
- **Search box**: Free text search across all columns
- **Column filters**: Dropdown filters at top of each column

**Columns**:

| Column | Description | Example Values |
|--------|-------------|----------------|
| **Date** | Event date | 2025-05-01 |
| **SP** | Settlement Period number | 1-48 |
| **Hour** | Hour of day (0-23) | 0, 1, 2, ... |
| **Delta_ND** | Total ND change at SP boundary | -354.00 MW |
| **ND_damping** | Expected change due to frequency damping | 9.14 MW |
| **ND_unforeseen** | Unforeseen component (Delta - Damping) | -363.14 MW |
| **is_unforeseen_ND** | Boolean flag if unforeseen threshold exceeded | true/false |
| **ND_event_severity** | Severity score of unforeseen component | 0.62 |
| **abs_freq_change** | Absolute frequency change at boundary | 0.02 Hz |
| **trend** | Frequency direction | Up/Down/Flat |
| **causality** | Event classification | Minor, Frequency-led, Demand-led |

**Pagination**:
- Shows "Showing 1 to 15 of 48 entries"
- Page numbers: 1, 2, 3, 4, Next
- Previous/Next buttons for navigation

**Data Source**:
- Input: `data/processed/unforeseen_demand_analysis.csv`

**Interpretation**:

**Causality Categories**:
- **Minor**: Small unforeseen component, negligible impact
- **Frequency-led**: Demand change primarily explained by frequency damping (no significant unforeseen component)
- **Demand-led**: Significant unforeseen demand change that drove frequency deviation

**Example Row Reading**:
- Date: 2025-05-01, SP 13
- Delta_ND: 2,183 MW (large demand increase)
- ND_damping: -17.47 MW (frequency fell, so damping reduced demand)
- ND_unforeseen: 2,200.47 MW (almost entire increase was unforeseen)
- Causality: Demand-led (unexpected demand surge caused frequency drop)

**Business Value**:
- Export detailed data for offline analysis
- Filter and search for specific event types
- Sort by severity to prioritize investigations
- Support compliance reporting and post-event analysis

---

## Sub-Tab 2: Patterns

### Purpose
Identifies temporal patterns in unforeseen demand events across multiple days to reveal systematic forecasting issues or recurring load behavior.

### Features

#### 1. Filter by Date Range

Controls for selecting analysis period:

- **Start Date**
  - Date input (format: YYYY-MM-DD)
  - Beginning of analysis period

- **End Date**
  - Date input (format: YYYY-MM-DD)
  - End of analysis period

- **Demand Metric**
  - Dropdown: ND or TSD
  - Selects which demand metric to analyze

- **Update Plots Button**
  - Applies filters and refreshes visualizations

---

#### 2. Total Unforeseen Events by Hour of Day

**Purpose**: Shows which hours of the day experience the most unforeseen demand events, aggregated across all dates in the selected range.

**Visual Design**:
- **Chart Type**: Bar chart
- **X-Axis**: Hour of Day (0-23)
  - 0 = midnight-1am, 23 = 11pm-midnight

- **Y-Axis**: Total Unforeseen Events (count)
  - Scale: 0-2+ events

**Bars**:
- **Red bars**: Count of unforeseen events for each hour
- Height indicates total events across all days in period

**Data Source**:
- Input: `data/processed/unforeseen_demand_analysis.csv`
- Aggregates `is_unforeseen_ND = true` events by hour

**Interpretation**:
- **Peak at Hour 21 (9-10pm)**: Most unforeseen events occur during evening
- **Peaks at Hours 3-5 (3-6am)**: Morning demand ramp forecasting challenges
- **Peaks at Hours 10-11, 16-19**: Daytime and evening transitions
- **Low/zero bars**: Hours with predictable demand patterns

**Pattern Recognition**:
- **Morning ramp (5-8am)**: Forecasting errors as demand rises
- **Evening peak (17-21pm)**: Unpredictable consumer behavior
- **Night valley (0-4am)**: Generally predictable, few events
- **Midday (11-15pm)**: Variable depending on weather/industrial load

**Business Value**:
- Identify hours requiring improved demand forecasting
- Optimize reserve holdings for problematic hours
- Schedule balancing resources proactively
- Support operational planning and staffing decisions

---

#### 3. Unforeseen Events Heatmap (Hour × Date)

**Purpose**: Two-dimensional visualization showing when unforeseen events occur across both time of day (hour) and calendar dates.

**Visual Design**:
- **Chart Type**: Heatmap
- **X-Axis**: Hour of Day (0-23)
- **Y-Axis**: Date (e.g., May 4, May 11, May 18, May 25 2025)
  - Dates from selected range

**Color Scale**:
- **Gray**: No events (0 events)
- **Red**: Events occurred (intensity indicates count)
- **Color bar**: 0 to 1 events (darker red = more events)

**Interactive Elements**:
- Tooltip shows: "Date: YYYY-MM-DD, Hour: HH, Events: N"

**Data Source**:
- Input: `data/processed/unforeseen_demand_analysis.csv`
- Aggregated by date and hour

**Interpretation**:
- **Vertical patterns** (same hour across multiple days): Systematic forecasting issue at that hour
- **Horizontal patterns** (multiple hours on same day): Day with generally poor forecasting
- **Scattered red cells**: Random unforeseen events
- **Clusters**: Recurring issues requiring targeted intervention

**Example Insights**:
- Multiple red cells at Hour 21 across different weeks: Evening peak consistently mispredicted
- Red cells concentrated on specific dates: Weather events or special circumstances
- Dense clusters: Combination of systematic and event-driven issues

**Business Value**:
- Visualize complex patterns at a glance
- Identify systematic vs random forecasting errors
- Correlate with external factors (weather, holidays, events)
- Support long-term forecasting model improvements

---

#### 4. Daily Event Count Time Series

**Purpose**: Shows daily count of unforeseen demand events over time, with optional filtering by specific hour.

**Visual Design**:
- **Chart Type**: Bar chart time series
- **X-Axis**: Date (e.g., May 4 2025, May 11, May 18, May 25)
- **Y-Axis**: Unforeseen Events Count (0-3)

**Filter Control**:
- **Filter by Hour dropdown**: "All Hours" or specific hour (0-23)
- Description: "Select a specific hour to see trends for that hour only, or 'All Hours' to see total daily counts."

**Bars**:
- **Blue bars**: Count of unforeseen events per day
- Height shows number of events

**Interactive Elements**:
- Tooltip shows date and event count

**Data Source**:
- Input: `data/processed/unforeseen_demand_analysis.csv`
- Aggregated by date (and optionally by hour)

**Interpretation**:
- **All Hours mode**: Shows days with most unforeseen events overall
- **Specific Hour mode**: Tracks trends for problematic hour across multiple days
- **Spikes**: Days requiring investigation
- **Trends**: Improving (decreasing) or deteriorating (increasing) forecasting accuracy

**Use Cases**:

**Use Case 1: Identify Problematic Days**
1. Set Filter by Hour to "All Hours"
2. Look for days with count ≥2
3. Cross-reference with external factors (weather, events)
4. Use Event Analysis tab to investigate specific days

**Use Case 2: Track Improvement for Specific Hour**
1. Set Filter by Hour to "21" (evening peak)
2. Review trend over weeks/months
3. Assess whether forecasting changes reduced events
4. Report on improvement initiative effectiveness

**Business Value**:
- Monitor forecasting performance trends
- Identify days requiring detailed investigation
- Track effectiveness of forecasting improvements
- Support performance reporting and KPIs

---

## Understanding Unforeseen Demand

### What is Unforeseen Demand?

**Unforeseen demand** is the component of demand change that cannot be explained by natural frequency damping alone. When frequency deviates from 50 Hz, electrical loads naturally respond:

- **Frequency drops**: Motors slow down, consuming less power (load damping reduces demand)
- **Frequency rises**: Motors speed up, consuming more power (load damping increases demand)

This natural response is **predictable** and calculated using the damping coefficient D (typically 1-2% per 1% frequency change).

**Unforeseen demand** occurs when actual demand change differs from what damping predicts:
- Forecasting errors (predicted demand ≠ actual demand)
- Unexpected load switching (industrial processes, EV charging)
- Weather-driven changes not captured in forecasts
- Special events or behaviors

### Calculation Method

For each SP boundary:

1. **Measure total demand change**: ΔD_total = Demand[SP_n] - Demand[SP_n-1]

2. **Calculate expected damping component**: ΔD_damping = D × Δf
   - D = damping coefficient (MW per Hz)
   - Δf = frequency change at SP boundary

3. **Calculate unforeseen component**: ΔD_unforeseen = ΔD_total - ΔD_damping

4. **Classify event**:
   - If |ΔD_unforeseen| > threshold → Flag as unforeseen event
   - Determine causality based on relative magnitudes

### Causality Classification

| Causality | Condition | Meaning |
|-----------|-----------|---------|
| **Demand-led** | Large unforeseen component drove frequency change | Unexpected demand change caused frequency deviation |
| **Frequency-led** | Unforeseen component small, damping explains most change | Frequency event caused demand change through damping |
| **Minor** | Both components small | No significant event |

---

## Cross-Feature Analysis

### Workflow: Investigating Unforeseen Demand Issues

1. **Identify Pattern** (Patterns tab):
   - Review Total Unforeseen Events by Hour of Day
   - Find hours with highest event counts

2. **Examine Temporal Distribution** (Patterns tab):
   - Check Unforeseen Events Heatmap for systematic patterns
   - Identify if issues are recurring or isolated

3. **Analyze Specific Day** (Event Analysis tab):
   - Select problematic day using filters
   - Review Demand Changes Over Time plot
   - Examine which SPs had unforeseen components

4. **Investigate Details** (Event Analysis tab):
   - Review Unforeseen Demand Events Details table
   - Sort by severity or unforeseen magnitude
   - Export data for correlation with external factors

5. **Cross-Reference** (SP Boundary Events tab):
   - Check if unforeseen demand events correlate with RED frequency events
   - Assess grid impact of forecasting errors

### Use Cases

#### Use Case 1: Monthly Forecasting Performance Review

**Objective**: Assess demand forecasting accuracy for past month

**Steps**:
1. Navigate to Patterns tab
2. Set date range to last complete month
3. Review Total Unforeseen Events by Hour of Day
4. Identify hours with most issues (e.g., Hour 21 with 8 events)
5. Set Filter by Hour to problematic hour in Daily Event Count
6. Identify specific days with events
7. Switch to Event Analysis tab for detailed investigation
8. Document findings and recommend forecasting improvements

#### Use Case 2: Systematic Issue Investigation

**Objective**: Determine if recurring pattern indicates systematic forecasting problem

**Steps**:
1. Navigate to Patterns tab
2. Set date range to cover several weeks
3. Review Heatmap for vertical patterns (same hour, multiple days)
4. Example: Hour 17 shows red cells on 8 different days
5. Conclusion: Evening ramp forecasting systematically poor
6. Action: Review forecasting model for Hour 17 period
7. Consider increased reserves for Hour 17-18 transition

#### Use Case 3: Event-Driven Spike Analysis

**Objective**: Understand cause of unusually high unforeseen events on specific day

**Steps**:
1. Identify spike in Daily Event Count (e.g., May 21 with 3 events)
2. Switch to Event Analysis tab
3. Set Start/End Date to May 21
4. Review Demand Changes Over Time: Multiple large red dots
5. Check Unforeseen Demand Events Details table
6. Sort by ND_unforeseen magnitude
7. Find: SP 13, 14, 15 all had large unforeseen components
8. Timing: 6:00-7:30am (morning ramp)
9. Cross-reference: Check weather data for unusual temperature
10. Conclusion: Unexpected cold snap increased heating demand beyond forecast

---

## Technical Details

### Damping Coefficient
- Represents natural load response to frequency changes
- Typical value: 1-2% demand change per 1% frequency change
- Configured in analysis parameters
- GB system: Approximately 1.5%

### Event Thresholds
- Unforeseen event flagged when |ΔD_unforeseen| exceeds threshold
- Threshold typically set to filter noise (e.g., 100-200 MW)
- Configurable in `config.yml`

### Data Aggregation
- SP-level analysis: Each of 48 daily boundaries analyzed independently
- Hourly aggregation: SPs grouped by hour (2 SPs per hour)
- Daily aggregation: All 48 SPs summed per day

### Causality Determination
- Complex algorithm considering multiple factors:
  - Magnitude of unforeseen component
  - Frequency change magnitude
  - Timing of changes
  - Trend direction consistency

---

## Best Practices

1. **Regular Pattern Review**: Weekly review of Patterns tab to catch emerging trends early

2. **Root Cause Analysis**: Don't just count events, investigate causes
   - Weather correlation
   - Day-of-week patterns
   - Special events or holidays

3. **Forecasting Feedback Loop**: Use findings to improve demand forecasting
   - Identify specific hours needing better models
   - Incorporate weather forecasts more effectively
   - Account for special events

4. **Reserve Optimization**: Adjust reserve holdings based on unforeseen event patterns
   - Hold more reserves during problematic hours
   - Reduce reserves during predictable periods
   - Cost optimization while maintaining security

5. **Metric Selection**: Choose appropriate demand metric
   - **ND**: National Demand (total GB demand)
   - **TSD**: Transmission System Demand (excludes embedded generation)
   - Use ND for overall forecasting, TSD for transmission-specific analysis

---

## Troubleshooting

### No red dots in Demand Changes plot
- Check Event Filter: May be filtering out unforeseen events
- Verify threshold settings: May be set too high
- Confirm data exists for selected date
- Check Unforeseen Demand Events Details table for is_unforeseen_ND flags

### All events showing as "Minor" causality
- Damping coefficient may be misconfigured
- Event classification thresholds may be too strict
- Review configuration in config.yml
- Verify frequency and demand data quality

### Heatmap showing all gray (no events)
- Expand date range to cover more data
- Check demand metric selection (ND vs TSD)
- Verify unforeseen demand analysis completed successfully
- Review threshold settings in configuration

### Daily Event Count doesn't match table count
- Check Filter by Hour setting (may be filtering)
- Verify date range consistency between views
- Check is_unforeseen_ND column in details table
- Ensure Update Plots button clicked after filter changes

### Unexpected hour patterns
- Verify hour calculation accounts for timezone
- Check SP-to-hour conversion logic
- Consider daylight saving time transitions
- Review data during clock change dates
