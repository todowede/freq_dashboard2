# Recent Updates to NESO Frequency Analysis Dashboard

## Version: November 2025

### New Analysis Capabilities

#### 1. System Imbalance Calculation
- **File:** `R/analysis_imbalance_calculation.R`
- **Output:** `data/output/imbalance/sp_boundary_imbalances.csv` (35 MB, 182,840 seconds)
- **Description:** Calculates power imbalances at SP boundaries using system inertia, demand, and frequency response characteristics
- **Formula:** `Imbalance = -LF_response - HF_response - Demand_damping + RoCoF_component`
- **Configuration:** Can calculate for all SP boundaries or only RED events

#### 2. Demand Analysis with Damping Separation
- **File:** `R/analysis_demand.R`
- **Output:** `data/output/reports/demand_changes.csv`
- **Description:** Analyzes demand changes at SP boundaries, separating natural frequency damping (2.5% per Hz) from market-driven changes
- **Metrics:** ND, TSD, ENGLAND_WALES_DEMAND

#### 3. Unforeseen Demand Event Detection
- **File:** `R/analysis_unforeseen_demand.R`
- **Output:** `data/output/reports/unforeseen_demand_events.csv`
- **Description:** Identifies unexpected demand changes that cannot be explained by:
  - Natural frequency damping
  - Normal forecasting variations (±2.5 SD from hourly mean)
- **Detection Logic:**
  - Statistical threshold: `|Unforeseen - hourly_mean| > 2.5 × hourly_SD`
  - Causality threshold: Both `|Demand_change| > 800 MW` AND `|Freq_change| > 0.05 Hz`

#### 4. Monthly Imbalance Aggregation
- **File:** `R/analysis_monthly_imbalance.R`
- **Output:** `data/output/reports/monthly_imbalance_summary.csv`
- **Description:** Aggregates event-based imbalance data by month
- **Metrics:** Mean, median, max, P95, P99 absolute imbalance (MW)

#### 5. Monthly Unforeseen vs Total Demand Comparison
- **File:** `R/analysis_monthly_unforeseen_comparison.R`
- **Output:** `data/output/reports/monthly_unforeseen_comparison.csv`
- **Description:** Monthly comparison of total demand changes vs unforeseen (market-driven) component
- **Metrics:** Mean, median, max, P95 for both total change and unforeseen component, plus deviation metrics

### New Dashboard Features

#### Dashboard Tab Structure (Now 10 Tabs)
1. **Overview** - Configuration parameters and summary statistics
2. **SP Boundary Events** - Browse and filter detected events
3. **System Dynamics** - Response analysis, imbalance calculation, demand vs frequency
4. **Demand Analysis** - Daily profiles, SP boundary changes, correlation analysis
5. **Unforeseen Patterns** - Event counts, hourly distribution, severity, time series
6. **Frequency & ROCOF** - Interactive time series plots
7. **Frequency KPI** - Quality monitoring by settlement period
8. **Frequency Excursion** - Daily excursion counts and durations
9. **Monthly Trends** - 8 analysis panels (NEW FEATURES BELOW)
10. **Monthly Red Ratio** - Static monthly trend plots (legacy view)

#### New Monthly Trends Panels
- **Panel 7: Monthly System Imbalance Level**
  - Shows mean, max, and 95th percentile absolute imbalance over time
  - Interactive dual-axis plot
  
- **Panel 8: Monthly Unforeseen vs Total Demand Change Comparison**
  - Compares total demand changes at SP boundaries with unforeseen component
  - Shows deviation of market-driven changes from total demand changes
  - Interactive line plot with metric selector

### Updated Workflow

The complete pipeline now includes 13 steps:
1. Data acquisition from NESO API
2. Data loading and cleaning
3. Per-second frequency processing with ROCOF
4. SP boundary event detection
5. Frequency KPI calculation
6. Frequency excursion analysis
7. System response and holding analysis
8. Demand analysis with damping separation (**NEW**)
9. Unforeseen demand event detection (**NEW**)
10. System imbalance calculation (**NEW**)
11. Monthly imbalance aggregation (**NEW**)
12. Monthly unforeseen vs total demand comparison (**NEW**)
13. Report and plot generation

### Configuration Updates

New configuration sections in `config/config.yml`:

```yaml
imbalance_calculation:
  calculate_for_red_events_only: false
  event_selection:
    mode: "all"
    max_events: 0
  system_data:
    inertia_source: "data/input/system_inertia.csv"
    demand_source: "data/input/system_demand.csv"
    response_source: "data/output/reports/system_dynamics_review.csv"
  demand_damping_percent_per_hz: 2.5
  default_inertia_gvas: 150
  default_demand_mw: 35000

unforeseen_demand:
  enabled: true
  demand_damping:
    percentage_per_hz: 0.025
    apply_direction: true
  statistical_threshold:
    sd_multiplier: 2.5
  causality:
    demand_threshold_mw: 800
    freq_threshold_hz: 0.05
```

### New Input Data Requirements

To use the imbalance calculation features, you need:

1. **System Inertia Data** (`data/input/system_inertia.csv`):
   - Columns: `dtm_sec`, `inertia_gvas`
   - System inertia in GVA·s per second

2. **System Demand Data** (`data/input/system_demand.csv`):
   - Columns: `SETTLEMENT_DATE`, `SETTLEMENT_PERIOD`, `ND`, `TSD`, `ENGLAND_WALES_DEMAND`
   - Demand in MW for each settlement period

### Key Statistics from Sample Data (May-October 2025)

**System Imbalance:**
- Mean absolute imbalance: 147-165 MW per month
- Maximum absolute imbalance: 746-964 MW
- 95th percentile: 378-419 MW
- Total events analyzed: 5,903 SP boundaries (182,840 seconds)

**Unforeseen Demand Events:**
- Typical ratio: ~100% of demand changes are unforeseen (market-driven)
- Indicates most SP boundary demand changes are forecasting errors, not natural damping
- Small deviations observed in 2025 data showing minimal damping contribution

### Documentation Updates

The README.md has been expanded to include:
- Detailed feature descriptions
- System imbalance and unforeseen demand formulas
- Configuration examples for all new features
- Key concepts section explaining physical interpretation
- Usage examples for running individual analysis steps
- Troubleshooting guidance

### Breaking Changes

None. All existing functionality remains unchanged. New features are additive.

### Performance Notes

- **Imbalance calculation for all SP boundaries:** ~11 minutes for 5,903 events
- **Output file size:** `sp_boundary_imbalances.csv` is 35 MB (182,840 rows)
- Recommended to run imbalance calculation overnight for large datasets

### Next Steps

To use the new features:
1. Update your `config/config.yml` with new parameters (see README)
2. Ensure system inertia and demand CSV files are in `data/input/`
3. Run full pipeline: `Rscript main.R`
4. Launch dashboard: `Rscript -e "shiny::runApp('dashboard.R')"`
5. Explore new tabs: System Dynamics, Demand Analysis, Unforeseen Patterns, Monthly Trends Panel 7 & 8

## Support

For issues or questions, please refer to the updated README.md for detailed documentation.
