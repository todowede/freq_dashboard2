# PART 5: DEMAND ANALYSIS MODULES

---

## 5.1 Demand Analysis Tab

**Purpose**: Understand demand patterns at Settlement Period boundaries to identify systematic demand changes that stress the power system.

---

### 5.1.1 The Demand-Frequency Connection

**Critical Relationship**:
```
Market-Driven Demand Change at SP Boundary
  ↓
Generation Lag (can't instantly match)
  ↓
Power Imbalance
  ↓
Frequency Deviation
```

**Why SP Boundaries Matter**:
Every 30 minutes (at :00 and :30), the electricity market transitions to a new Settlement Period. This causes:
1. **Different generators** scheduled to run
2. **Industrial loads** switching on/off based on price signals
3. **Natural demand cycles** (people waking up, going to work, cooking dinner)

**The Problem**: Generation was scheduled based on FORECAST demand, but ACTUAL demand may differ.

---

### 5.1.2 Demand Metrics Explained

The dashboard tracks **three demand metrics**:

**1. ND (National Demand)**
- **Definition**: Total electricity demand across Great Britain
- **Includes**: All transmission-connected and distribution-connected loads
- **Typical Range**: 20,000 - 45,000 MW
- **Use Case**: Primary metric for overall system demand

**2. TSD (Transmission System Demand)**
- **Definition**: Demand visible to the transmission network
- **Difference**: TSD > ND because it includes embedded generation effects
- **Use Case**: Operational planning

**3. ENGLAND_WALES_DEMAND**
- **Definition**: Regional demand (excludes Scotland)
- **Typical Relation**: 85-90% of National Demand
- **Use Case**: Regional analysis

**For This Dashboard**: We primarily use **ND** as it's the most comprehensive metric.

---

### 5.1.3 Demand Changes at SP Boundaries (Bar Chart)

**What**: Shows the change in demand (ΔMW) from one SP to the next

**Formula**:
```
ΔND(SP_n) = ND(SP_n) - ND(SP_n-1)

Example:
SP 25 (12:00): ND = 35,000 MW
SP 26 (12:30): ND = 37,200 MW
ΔND(SP 26) = 37,200 - 35,000 = +2,200 MW
```

**Visual Interpretation**:

```
           +2000 MW ↑ (Demand increased)
           +1500 MW ↑
           +1000 MW ↑
 ━━━━━━━━━━━━━ 0 ━━━━━━━━━━━━━ (No change)
           -500 MW  ↓
           -800 MW  ↓ (Demand decreased)
           -1200 MW ↓
```

**What Bars Up Mean**: Demand **increased** from previous SP
- Typical: Morning ramp (6am-9am), evening peak (5pm-7pm)
- Generators must INCREASE output to match
- Risk: If increase is larger than forecast, frequency drops

**What Bars Down Mean**: Demand **decreased** from previous SP
- Typical: Late evening (9pm-midnight), overnight (midnight-6am)
- Generators must DECREASE output to match
- Risk: If decrease is larger than forecast, frequency rises

---

### 5.1.4 Reading the Demand Changes Plot

**Example Analysis** (Typical Weekday):

```
SP 1-12 (00:00-06:00):
Bars: Mostly DOWN (negative) or small
Interpretation: Night time, demand falling then stable
Changes: -200 to -500 MW per SP

SP 13-18 (06:00-09:00):
Bars: LARGE UP (positive)
Interpretation: Morning ramp - people waking, businesses starting
Changes: +1,000 to +2,500 MW per SP ← HIGH RISK PERIOD

SP 19-24 (09:00-12:00):
Bars: Small UP or FLAT
Interpretation: Daytime plateau, demand stable
Changes: +200 to +500 MW per SP

SP 25-30 (12:00-15:00):
Bars: Slightly DOWN
Interpretation: Lunchtime lull, some industrial loads reduce
Changes: -100 to -400 MW per SP

SP 31-38 (15:00-19:00):
Bars: LARGE UP (positive)
Interpretation: Evening peak - people returning home, cooking dinner
Changes: +500 to +1,500 MW per SP ← HIGH RISK PERIOD

SP 39-48 (19:00-24:00):
Bars: DOWN (negative)
Interpretation: Evening wind-down, demand falling
Changes: -300 to -800 MW per SP
```

