# PART 4: SYSTEM CAPACITY ANALYSIS

---

## 4.1 Response Holdings Tab

**Purpose**: Monitor availability and utilization of frequency response services - the system's automatic defense against frequency deviations.

---

### 4.1.1 What Are Response Holdings?

**Definition**: Response Holdings are contracted services that automatically activate to stabilize frequency when it deviates from 50 Hz.

**The Business Model**:
```
NESO → Contracts with providers → Pay for availability (£/MW/hour)
When frequency deviates → Service activates automatically → Stabilizes system
```

**Why This Matters**:
- Inadequate holdings → Frequency instability → Risk of blackouts
- Excess holdings → Unnecessary costs (millions of £/year)
- **Goal**: Optimize holdings to balance cost and reliability

---

### 4.1.2 Types of Frequency Response Services

The system uses **6 main service types**, each with different activation speeds and purposes:

---

**SERVICE 1: Primary Response**
- **Activation Time**: 10 seconds
- **Duration**: Up to 30 minutes
- **Mechanism**: Governor droop response on generators
- **Typical Holding**: 500 MW
- **Use Case**: First line of defense for frequency drops
- **How It Works**:
  ```
  When f < 49.85 Hz (below deadband)
  → Generators automatically increase output proportionally
  → Formula: Additional Power = (50 - f) / 0.5 × Primary_MW
  ```

**Example**:
```
Frequency drops to 49.75 Hz
Primary Holdings: 500 MW
Activation = (50 - 49.75) / 0.5 × 500 = 0.25 / 0.5 × 500 = 250 MW
```
250 MW of additional generation activates automatically.

---

**SERVICE 2: Secondary Response**
- **Activation Time**: 30 seconds
- **Duration**: Up to 30 minutes
- **Typical Holding**: 300 MW
- **Purpose**: Sustained support after primary response
- **Providers**: Large thermal generators, pumped storage

---

**SERVICE 3: High Frequency Response (HF)**
- **Activation Time**: When f > 50.015 Hz
- **Purpose**: Reduce generation when frequency too high
- **Typical Holding**: 200 MW
- **Mechanism**: Fast reduction of output or increase in demand

---

**SERVICE 4: Dynamic Regulation (DR)**
- **Activation Time**: Continuous (0-1 second)
- **Typical Holding**: 300 MW
- **Technology**: Batteries, flywheels
- **Purpose**: Smooth frequency variations, prevent small deviations
- **Advantage**: Very fast, both-way support

---

**SERVICE 5: Dynamic Moderation (DM)**
- **Activation Time**: 1 second
- **Typical Holding**: 400 MW
- **Technology**: Batteries
- **Purpose**: Fast response to contain frequency deviations
- **Key Feature**: Symmetric (works for high AND low frequency)

---

**SERVICE 6: Dynamic Containment (DC)**
- **Activation Time**: <1 second
- **Typical Holding**: 500 MW
- **Technology**: Advanced batteries, fast-acting storage
- **Purpose**: Prevent RoCoF from exceeding limits
- **Critical Role**: Protects against high RoCoF in low inertia conditions

---

### 4.1.3 Response Holdings Summary Panel

**What**: Overview of current frequency response capacity

**Metrics Displayed**:

| Metric | Example Value | Business Meaning |
|--------|---------------|------------------|
| **Total Low Freq Response** | 2,000 MW | Maximum automatic generation increase available |
| **Total High Freq Response** | 200 MW | Maximum automatic generation decrease available |
| **Fast Response (DR+DM+DC)** | 1,200 MW | Ultra-fast response for high RoCoF events |
| **Traditional Response** | 800 MW | Slower but sustained response from generators |

**Adequacy Assessment**:
```
Total Response = 2,000 MW
Typical Largest Imbalance = 600 MW
Coverage Ratio = 2,000 / 600 = 3.3×

Interpretation: System can handle 3× the typical worst-case event ✓
```

**Concern Threshold**:
```
If Coverage Ratio < 2.0 → Insufficient reserves
→ Risk of frequency falling beyond recovery point
→ Immediate procurement action required
```

---

### 4.1.4 Response Holdings by Service Type (Bar Chart)

**What**: Visual comparison of holdings across service types

**X-Axis**: Service Type (Primary, Secondary, High, DR, DM, DC)
**Y-Axis**: Holdings (MW)

