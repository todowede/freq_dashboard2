# Monthly Trends Tab Documentation

## Overview

The Monthly Trends tab provides high-level monthly aggregations of key performance metrics across frequency quality, excursion behavior, and unforeseen demand patterns. It enables long-term trend analysis and month-over-month comparison to identify improving or deteriorating system performance.

---

## Analysis Period

### Purpose
Controls the time range for all trend visualizations.

### Features

- **Start Month**
  - Input format: YYYY-MM (e.g., 2025-05)
  - Defines beginning of analysis period

- **End Month**
  - Input format: YYYY-MM (e.g., 2025-08)
  - Defines end of analysis period

- **Demand Metric**
  - Dropdown: ND (National Demand) or TSD (Transmission System Demand)
  - Applies to Panel 4 only (demand-related analysis)

- **Update Analysis Button**
  - Refreshes all four panels with selected parameters

---

## Panel 1: Monthly Frequency KPI

### Purpose
Shows monthly distribution of frequency quality categories (RED/AMBER/BLUE/GREEN) to track overall frequency control performance trends.

### Visual Design

- **Chart Type**: Multi-line time series
- **X-Axis**: Month (e.g., 2025-05, 2025-06, 2025-07, 2025-08)
- **Y-Axis**: Average Percentage (%)
  - Scale: 0-100%

### Lines

- **Red line**: RED category percentage
  - Poorest quality, typically 1-3%
  - Target: Minimize

- **Orange line**: AMBER category percentage
  - Moderate quality issues, typically 2-5%
  - Target: Keep low

- **Blue line**: BLUE category percentage
  - Minor deviations, typically 10-15%
  - Target: Acceptable range

- **Green line**: GREEN category percentage
  - Best quality, typically 75-85%
  - Target: Maximize

### Data Source

- Input: `data/processed/frequency_kpi_results.csv`
- Aggregation: Monthly average of daily quality percentages

### Interpretation

**Quality Trends**:
- **GREEN increasing**: Improving frequency control
- **RED increasing**: Deteriorating performance, investigate causes
- **Stable lines**: Consistent performance month-over-month

**Example Reading**:
- May 2025: 82% GREEN, 12% BLUE, 4% AMBER, 2% RED
- June 2025: 77% GREEN, 15% BLUE, 5% AMBER, 3% RED
- Interpretation: June showed slight quality degradation

**Seasonal Patterns**:
- Summer months: Often show better GREEN percentage (stable demand)
- Winter months: May show lower GREEN (variable heating demand)
- Transition months (spring/autumn): Can show variable quality

### Business Value

- Track long-term frequency quality trends
- Set monthly performance targets (e.g., "GREEN >80%")
- Identify seasonal patterns for planning
- Support annual performance reporting
- Benchmark against historical data
- Validate effectiveness of operational improvements

---

## Panel 2: Monthly Red Event Ratio Trend

### Purpose
Tracks percentage of time frequency exceeded different excursion thresholds each month, focusing on severe deviation metrics.

### Visual Design

- **Chart Type**: Multi-line time series
- **X-Axis**: Month
- **Y-Axis**: Percentage of Time (%)
  - Scale: 0-25%

### Lines

- **Blue line**: >= 0.1 Hz excursions
  - Most frequent threshold
  - Typical range: 15-23%
  - Indicates time outside ±0.1 Hz band

- **Orange line**: >= 0.15 Hz excursions
  - Significant deviations
  - Typical range: 0.5-2.5%
  - More serious control issues

- **Red line**: >= 0.2 Hz excursions
  - Severe deviations
  - Typical range: 0-0.5%
  - Critical events requiring attention

### Data Source

- Input: `data/processed/frequency_excursion_analysis.csv`
- Aggregation: Monthly sum of excursion durations / total time

### Interpretation

**Threshold Meanings**:
- **0.1 Hz**: Frequency outside 49.9-50.1 Hz range
- **0.15 Hz**: Frequency outside 49.85-50.15 Hz range
- **0.2 Hz**: Frequency outside 49.8-50.2 Hz range

**Pattern Recognition**:
- **All lines trending up**: Worsening frequency control
- **0.2 Hz line above 0.5%**: Critical performance issue
- **June 2025 peak** (example): 23% at 0.1 Hz suggests problematic month

**Target Benchmarks** (example):
- 0.1 Hz: <20% (good), 20-25% (acceptable), >25% (poor)
- 0.15 Hz: <2% (good), 2-3% (acceptable), >3% (investigate)
- 0.2 Hz: <0.5% (good), >1% (critical)