**Business Insight**: The **largest bars** (either direction) represent the highest risk periods for frequency events, because large demand changes are hardest to forecast accurately.

---

### 5.1.5 Hourly Demand Pattern (Line Chart with Shaded Region)

**What**: Shows typical demand pattern across 24 hours, aggregated across the analysis period

**Visual Elements**:
- **Red Line**: Mean (average) National Demand for each hour
- **Pink Shaded Region**: Min-Max envelope (not standard deviation!)
- **X-Axis**: Hour of day (0-23)
- **Y-Axis**: Demand (MW)

**What the Shaded Region Means**:

**IMPORTANT CLARIFICATION**:
The shaded area shows the **absolute minimum and maximum** demand ever observed at that hour across the entire analysis period (May-August 2025).

**Formula**:
```
For hour H:
  Upper Bound = MAX(ND at hour H across all days)
  Lower Bound = MIN(ND at hour H across all days)
  Red Line = MEAN(ND at hour H across all days)
```

**Example**:
```
Hour 18 (6pm):
  Maximum observed: 42,000 MW (hottest summer day, World Cup match)
  Minimum observed: 28,000 MW (mild Sunday, low industrial activity)
  Average: 35,000 MW

Shaded region: 28,000 - 42,000 MW (range of 14,000 MW!)
```

**Why This Matters**:
The **width** of the shaded region shows the **variability** NESO must be prepared for:
- **Narrow region** (e.g., 3am): Demand predictable (±2,000 MW)
- **Wide region** (e.g., 6pm): Demand highly variable (±7,000 MW) → Harder to forecast

**Operational Insight**:
"At 6pm, we must be prepared for demand anywhere between 28-42 GW. Our forecasting error could be up to 7 GW in extreme cases."

---

### 5.1.6 Typical Demand Pattern Interpretation

**Reading the Hourly Pattern**:

```
00:00-06:00 (Night):
Mean: ~22,000 MW
Range: 18,000 - 26,000 MW
Interpretation: Low, stable demand. Narrow range = predictable.

06:00-09:00 (Morning Ramp):
Mean: 25,000 → 32,000 MW (rising rapidly)
Range: Widening (20,000 - 38,000 MW at 9am)
Interpretation: Steepest increase of the day. Widening range = challenging forecasts.

09:00-17:00 (Daytime):
Mean: 32,000 - 35,000 MW (plateau with slight dip at lunch)
Range: 26,000 - 42,000 MW
Interpretation: Peak business hours, but demand varies significantly based on:
  - Weather (air conditioning in summer)
  - Day of week (weekday vs weekend)
  - Industrial activity

17:00-20:00 (Evening Peak):
Mean: Peak at ~35,000 MW (around 18:00-19:00)
Range: WIDEST (28,000 - 43,000 MW)
Interpretation: Most variable period - domestic demand (heating, cooking, TV)
combines with still-active business loads. Weather-sensitive.

20:00-24:00 (Evening Decline):
Mean: Falling from 35,000 → 25,000 MW
Range: Narrowing
Interpretation: Predictable decline as loads switch off.
```

---

### 5.1.7 Demand Data at SP Boundaries (Table)

**What**: Detailed dataset of demand at every Settlement Period

**Columns**:

| Column | Description | Example Value |
|--------|-------------|---------------|
| **Date** | SP start date/time | 2025-05-29 18:00 |
| **SP** | Settlement Period number | 38 |
| **ND** | National Demand (MW) | 35,284 |
| **TSD** | Transmission System Demand (MW) | 37,156 |
| **Delta_ND** | Change from previous SP (MW) | +1,247 |
| **Delta_TSD** | TSD change from previous SP (MW) | +1,189 |

**Interactive Features**:
- **Filter by Date**: Analyze specific days
- **Sort by Delta_ND**: Find largest demand changes
- **Export**: Download for external analysis

**Use Cases**:

