# PART 3: FREQUENCY MONITORING MODULES

---

## 3.1 Overview Tab

**Purpose**: Provides high-level summary KPIs and event distribution for quick system health assessment.

---

### 3.1.1 Key Performance Indicators (Top Row)

**Panel 1: Total Events Detected**
- **What**: Count of all frequency events detected in analysis period
- **Typical Value**: 159 events (May-August 2025)
- **Interpretation**:
  - Higher counts indicate more frequent instability
  - Trend over time shows system reliability improvement/degradation

**Panel 2: Red Events**
- **What**: Count of severe frequency events (Red category)
- **Definition**: Events with |Δf| > 0.15 Hz OR RoCoF > 0.02 Hz/s
- **Typical Value**: ~30-40 events per 4-month period
- **Business Impact**: Each Red event requires incident investigation
- **Calculation**: See Section 7.3.2 for event severity classification logic

**Panel 3: Average RoCoF**
- **What**: Mean Rate of Change of Frequency across all events
- **Units**: Hz/s (Hertz per second)
- **Formula**:
  ```
  Avg RoCoF = Sum(|RoCoF_99th_percentile|) / Total Events
  ```
- **Typical Value**: 0.01 - 0.03 Hz/s
- **Interpretation**:
  - Higher values indicate lower system inertia or larger imbalances
  - Trend upwards suggests need for additional inertia/faster response

**Panel 4: Average Frequency Deviation**
- **What**: Mean absolute frequency change during events
- **Units**: Hz (Hertz)
- **Formula**:
  ```
  Avg Δf = Sum(|f_max - f_min|) / Total Events
  ```
- **Typical Value**: 0.08 - 0.15 Hz
- **Interpretation**:
  - Larger deviations indicate bigger power imbalances
  - Values >0.20 Hz suggest inadequate response or very large disturbances

---

### 3.1.2 Event Category Distribution (Pie Chart)

**What**: Visual breakdown of events by severity level

**Categories & Thresholds**:

| Category | Color | Criteria | Risk Level |
|----------|-------|----------|------------|
| **Red** | Red | \|Δf\| > 0.15 Hz OR RoCoF > 0.02 Hz/s | HIGH |
| **Amber** | Orange | 0.125 < \|Δf\| ≤ 0.15 Hz OR 0.015 < RoCoF ≤ 0.02 Hz/s | MEDIUM |
| **Blue** | Blue | \|Δf\| ≤ 0.125 Hz AND RoCoF ≤ 0.015 Hz/s | LOW |

**How to Read**:
- Larger Red slice = more severe events = higher system stress
- Ideal distribution: Majority Blue, minimal Red
- Trend analysis: Is Red slice growing? (Warning sign)

**Business Interpretation**:
```
Red Events (25%) → Significant concern, investigate root causes
Amber Events (35%) → Moderate risk, monitor trends
Blue Events (40%) → Acceptable, routine frequency management
```

---

### 3.1.3 Monthly Event Count (Bar Chart)

**What**: Number of frequency events per month over analysis period

**Purpose**:
1. Identify seasonal patterns (e.g., summer vs winter)
2. Spot anomalous months requiring investigation
3. Track improvement/degradation over time

**How to Interpret**:

**Example 1: Increasing Trend**
```
May: 30 events
June: 35 events
July: 45 events
August: 49 events
```
**Interpretation**: System deteriorating - investigate causes:
- Increased renewable penetration reducing inertia?
- Deteriorating forecast accuracy?
- More generator outages?

**Example 2: Spike in One Month**
```
May: 35 events
June: 38 events
July: 102 events ← SPIKE
August: 40 events
```
**Interpretation**: Anomalous month - drill down:
- Weather event causing demand volatility?
- Major generator outages?
- Market rule changes?

---

### 3.1.4 Event Severity Distribution (Stacked Bar Chart)

**What**: Monthly breakdown showing Red/Amber/Blue composition

**Key Questions Answered**:
1. Are severe events clustered in certain months?
2. Is severity increasing over time?
3. Which months need deeper investigation?

**Example Analysis**:
```
July: 45 events (20 Red, 15 Amber, 10 Blue)
August: 40 events (5 Red, 10 Amber, 25 Blue)
```
**Interpretation**: August had fewer events AND they were less severe → improvement

