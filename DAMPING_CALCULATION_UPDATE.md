# Demand Damping Calculation Update

## Summary
Changed from **fixed coefficient** (1500 MW/Hz) to **dynamic calculation** using actual demand values at each SP boundary.

## Changes Made

### 1. Config File (`config/config.yml`)
**Before:**
```yaml
unforeseen_demand:
  demand_damping:
    coefficient: 1500  # MW/Hz - typical damping coefficient for GB system
```

**After:**
```yaml
unforeseen_demand:
  demand_damping:
    percentage_per_hz: 0.025  # 2.5% of demand per Hz (NESO standard: pph = 0.025)
```

### 2. Code Changes (`R/analysis_unforeseen_demand.R`)

#### Function: `calculate_demand_damping()`
**Before:**
```r
coeff <- damping_config$coefficient
data[, (damping_col) := abs_freq_change * coeff]
```

**After:**
```r
pct_per_hz <- damping_config$percentage_per_hz
data[, (damping_col) := get(metric) * pct_per_hz * abs_freq_change]
```

**Formula Change:**
- Old: `Damping = Δf × 1500 MW/Hz` (fixed)
- New: `Damping = Demand × 2.5% × Δf` (dynamic)

## Impact Examples

### Scenario 1: Low Demand (35 GW, Night Time)
- Frequency change: -0.10 Hz
- **Old method**: 0.10 × 1500 = **150 MW** damping
- **New method**: 35,000 × 0.025 × 0.10 = **87.5 MW** damping
- **Difference**: 62.5 MW (71% overestimation with old method)

### Scenario 2: High Demand (60 GW, Peak Time)
- Frequency change: -0.10 Hz
- **Old method**: 0.10 × 1500 = **150 MW** damping
- **New method**: 60,000 × 0.025 × 0.10 = **150 MW** damping
- **Difference**: 0 MW (old method was calibrated for peak demand)

### Scenario 3: Medium Demand (45 GW, Typical)
- Frequency change: -0.08 Hz
- **Old method**: 0.08 × 1500 = **120 MW** damping
- **New method**: 45,000 × 0.025 × 0.08 = **90 MW** damping
- **Difference**: 30 MW (33% overestimation with old method)

## Benefits

1. **Accuracy**: Damping calculation now reflects actual system demand at each SP
2. **NESO Standard**: Uses official 2.5% per Hz coefficient (pph = 0.025)
3. **Time-varying**: Correctly accounts for demand variations throughout the day
4. **Metric-specific**: Each demand metric (ND, TSD, ENGLAND_WALES_DEMAND) uses its own actual value

## Validation

To verify the changes are working correctly, run:
```bash
Rscript main.R unforeseen_demand
```

Look for console output:
```
INFO: Calculating demand damping component using actual demand...
  Damping percentage: 2.5 % per Hz (NESO standard)
  Using formula: Damping (MW) = Demand (MW) × 0.025 × |Δf (Hz)|
```

Check output file for updated damping values:
```bash
head data/output/reports/unforeseen_demand_events.csv
```

## Reference
NESO documentation: Demand damping coefficient pph = 0.025 (2.5% per Hz)
- Used in FSE2.0 Model and pre-fault imbalance quantification
- Formula: P_load_damping = demand × (D/100) × (f - f_nom)