**Use Case 1: Identify Largest Demand Swings**
```
Action: Sort by Delta_ND (descending)
Result: Top 10 largest increases
Analysis:
  - Do these correlate with frequency events?
  - What time of day do they occur?
  - Are they on specific days (e.g., Mondays)?
```

**Use Case 2: Day-Type Analysis**
```
Action: Filter for Sundays only
Result: Compare demand patterns for weekends
Insight: Sunday demand changes are typically smaller
→ Lower risk of frequency events on Sundays
```

**Use Case 3: Cross-Reference with Events**
```
Action: Filter for dates with Red events
Result: Identify demand conditions during events
Question: Was there an unusually large Delta_ND?
→ If YES: Event was demand-driven (forecasting error)
→ If NO: Event was generation-driven (generator trip)
```

---

## 5.2 Unforeseen Demand Tab

**Purpose**: Separate **market-driven** demand changes from **frequency-driven** demand damping to identify true forecasting errors.

---

### 5.2.1 The Fundamental Problem

When frequency drops from 50.0 Hz to 49.85 Hz, demand automatically reduces by ~130 MW (for 35,000 MW base demand). This is **demand damping** - a natural physical phenomenon.

**The Challenge**:
```
Observed Demand Change = Market-Driven Change + Frequency-Driven Damping

Example:
Observed ΔND = -200 MW
Frequency fell by 0.10 Hz
Damping effect = 35,000 × 0.025 × (-0.10) = -87.5 MW

Therefore:
Market-Driven Change = -200 - (-87.5) = -112.5 MW

Real demand actually dropped by 112.5 MW, but frequency damping made it look like 200 MW.
```

**Why This Matters**:
- **For Forecasters**: Need to understand TRUE demand changes to improve models
- **For Grid Operators**: Must separate predictable (SP changes) from unpredictable (frequency response)
- **For Event Analysis**: Determine if event was caused by demand or generation

---

### 5.2.2 Unforeseen Demand Calculation

**Step-by-Step Methodology**:

**Step 1: Extract Frequency at SP Boundary**
```
For each SP boundary (e.g., 12:30:00):
  - Get frequency 1 second before: f(-1s) = 50.02 Hz
  - Get frequency at boundary: f(0s) = 49.95 Hz
  - Calculate Δf = 49.95 - 50.02 = -0.07 Hz
```

**Step 2: Determine Damping Direction**
The dashboard uses **frequency trend** to determine if damping helps or hinders:

```
If frequency is FALLING (Δf < 0):
  → Demand naturally REDUCES (helps stabilize)
  → Damping_MW = Demand × 0.025 × Δf (NEGATIVE value)

If frequency is RISING (Δf > 0):
  → Demand naturally INCREASES (worsens rise)
  → Damping_MW = Demand × 0.025 × Δf (POSITIVE value)
```

**Step 3: Remove Damping from Observed Change**
```
Unforeseen Demand = (ND_new - ND_old) - Damping_MW
```

**Complete Example**:

```
SP 37 → SP 38 (17:30 → 18:00)

Observed:
  ND(SP 37) = 34,500 MW
  ND(SP 38) = 36,200 MW
  Observed Change = +1,700 MW

Frequency Data:
  f(-1s) = 50.01 Hz
  f(0s) = 49.92 Hz
  Δf = -0.09 Hz (frequency FELL)

Damping Calculation:
  Base Demand = 34,500 MW (using SP 37 as baseline)
  Damping = 34,500 × 0.025 × (-0.09) = -77.6 MW

  Interpretation: Demand reduced by 77.6 MW due to frequency drop

Unforeseen Demand:
  Unforeseen = 1,700 - (-77.6) = 1,777.6 MW

Interpretation:
  - Market expected demand to increase by ~1,600 MW (forecast)
  - Actual market-driven increase was 1,777.6 MW
  - Forecasting error: +177.6 MW (demand higher than expected)
  - PLUS frequency damping masked an additional 77.6 MW
  - Total observed increase: 1,700 MW
```

---

### 5.2.3 Unforeseen Demand Summary Panel

**Metrics Displayed**:

**1. Total Unforeseen Events**
- **Definition**: Number of SPs where unforeseen demand exceeded threshold
- **Threshold**: |Unforeseen - Hourly Mean| > 2.5 standard deviations
- **Typical Value**: 50-80 events per 4-month period
- **Interpretation**: How often do we have significant forecasting surprises?

**2. Average Unforeseen Demand**
- **Definition**: Mean absolute unforeseen demand across all SPs
- **Formula**: `Mean(|Unforeseen_MW|)`
- **Typical Value**: 100-200 MW
- **Business Meaning**: Average forecasting error magnitude

**3. Max Unforeseen Demand**
- **Definition**: Largest single unforeseen demand change
- **Typical Value**: 800-1,500 MW
- **Critical Metric**: Worst-case forecasting error
- **Action Trigger**: If >2,000 MW → Investigate forecast model failure

**4. Unforeseen Demand Std Dev**
- **Definition**: Variability in forecasting errors
- **Formula**: Standard deviation of unforeseen demand values
- **Interpretation**:
  - Low σ (50-100 MW): Consistent forecasting quality
  - High σ (200-300 MW): Erratic, unpredictable errors

---

### 5.2.4 Unforeseen Demand Distribution (Histogram)

**What**: Frequency distribution of unforeseen demand magnitudes

**X-Axis**: Unforeseen Demand (MW), binned
**Y-Axis**: Count of occurrences

**Ideal Distribution** (Good Forecasting):
```
Centered at 0 MW (no systematic bias)
Narrow spread (σ < 150 MW)
Shape: Normal/Gaussian

Example:
-200 to -100 MW: ██ 12
-100 to 0 MW: ████████ 145
0 to +100 MW: ████████ 152
+100 to +200 MW: ██ 15
+200 to +300 MW: █ 3
```
**Interpretation**: Forecasts are unbiased and accurate.

**Problem Distribution 1: Biased**
```
-100 to 0 MW: ██ 25
0 to +100 MW: █████ 80  ← Skewed
+100 to +200 MW: ████ 65
+200 to +300 MW: ███ 45
+300 to +400 MW: ██ 20
```
**Interpretation**: Systematic UNDER-forecasting (demand consistently higher than predicted)
**Action**: Recalibrate forecast models with upward bias correction

**Problem Distribution 2: Fat Tails**
```
-500 to -400 MW: ██ 15 ← Outliers
...
-100 to +100 MW: ████ Normal
...
+400 to +500 MW: ██ 18 ← Outliers
```
**Interpretation**: Occasional extreme errors despite generally good forecasts
**Action**: Investigate outlier events for common patterns

---

### 5.2.5 Unforeseen Demand Over Time (Line Chart)

**What**: Time series of unforeseen demand at each SP boundary

**Visual Elements**:
- **Blue Line**: Unforeseen demand (MW)
- **Orange Line**: Demand damping contribution (MW)
- **Zero Line**: Perfect forecast

**Reading the Plot**:

**Example Period Analysis**:
```
May 1-7:
  Unforeseen mostly within ±200 MW
  Damping (orange) small and variable
  → Good forecasting week

May 8:
  Unforeseen spikes to +1,200 MW
  Damping = -80 MW
  → Major under-forecast event
  → Cross-reference: Check for weather anomaly, special event

May 15-20:
  Unforeseen consistently +300 to +500 MW
  → Systematic bias period
  → Possible cause: Heat wave not captured in forecast model
```

**Business Questions Answered**:
1. **Are errors getting worse over time?** (Trend analysis)
2. **Are errors clustered?** (Multi-day forecast failures)
3. **Is damping significant?** (Compare blue vs orange magnitude)

---

### 5.2.6 Unforeseen Demand vs Frequency Events (Scatter Plot)

**What**: Correlation between unforeseen demand and frequency event severity

**Axes**:
- **X-Axis**: Unforeseen Demand (MW)
- **Y-Axis**: Frequency Change (Hz) for events at corresponding SPs
- **Points**: Each event colored by category (Red/Amber/Blue)

**Expected Pattern**:
```
Large Positive Unforeseen (+800 MW)
  → Demand higher than expected
  → Generation shortfall
  → Frequency DROP (-0.15 Hz)
  → Red event

Large Negative Unforeseen (-800 MW)
  → Demand lower than expected
  → Generation excess
  → Frequency RISE (+0.12 Hz)
  → Amber event
```