### Business Value

- Monitor compliance with frequency standards
- Identify months requiring detailed investigation
- Track improvement initiatives quantitatively
- Support regulatory reporting
- Set performance improvement targets
- Correlate with system changes or events

---

## Panel 3: Monthly Excursion Percentage (0.15 Hz threshold)

### Purpose
Breaks down 0.15 Hz excursions by direction (over-frequency vs under-frequency) to identify asymmetric trends.

### Visual Design

- **Chart Type**: Multi-line time series
- **X-Axis**: Month
- **Y-Axis**: Percentage of Time (%)
  - Scale: 0-1.2%

### Lines

- **Red line**: Positive excursions (>50.15 Hz)
  - Over-frequency events
  - Generation surplus situations
  - Typical range: 0.5-1.1%

- **Blue line**: Negative excursions (<49.85 Hz)
  - Under-frequency events
  - Generation deficit situations
  - Typical range: 0.4-1.0%

### Data Source

- Input: `data/processed/frequency_excursion_analysis.csv`
- Filtered to 0.15 Hz threshold
- Separated by excursion direction (positive/negative)

### Interpretation

**Line Comparison**:
- **Lines equal**: Balanced over/under-frequency issues
- **Red line higher**: More over-frequency problems (excess generation or sudden load drops)
- **Blue line higher**: More under-frequency problems (generation shortfall or sudden load increases)

**Example Reading** (from screenshot):
- June 2025: Red (positive) at 1.1%, Blue (negative) at 0.97%
- Interpretation: Slightly more over-frequency excursions, fairly balanced

**Trend Analysis**:
- **Both lines increasing**: Overall deteriorating control
- **Lines converging**: Becoming more balanced
- **Lines diverging**: Developing asymmetric issues

**Seasonal Patterns**:
- Winter: May show more negative excursions (high demand risk)
- Summer: May show more positive excursions (lower demand, higher renewables)

### Business Value

- Identify generation-demand imbalance patterns
- Optimize reserve procurement (more upward or downward)
- Support balancing strategy decisions
- Understand renewable integration impacts
- Plan for seasonal demand variations
- Validate forecasting accuracy improvements

---

## Panel 4: Monthly Demand Change Analysis

### Purpose
Tracks magnitude of demand changes at SP boundaries, separating total changes from unforeseen components to assess forecasting accuracy trends.

### Visual Design

- **Chart Type**: Multi-line time series
- **X-Axis**: Month
- **Y-Axis**: Mean Absolute Change (MW)
  - Scale: 480-560 MW

### Lines

- **Blue line**: Total Demand Change
  - Mean absolute demand change across all SP boundaries
  - Includes both expected and unexpected changes
  - Typical range: 485-555 MW

- **Red line**: Unforeseen Component
  - Mean absolute unforeseen demand (not explained by damping)
  - Indicates forecasting accuracy
  - Typical range: 490-560 MW

### Data Source

- Input: `data/processed/unforeseen_demand_analysis.csv`
- Aggregation: Monthly mean of |Delta_ND| and |ND_unforeseen|
- Demand metric selected in Analysis Period controls (ND or TSD)

### Interpretation

**Line Relationships**:

- **Lines close together**: Most demand changes are unforeseen (poor forecasting)
- **Large gap**: Significant portion explained by damping (better situation)
- **Red above blue**: Unforeseen component magnitude exceeds total (complex interaction with damping)

**Example Reading** (from screenshot):
- May 2025: Total = 554 MW, Unforeseen = 560 MW
- June 2025: Total = 537 MW, Unforeseen = 542 MW
- Interpretation: June showed slightly lower demand variability

**Trend Analysis**:
- **Both lines decreasing**: Lower demand volatility or better forecasting
- **Both lines increasing**: Higher demand volatility or deteriorating forecasts
- **Unforeseen decreasing while total stable**: Improved forecasting
- **Unforeseen increasing while total stable**: Deteriorating forecasting

**Seasonal Effects**:
- Summer: Often lower values (stable weather, predictable demand)
- Winter: Higher values (heating variability, weather sensitivity)
- Transition months: Variable depending on weather patterns

### Business Value

- Track demand forecasting accuracy over time
- Identify months with unusual demand volatility
- Support forecasting model improvements
- Optimize balancing cost (better forecasts = lower costs)
- Correlate with weather patterns or events
- Set forecasting performance targets
- Justify investment in forecasting tools

---

## Cross-Panel Analysis

### Integrated Workflow

