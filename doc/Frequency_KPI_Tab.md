# Frequency KPI Tab Documentation

## Overview

The Frequency KPI tab analyzes frequency quality performance using standardized quality categories (RED, AMBER, BLUE, GREEN). It contains two sub-tabs: KPI Analysis for detailed time-based analysis and Static Monthly Red Ratio for long-term trend visualization.

---

## Sub-Tab 1: KPI Analysis

### Purpose
Provides detailed visualization of frequency quality distribution patterns across settlement periods and time.

### Features

#### 1. Filter Options
Controls for selecting analysis time period:

- **Filter By**
  - Radio buttons: Date Range or Month
  - Month option selected by default

- **Select Month**
  - Dropdown showing available months (e.g., "May 2025")
  - Filters all visualizations to selected month

- **Update Plots Button**
  - Applies selected filter and refreshes visualizations

#### 2. Quality Distribution by Settlement Period (Stacked Bar Chart)

**Purpose**: Shows percentage breakdown of quality categories for each of the 48 daily settlement periods.

**Visual Design**:
- **Chart Type**: 100% stacked bar chart
- **X-Axis**: Settlement Period (1-48)
  - 1-24: Midnight to noon
  - 25-48: Noon to midnight
  - Each SP represents a 30-minute interval

- **Y-Axis**: Average Percentage (%)
  - Always scales 0-100%
  - Shows proportion of time in each quality category

- **Color Legend**:
  - **Red**: RED category (poorest quality)
  - **Orange**: AMBER category
  - **Blue**: BLUE category
  - **Green**: GREEN category (best quality)

- **Interactive Elements**:
  - Hover tooltip shows: Settlement Period number, percentage value, category label
  - Example: "settlement_period: 9, percentage: 83.3976387710, category_label: Green"

**Data Source**:
- Input: `data/processed/frequency_kpi_results.csv`
- Aggregates frequency quality classifications by settlement period

**Interpretation**:
- **Dominant GREEN**: Indicates good frequency control during that SP
- **RED/AMBER presence**: Shows settlement periods with frequent quality issues
- **Patterns to look for**:
  - Morning ramp (SPs 8-14): Often shows AMBER/BLUE as demand rises
  - Evening peak (SPs 32-38): May show quality degradation
  - Night valleys (SPs 1-7, 45-48): Typically show high GREEN percentage
  - Specific SPs with consistent RED: Indicates systematic issues

**Business Value**:
- Identify problematic settlement periods requiring operational attention
- Optimize scheduling of generation dispatch and balancing actions
- Target specific times for enhanced monitoring or reserves
- Support capacity planning for different demand periods

---

#### 3. Daily Quality Metrics Time Series

**Purpose**: Shows day-by-day trends in quality category percentages over the selected month.

**Visual Design**:
- **Chart Type**: Multi-line time series
- **X-Axis**: Date (e.g., May 05, May 12, May 19, May 26)
  - Displays dates from selected month

- **Y-Axis**: Average Daily Percentage (%)
  - Scale: 0-100%
  - Shows percentage of SPs in each category per day

- **Lines**:
  - **Green line**: GREEN category percentage (typically 70-90%)
  - **Blue line**: BLUE category percentage (typically 5-20%)
  - **Orange line**: AMBER category percentage (typically 0-10%)
  - **Red line**: RED category percentage (typically 0-10%)

**Data Source**:
- Input: `data/processed/frequency_kpi_results.csv`
- Aggregates quality by date within filtered period

**Interpretation**:
- **GREEN line dips**: Days with worse frequency quality
- **RED line spikes**: Days with significant frequency disturbances
- **Stable patterns**: Consistent system performance
- **Weekend vs weekday**: Different demand patterns may show different quality profiles

**Example Insights**:
- Sudden GREEN drop from 85% to 65% on specific day indicates operational issue
- Corresponding RED spike suggests multiple disturbances occurred
- Gradual trends show seasonal or demand-driven changes

**Business Value**:
- Identify specific days requiring post-event analysis
- Correlate quality changes with operational events or weather patterns
- Track improvement or degradation over time
- Support daily performance reporting