**Key Insight**: **Strong correlation** indicates demand forecasting errors are a PRIMARY cause of frequency events.

**Weak Correlation**: Events are more likely random generator trips (unpredictable).

---

### 5.2.7 Unforeseen Demand Data Table

**Columns**:

| Column | Description |
|--------|-------------|
| **Date** | SP boundary timestamp |
| **SP** | Settlement Period number |
| **ND** | National Demand (MW) |
| **Delta_ND** | Observed demand change (MW) |
| **Freq_Change** | Frequency change at boundary (Hz) |
| **Damping_MW** | Calculated demand damping (MW) |
| **Unforeseen_Demand** | Market-driven change minus damping (MW) |
| **Hourly_Mean** | Expected change for that hour (statistical baseline) |
| **Deviation** | Unforeseen - Hourly_Mean (MW) |
| **Is_Flagged** | TRUE if |Deviation| > 2.5σ |

**How to Use**:

**Investigation Workflow**:
```
Step 1: Filter for Is_Flagged = TRUE
Step 2: Sort by |Unforeseen_Demand| (descending)
Step 3: Select top 10 worst events
Step 4: For each event:
  - Note Date, Time, Magnitude
  - Check for special circumstances:
    * Weather extreme?
    * Major sporting event?
    * Public holiday?
    * Grid incident elsewhere?
  - Document pattern
Step 5: Update forecasting model to account for identified patterns
```

---

## 5.3 Unforeseen Patterns Tab

**Purpose**: Identify temporal patterns in forecasting errors to enable systematic improvements.

---

### 5.3.1 Why Patterns Matter

Random forecasting errors are unavoidable. But **systematic patterns** are fixable:

```
Random Error: Sometimes +200 MW, sometimes -150 MW (average = 0)
→ Best we can do: Minimize variance

Systematic Pattern: Every Monday 9am, consistently +300 MW
→ Actionable: Adjust Monday 9am forecast upward by 300 MW
```

**Business Value**: Identifying patterns converts uncertain errors into predictable corrections.

---

### 5.3.2 Unforeseen Demand Events by Hour (Bar Chart)

**What**: Count of flagged unforeseen demand events per hour of day

**Purpose**: Identify which hours have the most forecasting difficulties

**Example Analysis**:

```
Hour | Event Count | Interpretation
-----|-------------|---------------
0    | 2           | Night - stable, easy to forecast
3    | 1           | Minimal activity
6    | 12          | Morning ramp - challenging ← Peak
9    | 8           | Business start - variable
12   | 5           | Lunchtime - moderate
15   | 3           | Afternoon - stable
18   | 15          | Evening peak - very challenging ← Peak
21   | 6           | Evening decline - moderate
```

**Business Insight**:
"Focus forecasting model improvements on Hours 6 and 18 - these account for 50% of all forecasting surprises."

**Action**:
- Hour 6: Implement weather-sensitive morning ramp model
- Hour 18: Add behavioral model for domestic evening peak

---

### 5.3.3 Unforeseen Demand Events by Day of Week (Bar Chart)

**What**: Count of flagged events per day (Monday-Sunday)

**Example Pattern**:

```
Day       | Events | Interpretation
----------|--------|---------------
Monday    | 18     | Return to work - high variance ← Peak
Tuesday   | 12     | Settling into week
Wednesday | 10     | Mid-week stability
Thursday  | 11     | Similar to Tuesday
Friday    | 14     | End-of-week variability
Saturday  | 8      | Weekend pattern - different but stable
Sunday    | 6      | Lowest variance ← Most predictable
```

**Business Insight**:
"Mondays are 3× harder to forecast than Sundays. Industrial loads restarting after weekend create uncertainty."

**Action**:
- Develop separate Monday forecast model
- Incorporate weekend weather into Monday predictions
- Consider day-ahead market data on Sunday evening

---

### 5.3.4 Unforeseen Demand Events by Month (Bar Chart)

**What**: Count of flagged events per month