**Monthly Performance Review Process**:

1. **Start with Panel 1** (Frequency KPI):
   - Check GREEN percentage target (e.g., >80%)
   - Identify problematic months

2. **Review Panel 2** (Excursion Trends):
   - Assess severity of quality issues
   - Check if 0.2 Hz threshold exceeded

3. **Examine Panel 3** (Excursion Direction):
   - Determine if issues are over/under-frequency
   - Inform reserve strategy

4. **Analyze Panel 4** (Demand Changes):
   - Assess whether demand forecasting contributed
   - Identify if unforeseen demand increased

5. **Synthesize findings**:
   - Correlate patterns across panels
   - Develop action plans

### Pattern Recognition

#### Pattern 1: Deteriorating Month

**Indicators**:
- Panel 1: GREEN drops from 82% to 75%
- Panel 2: 0.1 Hz excursions rise from 18% to 24%
- Panel 3: Both directions increase
- Panel 4: Unforeseen component spikes

**Interpretation**: System experienced challenging month with poor control and forecasting

**Actions**:
- Drill down to daily analysis for that month
- Review operational logs for events
- Check for system configuration changes
- Assess weather or demand anomalies

#### Pattern 2: Improving Trend

**Indicators**:
- Panel 1: GREEN increasing month-over-month
- Panel 2: All excursion thresholds decreasing
- Panel 3: Both directions reducing
- Panel 4: Unforeseen component decreasing

**Interpretation**: Operational improvements taking effect

**Actions**:
- Document successful changes
- Maintain current operational practices
- Share best practices across organization

#### Pattern 3: Asymmetric Issue

**Indicators**:
- Panel 1: GREEN stable but not excellent
- Panel 2: 0.1 Hz stable, higher thresholds low
- Panel 3: Red line significantly higher than blue
- Panel 4: Unforeseen stable

**Interpretation**: Systematic over-frequency issue (excess generation)

**Actions**:
- Review generation dispatch practices
- Check for demand forecast bias (over-predicting)
- Optimize downward reserve holdings
- Investigate renewable curtailment patterns

#### Pattern 4: Forecasting Challenge

**Indicators**:
- Panel 1: Quality metrics stable
- Panel 2: Excursions stable
- Panel 3: Balanced directions
- Panel 4: Unforeseen component increasing sharply

**Interpretation**: Demand becoming more unpredictable without severe frequency impact

**Actions**:
- Review demand forecasting models
- Check for new demand patterns (EV charging, etc.)
- Consider enhanced weather integration
- Increase forecasting team engagement

---

## Use Cases

### Use Case 1: Quarterly Performance Report

**Objective**: Generate quarterly summary of frequency control performance

**Steps**:
1. Set Start Month to beginning of quarter (e.g., 2025-04)
2. Set End Month to end of quarter (e.g., 2025-06)
3. Click Update Analysis
4. Document from Panel 1: Average GREEN percentage across quarter
5. Document from Panel 2: Average excursion percentages
6. Note any month-to-month trends
7. Export screenshots for presentation
8. Include commentary on seasonal factors

### Use Case 2: Year-Over-Year Comparison

**Objective**: Compare current year performance to previous year

**Steps**:
1. Analyze current year (e.g., Start: 2025-01, End: 2025-08)
2. Document all panel metrics
3. Change period to previous year (Start: 2024-01, End: 2024-08)
4. Document all panel metrics
5. Create comparison table showing improvements/degradations
6. Identify structural changes vs seasonal variations
7. Report findings for strategic planning

### Use Case 3: Initiative Impact Assessment

**Objective**: Evaluate impact of operational change implemented in specific month

**Steps**:
1. Set period covering 3 months before and after change
2. Example: Change implemented May 2025
3. Analyze Mar-Apr (before) vs Jun-Jul (after)
4. Compare Panel 1 metrics: Did GREEN % improve?
5. Compare Panel 2: Did excursions decrease?
6. Statistical test: Is change significant or noise?
7. Report on initiative ROI and effectiveness

### Use Case 4: Seasonal Planning

**Objective**: Prepare for upcoming seasonal transition

**Steps**:
1. Set period to same months in previous year
2. Example: Analyze Oct-Nov 2024 to plan for Oct-Nov 2025
3. Document typical seasonal patterns:
   - Expected GREEN percentage drop
   - Typical excursion increase
   - Demand change volatility
4. Plan reserve adjustments and operational strategies
5. Set realistic performance targets accounting for season

---

## Technical Details

### Monthly Aggregation Methods

