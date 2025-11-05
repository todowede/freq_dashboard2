# PART 6: POWER IMBALANCE ANALYSIS

---

## 6.1 Imbalance Analysis Tab - Overview

**Purpose**: Reverse-engineer the actual power imbalance (MW) that caused frequency deviations by working backwards from frequency effects to root causes.

---

### 6.1.1 The Detective Problem

**What We Observe**: Frequency drop from 50.046 Hz to 49.86 Hz over 10 seconds

**What We Need To Find**: How many MW of generation was lost (or demand gained)?

**The Challenge**: Frequency is the SYMPTOM, not the cause. Multiple factors affect frequency:
1. **Original Imbalance** (what we want to find)
2. **Frequency Response Services** (automatic generation increases)
3. **Demand Damping** (natural load reduction)
4. **Inertial Response** (energy from rotating generators)

**The Solution**: Work backwards - subtract all the helpful responses to reveal the original problem.

---

### 6.1.2 The Imbalance Equation

**Core Formula**:
```
Imbalance = -LF_Response - HF_Response - Demand_Damping + RoCoF_Component
```

**Why the negative signs?**

Think of it like detective work:

```
Crime Scene (Frequency Drop):
  - Frequency fell by 0.15 Hz
  - This is the EVIDENCE

Witnesses (Helpful Responses):
  - LF Response added 650 MW of generation
  - Demand Damping reduced load by 130 MW
  - Total help: 780 MW

Question: How big was the original crime (imbalance)?
Answer: Must have been BIGGER than what we see, because help was provided

Original Imbalance = Visible Effect + Help Provided
                   = (What we see) - (-LF Response) - (-Damping)
                   = -LF_Response - Damping  (using negative convention)
```

**Sign Convention**:
- **Negative Imbalance**: Generation shortage (or excess demand)
- **Positive Imbalance**: Generation excess (or demand shortfall)

---

### 6.1.3 The 7 Panels Explained

The Imbalance Analysis tab has **7 interconnected panels**:

**Panel 1: Event Selector (Dropdown)**
- Select which frequency event to analyze
- Events sorted by severity (worst first)

**Panel 2: Event List (Table)**
- All detected events with severity metrics
- Click to select event for detailed analysis

**Panel 3: Event Details (Info Box)**
- Date, Time, Settlement Period
- Boundary timestamp
- Frequency range (min-max)
- Frequency change (Δf)
- Peak RoCoF
- Event category (Red/Amber/Blue)
- Severity score

**Panel 4: Imbalance Summary (Info Box)**
- Pre-fault imbalance (baseline before event)
- Peak imbalance (worst moment)
- Mean imbalance (average during event)
- Component breakdown:
  - LF Response contribution
  - HF Response contribution
  - Demand Damping contribution
  - RoCoF Component contribution
- System values used (Inertia, Demand)

**Panel 5: Frequency Event Plot (Time Series)**
- Blue line: Frequency (Hz)
- Orange line: RoCoF (Hz/s)
- Vertical line: SP boundary (t=0)
- X-axis: ±15 seconds around boundary

**Panel 6: Power Imbalance Time Series (Line Chart)**
- Red line: Calculated imbalance (MW)
- Shows second-by-second imbalance
- X-axis: ±15 seconds around boundary

**Panel 7: All Events Imbalance Summary (Table)**
- Summary statistics for all analyzed events
- Sortable, filterable dataset

---

## 6.2 Event Detection Methodology

### 6.2.1 What Events Are Captured

**Scope**: Events occurring within **±60 seconds** of Settlement Period boundaries

