# PART 2: SYSTEM BACKGROUND & DATA SOURCES

---

## 2.1 GB Power System Fundamentals

### 2.1.1 What is Grid Frequency?

**Definition**: Grid frequency is the rate at which the AC (alternating current) voltage oscillates, measured in Hertz (Hz). In Great Britain, the target frequency is **50.0 Hz**.

**Physical Meaning**:
- 50 Hz means the voltage completes 50 full cycles per second
- This synchronous frequency is maintained across the entire GB transmission system
- ALL generators connected to the grid must rotate at exactly the same speed (synchronized)

### 2.1.2 Why Frequency Matters

**The Fundamental Law of Power Systems**:
```
Generation = Demand + Losses
```

When this balance is maintained, frequency stays at 50 Hz.

**What Happens When Balance Breaks?**

| Scenario | Frequency Response | Physical Explanation |
|----------|-------------------|----------------------|
| **Generation > Demand** | Frequency **rises** (>50 Hz) | Excess energy accelerates rotating generators |
| **Generation < Demand** | Frequency **falls** (<50 Hz) | Generators slow down as energy is extracted |
| **Perfect Balance** | Frequency = 50 Hz | System in equilibrium |

**Why This Is Critical**:
- Extreme frequency deviations can damage equipment
- Prolonged imbalance can cause cascading failures
- Automatic protection systems disconnect loads/generators if frequency goes too far
- Major blackouts typically involve frequency collapse

---

### 2.1.3 System Inertia

**Definition**: Inertia is the system's natural resistance to frequency change, provided by the rotating mass of synchronous generators.

**Formula**:
```
H = Stored Kinetic Energy / System Base Power
```
Where H is measured in GVA·s (Gigavolt-Ampere seconds)

**Key Concept**:
- **High Inertia** (150+ GVA·s): System with many large coal/nuclear generators
  - Frequency changes slowly
  - More time to activate corrective actions
  - Better stability

- **Low Inertia** (100- GVA·s): System with high wind/solar penetration
  - Frequency changes rapidly (high RoCoF)
  - Less time to respond
  - Requires faster response services

**Real Example from Dashboard**:
- Event on May 29, 2025: System inertia = 142 GVA·s
- This represents approximately 40-50 large synchronous generators online
- Lower than historical averages (150-180 GVA·s) due to increased renewables

---

### 2.1.4 Rate of Change of Frequency (RoCoF)

**Definition**: How fast frequency is changing, measured in Hz/s (Hertz per second).

**Formula**:
```
RoCoF = dF/dt = (Generation - Demand) × System_Frequency / (2 × Inertia)
```

**Simplified**:
```
RoCoF (Hz/s) = Imbalance (MW) × 50 / (2 × Inertia_GVAs)
```

**Real Example**:
- Imbalance: -600 MW (generation shortage)
- Inertia: 150 GVA·s
- RoCoF = -600 × 50 / (2 × 150) = **-0.10 Hz/s**

This means frequency is falling at 0.10 Hz every second.

**Why RoCoF Matters**:
- High RoCoF (>0.125 Hz/s) can trigger generator protection relays
- Renewable generators are particularly sensitive to high RoCoF
- GB Grid Code limits RoCoF to protect equipment

---

## 2.2 Settlement Periods & Market Structure

### 2.2.1 What is a Settlement Period?

**Definition**: A Settlement Period (SP) is a **30-minute trading interval** used in the GB electricity market.

**Structure**:
- Each day has **48 Settlement Periods**
- SP 1: 00:00 - 00:30
- SP 2: 00:30 - 01:00
- ...
- SP 48: 23:30 - 24:00

**Market Timeline**:
```
Day-Ahead Market → Intraday Trading → Gate Closure (1 hour before) → Settlement Period → Actual Delivery
```

### 2.2.2 Why SP Boundaries Are Critical

**The Problem**: At each SP boundary (e.g., 12:00, 12:30, 13:00), demand can change **significantly and suddenly**.

**Why**:
1. **Market Forces**: Different generators are scheduled for different SPs
2. **Consumer Behavior**: Industrial loads switch on/off at :00 and :30
3. **Forecasting Challenges**: Actual demand often differs from predicted demand

**Real-World Example**:
```
SP 25 (12:00-12:30): Demand forecast = 35,000 MW
SP 26 (12:30-13:00): Demand forecast = 37,000 MW
Expected change at 12:30: +2,000 MW

BUT...
Actual demand at 12:30: 37,800 MW
Unforeseen change: +800 MW beyond forecast!
```

This 800 MW error causes an immediate power imbalance → frequency drop.

---

### 2.2.3 The Link Between SP Boundaries and Frequency Events

**Key Insight**: Frequency events cluster around SP boundaries because:

1. **Predictable Timing**: Changes happen at :00 and :30
2. **Magnitude Uncertainty**: Exact demand change is unknown until it happens
3. **Generation Lag**: Generators can't instantly adjust to real demand
4. **Forecasting Errors**: Difference between predicted and actual demand

**Evidence from Dashboard**:
- 159 detected events analyzed
- All events detected within ±60 seconds of SP boundaries
- This is BY DESIGN - the dashboard focuses on SP-related risk

**Two Types of Events**:

| Type | Timing | Cause | Predictability |
|------|--------|-------|----------------|
| **Demand-Driven** | At SP boundary | Forecast error + market shift | Predictable timing, unpredictable magnitude |
| **Random** | Any time | Generator trip, line fault | Completely unpredictable |

The dashboard focuses on **demand-driven events** because they are preventable through better forecasting.

---

## 2.3 Frequency & System Stability

### 2.3.1 Frequency Operating Ranges

GB Grid Code defines frequency limits:

| Range | Frequency | Classification | Action Required |
|-------|-----------|----------------|-----------------|
| **Normal** | 49.95 - 50.05 Hz | Acceptable | None |
| **Operational** | 49.80 - 50.20 Hz | Deviation | Activate frequency response |
| **Extreme** | 49.50 - 50.50 Hz | Major event | Emergency actions |
| **Critical** | <49.20 or >51.00 Hz | System threat | Load shedding / generator trips |

### 2.3.2 Frequency Response Services

The system has automatic responses to frequency deviations:

**Low Frequency Response (LF)**: When frequency drops
- **Primary Response**: Activates within 10 seconds (droop-based)
- **Secondary Response**: Activates within 30 seconds
- **High Response**: Additional fast reserves
- **DR (Dynamic Regulation)**: Continuous frequency control
- **DM (Dynamic Moderation)**: Fast-acting batteries
- **DC (Dynamic Containment)**: Fastest response (1 second)

**High Frequency Response (HF)**: When frequency rises
- Reduces generation or increases load

**Key Formula**:
```
LF Response (MW) = Frequency Deviation (Hz) × Response Droop Factor
```

For a 0.5 Hz drop with 2000 MW contracted response:
```
LF Response = 0.5 × (2000 / 0.5) = 2000 MW activated
```

### 2.3.3 Demand Damping

**Natural Phenomenon**: When frequency drops, electrical demand automatically reduces.

**Why**: Many electrical devices (motors, resistive loads) consume less power at lower voltage/frequency.

**Standard Value**: **2.5% per Hz** (NESO standard)

**Formula**:
```
Demand Damping (MW) = Base Demand (MW) × 0.025 × Frequency Change (Hz)
```

**Example**:
- Base demand: 35,000 MW
- Frequency drop: -0.15 Hz (from 50.00 to 49.85 Hz)
- Demand damping = 35,000 × 0.025 × (-0.15) = **-131 MW**

The negative sign means demand REDUCED by 131 MW, which helps stabilize the system (acts like additional generation).

**Critical Understanding**:
- Demand damping is **automatic and instantaneous**
- It HELPS during low frequency (demand reduces)
- It HINDERS during high frequency (demand increases)
- Must be SEPARATED from market-driven demand changes

---

## 2.4 Data Sources & Collection

### 2.4.1 Primary Data Source: NESO Frequency Data

**Source**: NESO (National Energy System Operator) Open Data Portal

**API Endpoint**:
```
https://api.neso.energy/api/3/action/datapackage_show?id=system-frequency-data
```

**Data Format**:
- **File Pattern**: `fnew-YYYY-M.csv` (one file per month)
- **Temporal Resolution**: 1-second granularity
- **Columns**:
  - `dtm`: Timestamp (UTC)
  - `f`: Frequency in Hz

**Example Data**:
```csv
dtm,f
2025-05-29T17:59:50Z,50.045
2025-05-29T17:59:51Z,50.046
2025-05-29T17:59:52Z,50.044
```

**Coverage**: This analysis covers May-August 2025 (4 months)

---

### 2.4.2 Demand Data

**Source**: NESO Demand Data Out-Turn

**File**: `system_demand.csv` (3.1 MB)

**Format**:
```csv
SETTLEMENT_DATE,SETTLEMENT_PERIOD,ND,TSD,ENGLAND_WALES_DEMAND,...
01-JAN-2024,1,21783,23466,19539,...
```

**Key Metrics**:
- **ND (National Demand)**: Total GB electricity demand (MW)
- **TSD (Transmission System Demand)**: Demand seen by transmission grid
- **ENGLAND_WALES_DEMAND**: Regional demand

**Temporal Resolution**: One value per Settlement Period (30 minutes)