**How to Read**:

**Balanced Portfolio** (Ideal):
```
Primary: ████████ 500 MW
Secondary: █████ 300 MW
High: ███ 200 MW
DR: █████ 300 MW
DM: ██████ 400 MW
DC: ████████ 500 MW

Interpretation: Good mix of fast and sustained response
```

**Imbalanced Portfolio** (Risk):
```
Primary: ███████████ 800 MW ← Overreliance on slow response
Secondary: █████ 400 MW
High: ██ 100 MW
DR: ██ 100 MW ← Insufficient fast response
DM: ██ 150 MW
DC: ██ 150 MW

Interpretation: Vulnerable to high RoCoF events (low fast response)
```

**Business Question**: "Are we paying for the right mix of services?"

---

### 4.1.5 Response Holdings Trend (Line Chart)

**What**: How holdings changed over analysis period

**Purpose**:
1. Track procurement strategy evolution
2. Assess correlation between holdings and event frequency
3. Identify optimization opportunities

**Example Analysis**:

```
Month    | Total Holdings | Red Events | Analysis
---------|----------------|------------|----------
May      | 1,800 MW      | 12         | Baseline
June     | 2,000 MW      | 10         | ↑ Holdings → ↓ Events ✓
July     | 2,200 MW      | 15         | ↑ Holdings but ↑ Events (other factors)
August   | 2,100 MW      | 8          | Optimized
```

**Insight**: June-August shows procurement adjustments responding to May events.

---

### 4.1.6 Response Activation Analysis

**What**: Estimates how much response was actually utilized during events

**Calculation** (for each event):
```
Required Response = |Peak Imbalance| - Natural Damping

Example:
Peak Imbalance: -600 MW (generation shortage)
Natural Damping: +130 MW (demand reduced automatically)
Required Response = 600 - 130 = 470 MW

Available Response: 2,000 MW
Utilization: 470 / 2,000 = 23.5%
```

**Interpretation Table**:

| Utilization | Meaning | Action |
|-------------|---------|--------|
| <25% | Holdings significantly exceed typical needs | Consider reducing to cut costs |
| 25-50% | Good buffer | Maintain current levels |
| 50-75% | Adequate but tight | Monitor closely |
| >75% | Insufficient margin | Increase holdings immediately |
| >100% | Holdings fully depleted | CRITICAL - emergency procurement |

---

### 4.1.7 Business Cases & Decision Support

**Use Case 1: Cost Optimization**
```
Question: "Are we over-procuring response services?"

Analysis:
- Review Response Activation Analysis
- If average utilization < 30% across 4 months
- AND max utilization < 60%
→ Potential to reduce holdings by 10-15%
→ Cost saving: ~£5-10M/year
```

**Use Case 2: Risk Assessment**
```
Question: "Do we have enough response for worst-case scenarios?"

Analysis:
- Identify worst Red event: Peak imbalance = 750 MW
- Current holdings: 2,000 MW
- Safety factor: 2,000 / 750 = 2.67×
→ Adequate for known scenarios ✓

BUT if worst event was 1,200 MW:
- Safety factor: 2,000 / 1,200 = 1.67×
→ Marginal - recommend increase to 2,400 MW
```

**Use Case 3: Technology Transition**
```
Question: "Should we shift from traditional to fast response?"

Analysis:
- High RoCoF events (>0.03 Hz/s): 25% of total
- Fast response (DR+DM+DC): 1,200 MW (60% of total)
- Traditional (Primary+Secondary): 800 MW (40%)

Trend: RoCoF events increasing due to lower inertia
→ Recommendation: Shift investment toward DC/DM
→ Target: 70% fast, 30% traditional by next year
```

---

## 4.2 System Review Tab

**Purpose**: Analyze system inertia and fundamental dynamics that determine frequency stability.

---

### 4.2.1 Understanding System Inertia

**What Is Inertia?** (Non-Technical Explanation)

Imagine a flywheel spinning at 50 revolutions per second. The flywheel has mass and momentum - it resists changes to its speed. When you try to slow it down, it keeps spinning for a while. When you try to speed it up, it resists.

**In the power system**:
- Large generators (coal, nuclear, gas) are like heavy flywheels
- They spin synchronously at 50 Hz (3,000 RPM)
- Their rotating mass gives the system inertia
- **High inertia = slow frequency changes = more time to react**