**Why This Scope?**
1. **SP boundaries are high-risk moments** (market-driven demand changes)
2. **Focus on preventable events** (forecasting improvements can help)
3. **Computational efficiency** (don't analyze every second of 4 months)

**What This Means**:

**Events CAPTURED**:
```
SP Boundary at 12:30:00

Event occurs at 12:29:55 (5 seconds before) ✓ CAPTURED
Event occurs at 12:30:15 (15 seconds after) ✓ CAPTURED
```

**Events MISSED**:
```
Event occurs at 12:25:00 (5 minutes before) ✗ NOT CAPTURED
Event occurs at 12:45:00 (midway through SP) ✗ NOT CAPTURED
```

**Important**: Missing mid-SP events is BY DESIGN. Those are typically random generator trips (unpredictable). We focus on SP-related events (potentially preventable).

---

### 6.2.2 Event Detection Criteria

For each SP boundary, the system extracts ±60 seconds of frequency data and checks:

**Criterion 1: Frequency Deviation**
```
Δf = |f_max - f_min| in 60-second window

If Δf > 0.10 Hz → Event detected
```

**Criterion 2: RoCoF Exceedance**
```
RoCoF_p99 = 99th percentile of |RoCoF| in window

If RoCoF_p99 > 0.01 Hz/s → Event detected
```

**Detection Outcome**:
- If **either** criterion met → Event logged
- Event categorized by severity (Section 6.2.3)
- Event selected for imbalance calculation if meets severity threshold

---

### 6.2.3 Event Severity Classification

Events are classified into 3 categories based on magnitude:

**Red Events** (Severe):
```
|Δf| > 0.15 Hz  OR  RoCoF_p99 > 0.02 Hz/s

Example: Δf = 0.19 Hz, RoCoF = 0.043 Hz/s
→ RED (both thresholds exceeded)

Business Impact:
- Requires incident report
- Investigate root cause
- Potential Grid Code compliance issue
```

**Amber Events** (Moderate):
```
0.125 Hz < |Δf| ≤ 0.15 Hz  OR  0.015 Hz/s < RoCoF_p99 ≤ 0.02 Hz/s

Example: Δf = 0.14 Hz, RoCoF = 0.018 Hz/s
→ AMBER (both in moderate range)

Business Impact:
- Monitor for trends
- Review if frequency increases
- Acceptable but not ideal
```

**Blue Events** (Minor):
```
|Δf| ≤ 0.125 Hz  AND  RoCoF_p99 ≤ 0.015 Hz/s

Example: Δf = 0.08 Hz, RoCoF = 0.012 Hz/s
→ BLUE (both below thresholds)

Business Impact:
- Normal system operation
- No action required
- Track for statistics
```

---

## 6.3 Component Breakdown & Calculations

### 6.3.1 The Four Components Explained

**COMPONENT 1: Low Frequency (LF) Response**

**What**: Automatic generation increase when frequency drops below 49.985 Hz (deadband)

**Who Provides**: Thermal generators (coal, gas, nuclear), hydro, some batteries

**How It Activates**:
```
Droop Control:
  If f < 49.985 Hz (below deadband):
    Additional Power = |Δf| / 0.5 Hz × Total_LF_Holdings

  Example:
    f = 49.85 Hz → Δf = -0.15 Hz
    LF Holdings = 2,000 MW
    LF Response = 0.15 / 0.5 × 2,000 = 600 MW
```

**Calculation Formula**:
```
LF_Response = fifelse(
  df_hz < -0.015,  # Below deadband
  abs(df_hz) * (Primary + Secondary + DR + DM + DC) / 0.5,
  0
)
```

**Real Example** (May 29, 2025, 18:00):
```
Δf = -0.13 Hz
Holdings: Primary=500, Secondary=300, DR=300, DM=400, DC=500 = 2,000 MW total
LF_Response = 0.13 / 0.5 × 2,000 = 520 MW

Interpretation: Response services added 520 MW of generation
```

---

**COMPONENT 2: High Frequency (HF) Response**

**What**: Automatic generation reduction when frequency rises above 50.015 Hz

**Who Provides**: Fast-acting generators, demand-side response, batteries

**How It Activates**:
```
If f > 50.015 Hz (above deadband):
  Power Reduction = Δf / 0.2 Hz × Total_HF_Holdings

Example:
  f = 50.12 Hz → Δf = +0.12 Hz
  HF Holdings = 200 MW
  HF Response = 0.12 / 0.2 × 200 = 120 MW reduced
```

**Calculation Formula**:
```
HF_Response = fifelse(
  df_hz > 0.015,  # Above deadband
  df_hz * High_Holdings / 0.2,
  0
)
```

**Note**: In low-frequency events, HF_Response = 0 (not activated).

---

**COMPONENT 3: Demand Damping**

**What**: Natural reduction in electrical demand when frequency (and voltage) falls

**Physical Basis**:
- Motors slow down → consume less power
- Resistive loads (heaters) see lower voltage → less power
- Approximately **2.5% demand change per 1 Hz frequency change**

**Formula**:
```
Demand_Damping = Base_Demand × 0.025 × Δf

Where:
  Base_Demand = System demand at event time (MW)
  0.025 = 2.5% per Hz (NESO standard)
  Δf = Frequency deviation from 50 Hz
```

**Real Example**:
```
Base Demand = 35,000 MW
f = 49.87 Hz → Δf = -0.13 Hz

Demand_Damping = 35,000 × 0.025 × (-0.13)
               = -113.75 MW

Interpretation: Demand automatically reduced by 114 MW
This is HELPFUL (acts like additional generation)
```

**Sign Convention**:
- Negative damping = Demand decreased (helps during low frequency)
- Positive damping = Demand increased (worsens high frequency)

---

**COMPONENT 4: RoCoF Component**

**What**: Energy released from (or absorbed by) rotating generators' inertia

**Physical Basis**: When frequency changes, the kinetic energy stored in rotating generator shafts increases or decreases.

**Formula**:
```
RoCoF_Component = 2 × Inertia × System_Frequency × RoCoF

Simplified:
RoCoF_Component = 2 × H × 50 × (df/dt)

Where:
  H = System inertia (GVA·s)
  50 = Nominal frequency (Hz)
  df/dt = RoCoF (Hz/s)
```

**Real Example**:
```
Inertia = 150 GVA·s
RoCoF = -0.05 Hz/s (frequency falling rapidly)

RoCoF_Component = 2 × 150 × 50 × (-0.05)
                = -750 MW

Interpretation: Generators slowing down, releasing 750 MW from stored energy
```

**Important Understanding**:
- RoCoF Component is TRANSIENT (only during frequency change)
- Once frequency stabilizes (RoCoF → 0), this component disappears
- Represents energy buffer, not sustained generation

---

### 6.3.2 Putting It All Together: The Complete Calculation

**Step-by-Step Example** (May 29, 2025, 18:00 Event)

**STEP 1: Gather Inputs**
```
From Frequency Data:
  f(t=-1s) = 50.046 Hz
  f(t=0s) = 50.003 Hz
  f(t=5s) = 49.86 Hz (nadir)
  Δf = 49.86 - 50.046 = -0.186 Hz
  RoCoF(peak) = -0.05 Hz/s

From System Data:
  Inertia = 142 GVA·s
  Base Demand = 21,783 MW (actual value from that SP)

From Response Holdings:
  Total LF = 2,000 MW
  Total HF = 200 MW
```

**STEP 2: Calculate Each Component** (at peak, t=5s)

```
LF Response:
  Δf = -0.186 Hz (well below -0.015 deadband)
  LF = 0.186 / 0.5 × 2,000 = 744 MW activated

HF Response:
  Δf < 0 → HF = 0 (not activated)

Demand Damping:
  Damping = 21,783 × 0.025 × (-0.186)
          = -101.3 MW

RoCoF Component (at peak RoCoF):
  RoCoF = -0.05 Hz/s
  RoCoF_Component = 2 × 142 × 50 × (-0.05)
                  = -710 MW
```

**STEP 3: Calculate Imbalance**

```
Imbalance = -LF_Response - HF_Response - Demand_Damping + RoCoF_Component
          = -744 - 0 - (-101.3) + (-710)
          = -744 + 101.3 - 710
          = -1,352.7 MW

But wait - let's use the STABILIZED value (after 10 seconds)
```

**STEP 4: Stabilized Calculation** (t=15s, after responses stabilized)

```
At t=15s:
  f = 49.90 Hz → Δf = -0.10 Hz
  RoCoF ≈ 0 Hz/s (stabilized)

LF Response:
  LF = 0.10 / 0.5 × 2,000 = 400 MW

Demand Damping:
  Damping = 21,783 × 0.025 × (-0.10) = -54.5 MW

RoCoF Component:
  RoCoF ≈ 0 → Component ≈ 0 MW

Stabilized Imbalance:
  = -400 - 0 - (-54.5) + 0
  = -400 + 54.5
  = -345.5 MW
```

**INTERPRETATION**:

```
Peak Imbalance (t=5s): -1,353 MW
  → Worst moment, includes transient inertial effects
  → Generation fell short by 1,353 MW instantaneously

Stabilized Imbalance (t=15s): -346 MW
  → Sustained shortfall after responses activated
  → System reached new equilibrium with 346 MW deficit
  → This is the "true" underlying imbalance
```

**Physical Story**:
```
What Happened:
1. At 18:00 SP boundary, demand suddenly increased by ~600 MW
   (likely forecast error + scheduled load ramp)
2. Generators couldn't instantly respond
3. Frequency began falling rapidly (RoCoF = -0.05 Hz/s)
4. Within 10 seconds:
   - LF Response ramped up to 400 MW
   - Demand naturally reduced by 54 MW (damping)
   - Generators released energy from inertia (transient support)
5. After 15 seconds:
   - System stabilized at new equilibrium
   - Frequency at 49.90 Hz (0.10 Hz below nominal)
   - Net imbalance: 346 MW (sustained)
```

---

## 6.4 Interpretation & Real-World Examples

### 6.4.1 Reading Panel 5: Frequency Event Plot

**Example Plot** (May 29, 2025, 18:00):

**BEFORE Boundary (t < 0)**:
```
Frequency: 50.04-50.05 Hz (stable)
RoCoF: ~0.003 Hz/s (minor fluctuations)

Interpretation: System in equilibrium, normal operation
```

**AT Boundary (t = 0)**:
```
Frequency: Begins sharp drop
RoCoF: Spikes to -0.05 Hz/s (negative, rapid fall)

Interpretation: Sudden imbalance triggered AT SP boundary
→ Strong evidence of demand-driven event
```

**DURING Event (0 < t < 10s)**:
```
Frequency: Falls from 50.046 Hz to 49.86 Hz (nadir at t=5s)
RoCoF: Remains high (-0.03 to -0.05 Hz/s)

Interpretation:
  - Imbalance large enough to overwhelm initial response
  - Frequency falling rapidly
  - RoCoF indicates ~600-800 MW instantaneous imbalance
```

**RECOVERY (t > 10s)**:
```
Frequency: Rises slightly to 49.90 Hz, stabilizes
RoCoF: Decays to ~-0.01 Hz/s, then 0

Interpretation:
  - Response services activated and helping
  - Frequency stopped falling (RoCoF → 0)
  - New equilibrium at 49.90 Hz
  - Sustained imbalance ~350 MW
```

---

### 6.4.2 Reading Panel 6: Power Imbalance Time Series

**Example Plot** (same event):

**BEFORE (t < 0)**:
```
Imbalance: -50 to -100 MW (minor pre-fault imbalance)

Interpretation: Small background imbalance already present
(Demand slightly high or generation slightly low before event)
```

**PEAK (t = 5s)**:
```
Imbalance: -1,350 MW (deep trough)

Interpretation: Maximum imbalance at worst frequency moment
Includes transient inertial effects
```

**RECOVERY (5s < t < 15s)**:
```
Imbalance: Rises from -1,350 MW to -350 MW

Interpretation:
  - Response services reducing imbalance
  - Inertial support ending (RoCoF → 0)
  - Converging toward sustained imbalance level
```

**STABILIZED (t > 15s)**:
```
Imbalance: Oscillates around -350 MW

Interpretation:
  - System reached new equilibrium
  - Frequency responses activated fully
  - Remaining 350 MW deficit is:
    * Original imbalance minus
    * LF Response (400 MW) minus
    * Demand Damping (54 MW)
```

---

### 6.4.3 Real Example Walkthrough

**Event**: May 29, 2025, 18:00, SP 38

**Panel 3 (Event Details) Shows**:
```
Date & SP: 2025-05-29 18:00 / SP 38
Boundary Time: 18:00:00
Frequency Range: 49.86 - 50.046 Hz
Frequency Change: 0.186 Hz
ROCOF (max): 0.0435 Hz/s
Event Category: Red
Severity Score: 7.03
```

**Panel 4 (Imbalance Summary) Shows**:
```
Imbalance Statistics:
  Pre-fault Imbalance: -89.2 MW
  Peak Imbalance: -1,352.7 MW
  Mean Imbalance: -645.3 MW

Component Breakdown (Stabilized):
  LF Response: 400.0 MW
  HF Response: 0.0 MW
  Demand Damping: -54.5 MW
  RoCoF Component: 0.0 MW

System values used:
  Inertia: 142.0 GVA·s
  Demand: 21,783 MW
```

**Analysis & Business Interpretation**:

**1. Event Timing**:
- Occurred exactly at SP 38 boundary (18:00)
- Evening peak period (high demand, high risk)
- **Conclusion**: Demand-driven event, likely forecasting error

**2. Severity Assessment**:
- Frequency fell 0.186 Hz (severe, >0.15 Hz threshold)
- RoCoF peaked at 0.0435 Hz/s (>2× the 0.02 threshold)
- Category: Red (requires investigation)
- **Conclusion**: Major event, top priority

**3. Imbalance Magnitude**:
- Peak: 1,353 MW shortfall (very large)
- Stabilized: ~350 MW sustained deficit
- **Comparison**: Typical large generator = 500-800 MW
  → This event equivalent to losing a major power station
- **Conclusion**: Either massive forecast error OR generator trip

**4. Response Performance**:
- LF Response: 400 MW activated (20% of available 2,000 MW)
- Response adequate to stabilize (frequency stopped falling)
- Demand damping contributed 54 MW (minor but helpful)
- **Conclusion**: Response services performed as expected

**5. Root Cause**:
Cross-reference with Demand Analysis tab for SP 38:
```
Demand at SP 37 (17:30): 20,536 MW
Demand at SP 38 (18:00): 21,783 MW
Change: +1,247 MW

Expected change (hourly mean): ~+900 MW
Unforeseen Demand: +347 MW
```

**Conclusion**:
- Demand increased by 1,247 MW (larger than typical +900 MW)
- Forecast error: ~350 MW
- This matches the stabilized imbalance perfectly!
- **Root Cause**: Demand forecast was 350 MW too low

**6. Business Impact**:
```
Costs:
  - Balancing Mechanism activation: ~£100-200k
  - Potential Grid Code breach investigation: Staff time
  - Reputational impact: Stakeholder confidence

Prevention:
  - Improve 18:00 hour demand forecast (see Section 5.3)
  - Consider additional evening peak response holdings
  - Implement real-time demand monitoring with 15-min update cycle
```

---

### 6.4.4 Comparing Event Types

**Event Type A: Large Demand-Driven** (like May 29)
```
Characteristics:
  - Occurs AT SP boundary (±1 second)
  - Imbalance magnitude matches unforeseen demand
  - Frequency drop proportional to forecast error
  - RoCoF high initially, stabilizes

Preventability: HIGH (improve forecasts)
```

**Event Type B: Generator Trip** (random)
```
Characteristics:
  - Occurs at random time (not SP boundary)
  - Imbalance = generator size (e.g., 500 MW)
  - Very high initial RoCoF (sudden loss)
  - Fast recovery if response adequate

Preventability: LOW (equipment failure, unpredictable)
```

**Event Type C: Combined** (worst case)
```
Characteristics:
  - Demand forecast error coincides with generator trip
  - Cumulative imbalance >1,000 MW
  - Extreme frequency deviation (>0.2 Hz)
  - May exhaust response reserves

Preventability: PARTIAL (better forecasts reduce demand component)
```

---

### 6.4.5 Decision Support Use Cases

**Use Case 1: Incident Investigation**
```
Question: "What caused the 18:00 Red event on May 29?"

Steps:
1. Open Imbalance Analysis → Select event
2. Panel 3: Confirm timing (exactly at SP boundary)
3. Panel 4: Note stabilized imbalance (346 MW)
4. Panel 6: Verify imbalance pattern (sharp drop at t=0)
5. Cross-check Unforeseen Demand tab:
   → Unforeseen Demand = +347 MW ✓ MATCH

Conclusion: Demand forecast error of 347 MW caused event
Action: Investigate why forecast failed, improve model
```

**Use Case 2: Response Adequacy Assessment**
```
Question: "Do we have enough LF Response contracted?"

Analysis:
1. Review worst 10 Red events
2. Extract peak imbalances: Range 800-1,350 MW
3. Current LF Holdings: 2,000 MW
4. Utilization: 1,350 / 2,000 = 67.5% (peak event)

Safety Factor: 2,000 / 1,350 = 1.48×

Interpretation:
  - Adequate for known events (>1× coverage)
  - But safety margin thin (<2×)
  - Recommendation: Increase to 2,400 MW for 1.78× margin
```

**Use Case 3: Forecasting Performance Tracking**
```
Question: "Are our forecasts improving?"

Method:
1. Compare stabilized imbalances to unforeseen demand
2. Calculate correlation (should be ~1.0)
3. Track average magnitude over time

Example Results:
  May: Avg |Imbalance| = 425 MW
  June: Avg |Imbalance| = 390 MW (-8%)
  July: Avg |Imbalance| = 475 MW (+12% worse)
  August: Avg |Imbalance| = 350 MW (-18% improvement)

Conclusion: July was problematic (investigate), but overall improving trend
```

---

**Next**: [Part 7: Technical Implementation & Formulas](07_Technical_Implementation.md)