**Use in Dashboard**:
- Demand Analysis tab: Track demand patterns
- Unforeseen Demand tab: Calculate forecast errors
- Imbalance Analysis: Provide base demand for damping calculations

---

### 2.4.3 Inertia Data

**Source**: NESO System Inertia Reports

**File**: `system_inertia.csv` (933 KB)

**Format**:
```csv
Settlement Date,Settlement Period,Outturn Inertia,Market Provided Inertia
2023-04-01,1,142,130
```

**Key Metric**:
- **Outturn Inertia** (GVA·s): Actual system inertia delivered

**Temporal Resolution**: One value per Settlement Period

**Use in Dashboard**:
- System Review tab: Track inertia trends
- Imbalance Analysis: Calculate RoCoF component accurately

**Typical Values**:
- Historical (high coal/nuclear): 150-180 GVA·s
- Current (more renewables): 120-150 GVA·s
- Low inertia periods: <100 GVA·s (high risk)

---

### 2.4.4 Response Holdings Data

**Source**: Derived from MFR (Month-Forward Reports) and EAC (Enhanced Ancillary Contracts)

**File**: `data/output/reports/system_dynamics_review.csv` (generated internally)

**Content**: Contracted frequency response capacity per service type:
- `primary_mw`: Primary frequency response
- `secondary_mw`: Secondary frequency response
- `high_mw`: High frequency response
- `dr_mw`: Dynamic Regulation
- `dm_mw`: Dynamic Moderation
- `dc_mw`: Dynamic Containment

**Temporal Resolution**: Monthly averages

**Typical Values** (approximate):
- Primary: 500 MW
- Secondary: 300 MW
- High: 200 MW
- DR: 300 MW
- DM: 400 MW
- DC: 500 MW

---

## 2.5 Data Quality & Coverage

### 2.5.1 Data Completeness

**Frequency Data** (primary source):
- **Expected Records**: ~10.5 million seconds (4 months × 30 days × 24 hours × 3600 seconds)
- **Actual Coverage**: >99.9% complete
- **Missing Data Handling**: Linear interpolation for gaps <10 seconds

**Demand Data**:
- **Expected Records**: 5,760 settlement periods (4 months × 48 SPs × 30 days)
- **Actual Coverage**: 100% complete
- **Source**: Official NESO settlement data (authoritative)

**Inertia Data**:
- **Coverage**: Historical data from April 2023 onwards
- **Quality**: Direct NESO reports, no interpolation needed

---

### 2.5.2 Data Validation & Quality Checks

**Frequency Data Validation**:
1. **Range Check**: All values must be within 47.0 - 53.0 Hz (extreme physical limits)
2. **Continuity Check**: No jumps >0.5 Hz between consecutive seconds
3. **Timestamp Validation**: Strictly ascending timestamps

**Demand Data Validation**:
1. **Reasonableness**: Demand between 15,000 - 55,000 MW
2. **No Missing SPs**: All 48 periods present for each day
3. **Cross-validation**: ND > ENGLAND_WALES_DEMAND (GB > England & Wales)

**Derived Data Quality**:
1. **Event Detection**: Manual verification of top 10 worst events
2. **Imbalance Calculation**: Validation plots for extreme events
3. **Statistical Checks**: Outlier detection (>3σ) flagged for review

---

### 2.5.3 Known Limitations

**1. Inertia Data Granularity**
- **Limitation**: Inertia reported per 30-minute SP, not per second
- **Impact**: Imbalance calculations use nearest SP inertia value
- **Mitigation**: Conservative assumption - actual inertia may vary during event

**2. Response Holdings**
- **Limitation**: Monthly average holdings, not real-time activation
- **Impact**: Cannot confirm exact MW response activated per event
- **Mitigation**: Use contracted holdings as upper bound estimate

**3. Event Detection Scope**
- **Limitation**: Only detects events within ±60 seconds of SP boundaries
- **Impact**: Random mid-SP events not captured (by design)
- **Mitigation**: Scope clearly documented; focus is SP-related events

**4. Demand Forecast Baseline**
- **Limitation**: No official NESO forecast data available
- **Impact**: "Unforeseen demand" uses statistical baseline (hourly mean)
- **Mitigation**: Clearly documented in Unforeseen Demand methodology

---

### 2.5.4 Data Refresh & Update Cycle

**Current Implementation**:
- **Analysis Period**: May - August 2025 (fixed retrospective analysis)
- **Update Frequency**: Manual re-run of pipeline when new data available

**Future Enhancement Potential**:
- **Near Real-Time**: Automate daily data fetch and analysis
- **Rolling Window**: Always show latest 4 months
- **Alerting**: Flag Red events within 24 hours

---

**Next**: [Part 3: Frequency Monitoring Modules](03_Frequency_Monitoring.md)