**Technical Definition**:
```
Inertia (H) = Kinetic Energy Stored / System Base Power
Units: GVA·s (Gigavolt-Ampere seconds)

Kinetic Energy = 0.5 × J × ω²
Where:
J = Moment of inertia (kg·m²)
ω = Angular velocity (rad/s)
```

---

### 4.2.2 Why Inertia Is Changing

**Historical GB System** (1990s-2010s):
- **Dominated by**: Large coal and nuclear stations
- **Typical Inertia**: 160-180 GVA·s
- **Characteristics**: Heavy, stable, slow to change

**Modern GB System** (2020s):
- **Dominated by**: Wind, solar, interconnectors, gas (CCGTs)
- **Typical Inertia**: 120-150 GVA·s (and falling)
- **Characteristics**: Lightweight, variable, fast-changing

**The Challenge**:
```
Wind/Solar = Zero Inertia (inverter-connected, not rotating)
Each coal station closed = -2 to -4 GVA·s lost
Each offshore wind farm added = 0 GVA·s gained

Result: System inertia declining ~10-15% per decade
```

**Business Impact**:
```
Lower Inertia → Higher RoCoF → More stress on protection systems
→ Need more fast response services (DM, DC)
→ Higher balancing costs
→ Potential stability limits on renewable generation
```

---

### 4.2.3 System Inertia Summary Panel

**Metrics Displayed**:

**1. Average Inertia (GVA·s)**
- Mean system inertia across analysis period
- Example: 142 GVA·s
- **Interpretation**:
  - >160 GVA·s: Very high (legacy system)
  - 140-160 GVA·s: High (adequate)
  - 120-140 GVA·s: Moderate (typical modern system)
  - <120 GVA·s: Low (requires special management)

**2. Minimum Inertia (GVA·s)**
- Lowest inertia observed
- Example: 105 GVA·s
- **Risk Indicator**: How low does inertia fall during critical periods?
- **Action Trigger**: If min < 100 GVA·s → Implement inertia management strategy

**3. Maximum Inertia (GVA·s)**
- Highest inertia observed
- Example: 175 GVA·s
- **Context**: Typically during high demand, high coal/nuclear dispatch

**4. Inertia Range (GVA·s)**
- Difference between max and min
- Example: 175 - 105 = 70 GVA·s
- **Interpretation**:
  - Large range → Highly variable dispatch
  - Small range → Consistent generation mix

---

### 4.2.4 Inertia Over Time (Line Chart)

**What**: System inertia trends across analysis period

**X-Axis**: Date
**Y-Axis**: Inertia (GVA·s)
**Resolution**: Daily average (calculated from 30-minute settlement periods)

**Patterns to Identify**:

**Pattern 1: Weekly Cycle**
```
Monday-Friday: 140-150 GVA·s (high demand, more conventional plant)
Saturday-Sunday: 115-125 GVA·s (low demand, more renewables)

Interpretation: Weekends are higher risk (lower inertia)
```

**Pattern 2: Time-of-Day Variation**
```
00:00-06:00: 110-120 GVA·s (low demand, minimal conventional generation)
06:00-09:00: 145-155 GVA·s (morning ramp, more plant online)
12:00-14:00: 130-140 GVA·s (high solar, less conventional)
17:00-20:00: 155-165 GVA·s (peak demand, maximum plant online)
21:00-24:00: 135-145 GVA·s (falling)

Interpretation: Midnight-6am and midday are vulnerable periods
```

**Pattern 3: Long-Term Trend**
```
May 2025: Avg 145 GVA·s
June 2025: Avg 142 GVA·s
July 2025: Avg 138 GVA·s
August 2025: Avg 135 GVA·s

Interpretation: Declining trend (~7% over 4 months)
→ Possible causes: More renewables, coal/nuclear outages
→ Action: Monitor RoCoF compliance, increase fast response
```

---

### 4.2.5 Inertia Distribution (Histogram)

**What**: Frequency distribution of inertia levels

**Bins**:
```
<100 GVA·s: Critical (red zone)
100-120 GVA·s: Low (yellow)
120-140 GVA·s: Moderate (green)
140-160 GVA·s: High (green)
>160 GVA·s: Very high (blue)
```