**Panel 1 (KPI)**:
- Daily quality percentages averaged across month
- Weighted equally (each day counts the same)

**Panel 2 (Excursions)**:
- Total excursion seconds per month / total seconds in month
- Accounts for different month lengths (28-31 days)

**Panel 3 (Directional Excursions)**:
- Separate aggregation for positive and negative excursions
- Same percentage calculation as Panel 2

**Panel 4 (Demand Changes)**:
- Mean absolute value of all SP boundary changes
- Formula: mean(|ΔD|) across all SPs in month
- Unforeseen: mean(|ΔD_unforeseen|)

### Data Completeness

- Months with incomplete data may show skewed results
- System accounts for missing days by averaging available data
- Consider data coverage when interpreting trends
- First/last months of dataset may be partial

### Statistical Considerations

- Month-to-month variation includes both signal and noise
- Trends over 3+ months more reliable than single month changes
- Seasonal effects should be accounted for in comparisons
- Year-over-year comparisons more meaningful than sequential months

---

## Best Practices

1. **Regular Monitoring**: Review monthly after each month closes
   - Add new month to rolling window
   - Track against targets
   - Document significant changes

2. **Consistent Timeframes**: Use consistent analysis periods for comparisons
   - Same number of months
   - Account for seasonal effects
   - Compare like-to-like periods

3. **Contextualize Data**: Don't analyze trends in isolation
   - Consider weather patterns
   - Note major grid events or outages
   - Account for system configuration changes
   - Review demand levels and generation mix

4. **Set Targets**: Define acceptable ranges for each metric
   - GREEN >80%
   - 0.1 Hz excursions <20%
   - 0.2 Hz excursions <0.5%
   - Track performance against targets

5. **Drill Down**: Use monthly trends to identify periods needing detailed analysis
   - Don't just note the trend
   - Investigate root causes
   - Link to daily/hourly analysis tabs

6. **Document Changes**: Maintain log of operational changes
   - Map changes to performance impacts
   - Build knowledge base of effective interventions
   - Support continuous improvement

---

## Interpretation Guide

### Panel 1: Frequency KPI

**Excellent Performance**:
- GREEN >85%, RED <1%, AMBER <3%
- Stable or improving trend

**Acceptable Performance**:
- GREEN 75-85%, RED 1-3%, AMBER 3-6%
- Relatively stable

**Poor Performance**:
- GREEN <75%, RED >3%, AMBER >6%
- Deteriorating trend

### Panel 2: Excursion Trends

**Good Control**:
- 0.1 Hz <18%, 0.15 Hz <1.5%, 0.2 Hz <0.3%
- Decreasing or stable

**Adequate Control**:
- 0.1 Hz 18-22%, 0.15 Hz 1.5-2.5%, 0.2 Hz 0.3-0.5%
- Stable

**Control Issues**:
- 0.1 Hz >22%, 0.15 Hz >2.5%, 0.2 Hz >0.5%
- Increasing trend

### Panel 3: Directional Balance

**Balanced**:
- Lines within 0.2% of each other
- Both trending similarly

**Minor Asymmetry**:
- Lines differ by 0.2-0.4%
- Explainable by seasonal factors

**Significant Asymmetry**:
- Lines differ by >0.4%
- One direction consistently higher
- Investigate systematic bias

### Panel 4: Demand Forecasting

**Good Forecasting**:
- Unforeseen <500 MW average
- Decreasing trend

**Acceptable Forecasting**:
- Unforeseen 500-540 MW average
- Stable

**Forecasting Issues**:
- Unforeseen >540 MW average
- Increasing trend

---

## Troubleshooting

### No data displayed in panels
- Check date range includes months with data
- Verify processed data files exist
- Ensure Update Analysis button clicked
- Review console for data loading errors

### Unexpected spikes in single month
- Check for data completeness (partial month data?)
- Review operational logs for major events
- Consider weather anomalies
- Verify data quality for that month

### Trends don't match expectations
- Confirm analysis period settings
- Check demand metric selection (ND vs TSD)
- Verify against other tabs for consistency
- Consider seasonal normalization

### Panel 4 shows unforeseen higher than total
- This is mathematically possible when damping works opposite to total change
- Example: Demand drops 100 MW, but frequency rises (adding 50 MW via damping), so unforeseen = -150 MW
- Check specific events to understand interaction

### Inconsistent month-to-month changes
- Natural variability expected
- Look for 3+ month trends rather than single month
- Account for different month lengths
- Consider external factors (weather, events)