**Example Seasonal Pattern**:

```
Month   | Events | Likely Drivers
--------|--------|---------------
May     | 8      | Mild weather, stable
June    | 12     | Warming, AC load starting
July    | 22     | Peak summer, high variability ← Peak
August  | 15     | Continued summer, slightly more stable
```

**Business Insight**:
"July has 3× more forecast surprises than May. Summer heat waves create unpredictable air conditioning demand."

**Action**:
- Enhance weather-sensitivity of summer forecast models
- Incorporate real-time temperature data for intraday updates
- Build historical temperature-demand response curves

---

### 5.3.5 Average Unforeseen Demand by Hour (Line Chart)

**What**: Mean unforeseen demand (not count, but magnitude) by hour

**Purpose**: Identify systematic bias by time of day

**Example Analysis**:

```
Hour | Avg Unforeseen | Interpretation
-----|----------------|---------------
0-5  | +20 MW         | Slight over-forecast (near zero, good)
6    | +250 MW        | Consistent UNDER-forecast ← Systematic
7-8  | +180 MW        | Continued under-forecast
9-16 | -30 MW         | Slight over-forecast (acceptable)
17   | +50 MW         | Near neutral
18   | +320 MW        | Major UNDER-forecast ← Systematic
19-23| -60 MW         | Slight over-forecast
```

**Critical Finding**: Hours 6 and 18 show **consistent positive bias** (demand higher than forecast).

**Root Cause Hypothesis**:
- Morning (Hour 6): People wake earlier than model assumes in summer
- Evening (Hour 18): Domestic cooking load underestimated

**Correction**:
```
Adjusted Forecast(Hour 6) = Base Forecast + 250 MW
Adjusted Forecast(Hour 18) = Base Forecast + 320 MW

Expected Outcome: Reduce forecasting errors by ~40% at these critical hours
```

---

### 5.3.6 Cross-Tab Analysis: Hour × Day of Week

**What**: Heatmap showing unforeseen demand events by hour AND day

**Visual**: Color-coded grid
- **Rows**: Hours (0-23)
- **Columns**: Days (Mon-Sun)
- **Color Intensity**: Event count or average magnitude

**Example Insight**:

```
            Mon  Tue  Wed  Thu  Fri  Sat  Sun
Hour 6      🔴   🟠   🟡   🟡   🟠   🟢   🟢
Hour 9      🟠   🟡   🟡   🟡   🟠   🟢   🟢
Hour 18     🔴   🟠   🟠   🟠   🔴   🟡   🟢

Legend:
🔴 >5 events (high risk)
🟠 3-5 events (moderate)
🟡 1-2 events (low)
🟢 0 events (stable)
```

**Business Insight**:
"Monday 6am and Friday 6pm are THE highest risk periods. These require special forecasting attention and potentially increased response reserves."

---

### 5.3.7 Actionable Recommendations from Pattern Analysis

**Recommendation 1: Time-Specific Corrections**
```
Implementation:
  - Apply +250 MW correction to all Hour 6 forecasts
  - Apply +320 MW correction to all Hour 18 forecasts

Expected Benefit:
  - 40% reduction in forecast errors at these hours
  - ~15% reduction in frequency events overall
  - Cost saving: £2-5M/year in reduced balancing actions
```

**Recommendation 2: Day-Type Models**
```
Current: Single forecast model for all days
Proposed: Separate models for:
  - Monday (heavy, uncertain)
  - Tuesday-Thursday (stable weekday)
  - Friday (transition)
  - Weekend (light, predictable)

Expected Benefit:
  - 25% improvement in Monday forecasts
  - Reduce Monday event count from 18 to ~12-14
```

**Recommendation 3: Weather Integration**
```
Observation: July events 3× higher than May
Driver: Unmodeled air conditioning load during heat waves

Implementation:
  - Real-time temperature → demand response curve
  - Update forecast every 4 hours with latest weather

Expected Benefit:
  - 50% reduction in summer forecast surprises
  - Particularly effective for extreme heat days
```

---

**Next**: [Part 6: Power Imbalance Analysis](06_Imbalance_Analysis.md)