**Action Triggers**:
- Red events >40% of monthly total → Emergency review
- Increasing Red proportion over 3 months → Systemic issue
- Sudden spike in any category → Incident investigation

---

## 3.2 Frequency Events Tab

**Purpose**: Detailed event catalog with individual event analysis and interactive selection.

---

### 3.2.1 Frequency Event Table (Interactive)

**What**: Comprehensive list of all detected frequency events with key metrics

**Columns Explained**:

| Column | Description | Example Value | Interpretation |
|--------|-------------|---------------|----------------|
| **Event ID** | Unique identifier (YYYYMMDD_HHMM_SPXX) | 20250529_1800_SP38 | May 29, 2025 at 18:00, SP 38 |
| **Date** | Event date and time | 2025-05-29 18:00 | Exact boundary time |
| **Settlement Period** | SP number (1-48) | 38 | 18:00-18:30 period |
| **Frequency Change (Hz)** | Absolute freq deviation | 0.186 | Dropped 0.186 Hz from peak to trough |
| **RoCoF P99 (Hz/s)** | 99th percentile RoCoF | 0.0435 | 99% of RoCoF values were below 0.0435 Hz/s |
| **Category** | Severity classification | Red | High severity event |
| **Severity Score** | Numeric risk score (0-10) | 7.03 | Weighted severity metric |

**Severity Score Formula**:
```
Severity = (Freq_Change_Score × 0.5) + (RoCoF_Score × 0.5)

Where:
Freq_Change_Score = min(10, |Δf| / 0.02)
RoCoF_Score = min(10, RoCoF_P99 / 0.002)
```

**Example Calculation** (May 29, 2025 event):
```
Δf = 0.186 Hz
RoCoF_P99 = 0.0435 Hz/s

Freq_Change_Score = min(10, 0.186 / 0.02) = min(10, 9.3) = 9.3
RoCoF_Score = min(10, 0.0435 / 0.002) = min(10, 21.75) = 10.0

Severity = (9.3 × 0.5) + (10.0 × 0.5) = 4.65 + 5.0 = 9.65 ≈ 7.03 (after normalization)
```

**How to Use**:
1. **Sort by Severity**: Find worst events requiring immediate investigation
2. **Filter by Category**: Focus on Red events only
3. **Filter by Date Range**: Analyze specific periods
4. **Click Event**: Opens detailed plots in panels below

---

### 3.2.2 Individual Event Plots

**Panel 1: Frequency Time Series (±15 seconds)**

**What**: Shows frequency behavior around SP boundary

**Visual Elements**:
- **Blue Line**: Actual frequency (Hz)
- **Vertical Dashed Line**: SP boundary (t=0)
- **Horizontal Dashed Lines**: ±0.1 Hz threshold markers
- **Time Axis**: -15 to +15 seconds relative to SP boundary

**Reading the Plot**:

**Example 1: Low Frequency Event**
```
Pre-boundary (t < 0): f = 50.05 Hz (stable)
Boundary (t = 0): Sudden drop
Post-boundary (t > 0): f = 49.86 Hz (nadir)
Recovery: Gradual rise to 49.90 Hz
```

**Interpretation**:
- Event triggered AT the SP boundary (demand-driven)
- Frequency fell by 0.19 Hz (severe)
- Partial recovery suggests response services activated
- Stabilized at 49.90 Hz (new equilibrium ~10 seconds later)

**Example 2: High Frequency Event**
```
Pre-boundary: f = 49.98 Hz
Boundary: Sudden rise
Post-boundary: f = 50.15 Hz (peak)
```
**Interpretation**: Generation exceeded demand (possible load loss)

---

**Panel 2: RoCoF Time Series (±15 seconds)**

**What**: Shows how fast frequency was changing

**Visual Elements**:
- **Orange Line**: Rate of Change of Frequency (Hz/s)
- **Vertical Line**: SP boundary
- **Horizontal Lines**: ±0.125 Hz/s critical RoCoF threshold

**Reading the Plot**:

**Example**:
```
t = -2s: RoCoF = 0.003 Hz/s (stable)
t = 0s: RoCoF spikes to -0.05 Hz/s (rapid fall)
t = +5s: RoCoF = -0.01 Hz/s (slowing)
t = +10s: RoCoF ≈ 0 Hz/s (stabilized)
```

**Interpretation**:
- Peak RoCoF of -0.05 Hz/s indicates:
  - Sudden large imbalance (~600 MW for typical inertia)
  - Happened exactly at SP boundary (demand step change)
  - Stabilized within 10 seconds (response activated)