**Example Distribution**:
```
<100 GVA·s: 2% (rare, but concerning)
100-120 GVA·s: 15% (occasional low periods)
120-140 GVA·s: 45% (most common)
140-160 GVA·s: 30%
>160 GVA·s: 8% (rare high periods)
```

**Risk Assessment**:
```
If >10% of time spent <120 GVA·s
→ System frequently operating in low-inertia regime
→ Requires:
   1. Increased DC/DM response holdings
   2. Inertia procurement services
   3. Operational limits on renewable dispatch during critical periods
```

---

### 4.2.6 Inertia vs RoCoF Correlation Analysis

**What**: Explores relationship between system inertia and observed RoCoF

**Expected Relationship**:
```
RoCoF = Imbalance × 50 / (2 × Inertia)

Therefore:
Lower Inertia → Higher RoCoF (for same imbalance)
```

**Scatter Plot Interpretation**:

**Ideal Pattern**:
```
High Inertia (>150 GVA·s) → Low RoCoF (<0.02 Hz/s)
Low Inertia (<120 GVA·s) → High RoCoF (>0.03 Hz/s)

Clear inverse correlation → System behaving as expected
```

**Concerning Pattern**:
```
High Inertia → Still seeing high RoCoF

Interpretation: Imbalances are very large, overwhelming inertia benefit
→ Root cause is demand forecasting or generation scheduling, not inertia
→ Action: Focus on improving forecasts
```

---

### 4.2.7 System Dynamics Review Table

**What**: Comprehensive dataset of system conditions per settlement period

**Columns**:

| Column | Description | Use Case |
|--------|-------------|----------|
| **Date** | Settlement period date | Time filtering |
| **SP** | Settlement period (1-48) | Intraday pattern analysis |
| **Inertia (GVA·s)** | System inertia | Low inertia identification |
| **Demand (MW)** | National demand | Demand vs inertia correlation |
| **Primary (MW)** | Primary response holding | Service adequacy check |
| **Secondary (MW)** | Secondary response holding | Service mix analysis |
| **Total Response (MW)** | Sum of all response | Coverage ratio calculation |

**Interactive Features**:
- **Sort**: Identify lowest inertia periods
- **Filter**: Focus on specific dates/SPs
- **Export**: Download for external analysis

**Example Use**:
```
Query: "Find all SPs with inertia <110 GVA·s"
Result: 24 settlement periods identified

Cross-reference with Frequency Events tab:
→ Did low inertia periods correlate with Red events?
→ If YES: Implement inertia management constraints
→ If NO: Other factors (imbalance size) more important
```

---

### 4.2.8 Business Applications

**Application 1: Inertia Floor Management**
```
Observation: Events become severe when inertia <115 GVA·s
Decision: Establish operational limit
Implementation:
  - If forecast inertia <115 GVA·s
  → Mandatorily dispatch minimum number of synchronous generators
  → OR procure synthetic inertia services
  → Costs: £50-100k per low-inertia day
  → Benefit: Prevent Red events costing £1-5M in balancing actions
```

**Application 2: Long-Term Planning**
```
Trend: Inertia declining 10% per year
Projection: Will reach 100 GVA·s (critical threshold) in 4 years

Investment Options:
A) Synchronous Compensators (£50M each, +3 GVA·s)
B) Synthetic Inertia from Batteries (£30M each, +2 GVA·s equivalent)
C) Grid-Forming Inverters on Wind Farms (£100M, +10 GVA·s equivalent)

ROI Analysis:
  - Current balancing costs due to low inertia: £20M/year
  - Option C: Payback in 5 years
→ Recommendation: Invest in grid-forming technology
```

**Application 3: Real-Time Operations**
```
Real-Time Dashboard Use:
09:00 - Check forecast inertia for today
      - If any SP <120 GVA·s → Flag for closer monitoring
      - Pre-position additional fast response
      - Brief control room staff on high-risk periods

14:00 - Solar peak approaching, inertia expected to fall
      - Validate actual vs forecast inertia
      - If falling faster than expected → Activate contingency plan

18:00 - Evening peak, inertia should recover
      - Confirm sufficient synchronous plant online
      - Prepare for evening demand ramp
```

---

**Next**: [Part 5: Demand Analysis Modules](05_Demand_Analysis.md)