---

## Sub-Tab 2: Static Monthly Red Ratio

### Purpose
Displays long-term trends in RED event frequency across months and years to identify seasonal patterns and year-over-year changes.

### Features

#### 1. Section Description
Text explanation: "This section displays static plots showing the monthly Red event ratio trends - the percentage of SP boundaries that were classified as Red events each month."

#### 2. All Years (Faceted View)

**Purpose**: Shows RED event ratio trends separately for each year.

**Visual Design**:
- **Chart Type**: Line chart with facets
- **Faceting**: Separate panel for each year (e.g., 2025 shown)
- **X-Axis**: Month (May, Jun, Jul, Aug)
- **Y-Axis**: Red Ratio (%)
  - Shows percentage of SP boundaries classified as RED
  - Scale: 0-5% (typical range)

- **Line**:
  - Red/coral colored line with markers
  - Connects monthly RED ratio values

**Data Source**:
- Input: `data/processed/sp_boundary_events_enriched.csv`
- Aggregated by month to calculate RED event percentage

**Interpretation**:
- **Rising trend**: Increasing frequency quality issues over months
- **Falling trend**: Improving system performance
- **Seasonal patterns**:
  - Higher in transitional months (spring/autumn) due to variable demand
  - Lower in stable demand periods (mid-summer, mid-winter)

**Example Reading** (from screenshot):
- May 2025: ~3% RED ratio
- June 2025: Peak at ~4.5% RED ratio
- July 2025: Declining to ~2% RED ratio
- August 2025: Stable at ~1.8% RED ratio

---

#### 3. All Years (Overlay View)

**Purpose**: Compare RED ratio trends across multiple years on the same plot to identify year-over-year changes.

**Visual Design**:
- **Chart Type**: Multi-line overlay chart
- **X-Axis**: Month (May, Jun, Jul, Aug)
- **Y-Axis**: Red Ratio (%)
  - Scale: 0-5%

- **Lines**:
  - Each year plotted as separate line
  - 2025 shown in blue (most recent year)
  - Other years would appear in different colors

**Data Source**:
- Same as faceted view: `data/processed/sp_boundary_events_enriched.csv`
- Enables direct year-over-year comparison

**Interpretation**:
- **Lines above others**: Year with worse RED performance
- **Lines below others**: Year with better performance
- **Similar patterns**: Indicates consistent seasonal effects
- **Diverging patterns**: Suggests operational or grid configuration changes

**Business Value**:
- Benchmark current year against historical performance
- Identify if current trends are typical or unusual
- Support annual performance reporting and target setting
- Validate effectiveness of operational improvements

---

## Quality Categories Explained

The KPI system classifies frequency quality into four categories:

| Category | Color | Criteria | Meaning |
|----------|-------|----------|---------|
| **RED** | Red | Most severe deviations | Significant frequency disturbance requiring investigation |
| **AMBER** | Orange | Moderate deviations | Noticeable frequency variation, monitor closely |
| **BLUE** | Blue | Minor deviations | Small frequency variation, acceptable |
| **GREEN** | Green | Minimal deviations | Excellent frequency control, target state |

Quality classification is based on:
- Frequency deviation magnitude (Δf from 50 Hz)
- Rate of Change of Frequency (ROCOF)
- Duration of deviation
- Trend direction (up/down)

---

## Cross-Feature Workflow

### Typical Analysis Flow
1. **Start with Static Monthly Red Ratio**: Identify months with unusually high RED ratios
2. **Switch to KPI Analysis**: Select problematic month using filter
3. **Review Stacked Bar Chart**: Identify specific settlement periods with quality issues
4. **Review Daily Time Series**: Find specific days with quality degradation
5. **Navigate to SP Boundary Events tab**: Deep-dive into specific RED events on those days

### Use Cases

#### Use Case 1: Monthly Performance Review
1. View Static Monthly Red Ratio (Faceted View) to see latest month performance
2. Compare with Overlay View to benchmark against previous years
3. If RED ratio above target (e.g., >2%), investigate further
4. Use KPI Analysis to identify which SPs and days contributed most