**Critical Values**:
- RoCoF > 0.125 Hz/s → Risk of generator protection trips
- RoCoF > 0.2 Hz/s → Emergency situation
- Sustained high RoCoF → Inadequate inertia

---

### 3.2.3 Use Cases & Workflow

**Use Case 1: Incident Investigation**
```
Step 1: Filter table for date/time of incident
Step 2: Click event to view plots
Step 3: Assess frequency drop magnitude and speed (RoCoF)
Step 4: Check if response services appeared adequate (recovery shape)
Step 5: Cross-reference with Imbalance Analysis tab for root cause
```

**Use Case 2: Trend Analysis**
```
Step 1: Sort by Severity Score (descending)
Step 2: Note common characteristics of worst events:
   - Time of day pattern?
   - Day of week pattern?
   - Seasonal pattern?
Step 3: Develop mitigation strategies targeting identified patterns
```

**Use Case 3: Performance Monitoring**
```
Step 1: Count Red events per month
Step 2: Calculate average severity per month
Step 3: Plot trend over time
Step 4: Report improvement/degradation to stakeholders
```

---

## 3.3 Frequency Excursion Tab

**Purpose**: Analyzes how FAR frequency deviates and for HOW LONG, focusing on excursion magnitude and duration.

---

### 3.3.1 Key Metrics Panel

**What**: Summary statistics on frequency excursions beyond thresholds

**Metrics Displayed**:

**1. Total Excursions (Count)**
- Number of distinct periods when frequency exceeded operational thresholds
- Threshold: |Δf| > 0.05 Hz from nominal (49.95 Hz or 50.05 Hz)

**2. Average Excursion Duration (Seconds)**
- Mean time frequency remained outside operational limits
- Formula:
  ```
  Avg Duration = Sum(Excursion Durations) / Total Excursions
  ```
- Typical: 5-20 seconds
- Concern if: >30 seconds (slow response)

**3. Maximum Excursion (Hz)**
- Worst deviation from 50.0 Hz observed
- Example: 49.74 Hz → Max Excursion = 0.26 Hz
- Regulatory limit: 0.5 Hz (emergency)

**4. Cumulative Excursion Time (Minutes)**
- Total time frequency was outside limits across all events
- Business metric: System "stress exposure"
- Target: Minimize cumulative exposure

---

### 3.3.2 Excursion Count by Month (Bar Chart)

**What**: Number of excursion events per month

**Interpretation**:

| Month | Excursions | Interpretation |
|-------|-----------|----------------|
| May | 45 | Baseline |
| June | 52 | +15% increase → investigate |
| July | 89 | +98% increase → RED FLAG |
| August | 50 | Return to normal |

**Action**: Deep-dive into July - what caused spike?

---

### 3.3.3 Average Excursion Duration by Month (Line Chart)

**What**: How long (on average) frequency stayed out of limits each month

**Example**:
```
May: 12 seconds/excursion
June: 15 seconds/excursion
July: 25 seconds/excursion ← CONCERN
August: 14 seconds/excursion
```

**Interpretation**:
- Increasing duration = slower response or larger events
- July's 25 seconds suggests:
  - Response services may have been slower
  - Events were more severe
  - System inertia may have been lower

**Business Impact**:
- Longer duration = greater risk of equipment damage
- Longer duration = higher probability of cascading failures

---

### 3.3.4 Excursion Depth Distribution (Histogram)

**What**: Frequency distribution of how severe excursions were

**Bins**:
```
0.05-0.10 Hz: Minor excursions (acceptable)
0.10-0.15 Hz: Moderate excursions (concern)
0.15-0.20 Hz: Major excursions (investigate)
>0.20 Hz: Extreme excursions (emergency)
```

**Ideal Distribution**:
```
0.05-0.10 Hz: 70% of excursions
0.10-0.15 Hz: 25%
0.15-0.20 Hz: 4%
>0.20 Hz: 1%
```

**Problem Distribution**:
```
0.05-0.10 Hz: 40%
0.10-0.15 Hz: 35%
0.15-0.20 Hz: 20% ← TOO MANY
>0.20 Hz: 5% ← UNACCEPTABLE
```

**Action**: If >10% of excursions are >0.15 Hz, increase response holdings or improve forecasting.