#### Use Case 2: Operational Pattern Analysis
1. Filter KPI Analysis to specific month
2. Review Stacked Bar Chart for SP patterns:
   - Are morning ramps causing issues? (SPs 8-14)
   - Are evening peaks problematic? (SPs 32-38)
   - Are specific transitions consistently RED?
3. Use insights to adjust operational procedures or reserves

#### Use Case 3: Year-over-Year Comparison
1. View Static Monthly Red Ratio (Overlay View)
2. Compare current year line with previous years
3. If current year trending worse:
   - Check for grid configuration changes
   - Review demand forecast accuracy
   - Assess generation mix changes
4. Report findings for strategic planning

---

## Technical Details

### Quality Classification
- Each second of frequency data is classified into RED/AMBER/BLUE/GREEN
- SP-level quality determined by aggregating second-by-second classifications
- Daily percentages calculated from 48 SPs per day
- Monthly RED ratio calculated as: (RED SP boundaries / Total SP boundaries) × 100%

### Time Aggregations
- **Stacked Bar Chart**: Averages across all days in selected period for each SP
- **Daily Time Series**: Daily aggregation across all 48 SPs
- **Monthly Red Ratio**: Monthly aggregation across all days

### Data Quality
- Requires complete frequency_kpi_results.csv with quality classifications
- Missing data for specific SPs/days excluded from averages
- Monthly plots generated during analysis pipeline, not dynamic

---

## Best Practices

1. **Regular Monitoring**: Review Static Monthly Red Ratio monthly to track performance trends
2. **Drill-down approach**: Start broad (monthly trends), narrow to specific SPs and days
3. **Context matters**: Consider external factors (weather, outages, demand patterns) when interpreting trends
4. **Threshold setting**: Define acceptable RED ratio targets (e.g., <2% monthly)
5. **Action triggers**: Set specific thresholds that trigger deeper investigation
6. **Seasonal awareness**: Compare like-for-like months across years, not sequential months

---

## Interpretation Guide

### Stacked Bar Chart Patterns

**Healthy Pattern**:
- 80%+ GREEN across most SPs
- Small BLUE/AMBER percentages
- Minimal or no RED

**Warning Pattern**:
- GREEN below 70% for multiple SPs
- AMBER/BLUE together exceed 25%
- Consistent RED presence (even if small)

**Critical Pattern**:
- RED exceeds 5% for any SP
- GREEN below 50% for any SP
- Multiple consecutive SPs showing poor quality

### Daily Time Series Patterns

**Stable Performance**:
- GREEN line consistently 80-95%
- Other lines flat and low (<5% each)
- Minimal day-to-day variation

**Deteriorating Performance**:
- GREEN line trending downward
- RED line trending upward
- Increasing volatility across days

**Event Day**:
- Sharp GREEN drop on specific date
- Corresponding RED spike
- Other days showing normal patterns

### Monthly Red Ratio Patterns

**Good Performance**:
- RED ratio consistently below 2%
- Stable or declining trend
- Current year equal to or better than previous years

**Performance Issues**:
- RED ratio above 3%
- Rising trend over multiple months
- Current year significantly worse than previous years

**Seasonal Normal**:
- Similar pattern across multiple years
- Predictable peaks/troughs
- Within historical range

---

## Troubleshooting

### Plots not updating
- Ensure filter selection is valid (month has data)
- Click "Update Plots" button after changing filters
- Check browser console for errors

### Static Monthly Red Ratio shows no data
- Verify `data/processed/sp_boundary_events_enriched.csv` exists
- Confirm monthly plots generated during pipeline execution
- Check date range of data covers expected months

### Unexpected quality distribution
- Verify quality thresholds configured correctly in config.yml
- Check frequency data quality (missing values can affect classification)
- Review event detection parameters for calibration

### Percentages don't sum to 100%
- This is expected - unclassified or missing periods excluded
- Check data coverage for the selected period
- Review logs for data loading warnings