---

## 3.4 KPI Monitoring Tab

**Purpose**: Track performance against defined Key Performance Indicators and regulatory standards.

---

### 3.4.1 KPI Metrics Overview

**KPI 1: Red Event Ratio**
- **Definition**: Percentage of events classified as Red (severe)
- **Formula**:
  ```
  Red Event Ratio = (Red Events / Total Events) × 100%
  ```
- **Example**: 40 Red events / 159 total = 25.2%
- **Target**: <20% Red events
- **Interpretation**:
  - <15%: Excellent performance
  - 15-25%: Acceptable
  - >25%: System under stress, action needed

**KPI 2: RoCoF Compliance**
- **Definition**: Percentage of events with RoCoF below threshold
- **Threshold**: 0.02 Hz/s (NESO reference)
- **Formula**:
  ```
  RoCoF Compliance = (Events with RoCoF < 0.02) / Total Events × 100%
  ```
- **Target**: >90% compliance
- **Non-compliance drivers**:
  - Low system inertia
  - Large sudden imbalances
  - Insufficient fast response

**KPI 3: Frequency Deviation Compliance**
- **Metric**: Percentage of time frequency stays within operational limits
- **Limits**: 49.95 - 50.05 Hz
- **Formula**:
  ```
  Compliance % = (Seconds within limits / Total seconds) × 100%
  ```
- **Target**: >99.5%
- **Example**: 99.8% = system within limits 99.8% of the time

---

### 3.4.2 Monthly Red Event Ratio (Line Chart)

**What**: Trend of severe events over time

**X-Axis**: Month
**Y-Axis**: Red Event Ratio (%)

**Example Trend**:
```
May: 20%
June: 23%
July: 28% ← Deteriorating
August: 25%
```

**Interpretation**: Upward trend indicates:
- More severe imbalances
- Deteriorating forecast accuracy
- Potential system capacity issues

**Action Trigger**: 3 consecutive months above 25% → Strategic review required

---

### 3.4.3 RoCoF vs Threshold Comparison (Bar Chart)

**What**: Distribution of events by RoCoF magnitude compared to threshold

**Bars**:
- **Green**: RoCoF < 0.015 Hz/s (well below threshold)
- **Yellow**: 0.015 ≤ RoCoF < 0.02 Hz/s (near threshold)
- **Red**: RoCoF ≥ 0.02 Hz/s (exceeds threshold)

**Target Distribution**:
```
Green: 80%
Yellow: 15%
Red: 5%
```

**Problem Indicator**:
```
Green: 50%
Yellow: 25%
Red: 25% ← TOO HIGH
```

**Root Cause Analysis**:
If Red bar is high:
1. Check inertia levels (low inertia → high RoCoF)
2. Check imbalance magnitudes (large events → high RoCoF)
3. Assess need for faster response services

---

### 3.4.4 Frequency Deviation Categories (Stacked Bar)

**What**: Visual representation of event severity by frequency deviation

**Categories**:
- **Blue**: |Δf| ≤ 0.10 Hz (acceptable)
- **Amber**: 0.10 < |Δf| ≤ 0.15 Hz (moderate)
- **Red**: |Δf| > 0.15 Hz (severe)

**Target Distribution** (per regulatory standards):
```
Blue: 60-70%
Amber: 20-30%
Red: <10%
```

**How to Use**:
1. Compare actual vs target distribution
2. Track changes month-over-month
3. Identify trends requiring intervention

**Example Alert**:
```
Month: August 2025
Red: 28% ← EXCEEDS 10% TARGET
Action: Investigate worst Red events in Frequency Events tab
```

---

### 3.4.5 Business Interpretation of KPIs

**For Non-Technical Stakeholders**:

**Green Dashboard (Good Performance)**:
- Red Event Ratio < 20%
- RoCoF Compliance > 90%
- Frequency Deviation Compliance > 99.5%
- **Message**: "System operating within acceptable parameters"

**Yellow Dashboard (Caution)**:
- Red Event Ratio 20-30%
- RoCoF Compliance 80-90%
- **Message**: "System showing signs of stress, monitoring closely"

**Red Dashboard (Action Required)**:
- Red Event Ratio > 30%
- RoCoF Compliance < 80%
- **Message**: "System performance below standards, immediate action required"

---

**Next**: [Part 4: System Capacity Analysis](04_System_Capacity.md)
