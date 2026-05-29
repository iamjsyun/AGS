# AGS AI Model Execution & Selection Matrix (v1.2)

## 1. Introduction

In the AGS (Antigravity System) framework, runtime tasks are hyper-atomized to separate core trading logic, data persistence, and platform verification. To ensure high execution reliability and cost efficiency, this document defines the standard for selecting and routing tasks to the appropriate AI model class based on execution frequency, latency tolerances, and reasoning depth, standardized for the Gemini 2.5 to 4.0 version family.

---

## 2. Selection Matrix (Task-Level Mapping)

The framework routes tasks to models in four distinct categories. v1.2 introduces explicit class mapping for all core workflow tasks.

| Tier | Task Type | Explicit Class Mapping | Target Metrics | Recommended AI Model |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1** | **Verification & Polling** | `CXTaskActive_V_Terminal`<br>`CXTaskExit_V_Terminal`<br>`CXTaskSync_V_Stale`<br>`CXTaskPending_V_Sync` | - Latency < 100ms<br>- High API frequency<br>- Low-cost scaling | **Gemini 2.5/3.0 Flash** |
| **Tier 2** | **Stateful Decisions** | `CXTaskIntentWatch`<br>`CXTaskExit_P_Lock`<br>`CXTaskExit_P_Finalize`<br>`CXTaskTrail_V_Activate` | - Strict rules compliance<br>- Reliable state routing<br>- Medium latency | **Gemini 3.0/3.5 Pro** |
| **Tier 3** | **Mathematical Evaluation** | `CXTaskTrail_L_Evaluate`<br>`CXTaskTrail_R_Execute`<br>`CXTaskTrail_V_Extremum`<br>`CXTaskExit_R_Order` | - Analytical deduction<br>- Statistical confidence<br>- Multivariable heuristics | **Gemini 3.5/4.0 Pro / Ultra** |
| **Tier 4** | **Agentic Engineering** | TSDL test creation (`Test*.mqh`), PowerShell scripts, code generation | - Perfect code compile (`0 errors`) | **Gemini 4.0 Ultra / Advanced** |

---

## 3. Tier Specifications & Architectural Rationales

### 3.1 Tier 1: Real-time Verification & Polling (Gemini Flash)
- **Role**: Validating physical terminal asset existence and detecting timeouts on every market tick.
- **Rationals**:
  - **Latency is Critical**: Multi-millisecond delays during high-frequency volatility can cause slippage or execution failures.
  - **High API Footprint**: Continuous polling across multiple active sessions generates substantial API volume. 
  - **Tasks**: `CXTaskActive_V_Terminal` and `CXTaskExit_V_Terminal` are called every tick for every active session.

### 3.2 Tier 2: Stateful Logic & Transition Gates (Gemini Pro)
- **Role**: Making deterministic state machine state updates (e.g., shifting from `PENDING` to `ACTIVE`, detecting manual exit bypasses).
- **Rationals**:
  - **Zero Tolerance for Split-Brain**: Transition mistakes can cause duplicate order placements.
  - **Tasks**: `CXTaskIntentWatch` must reliably detect when a user manually closes a position to prevent the engine from attempting to manage a non-existent asset.

### 3.3 Tier 3: Mathematical Heuristics (Gemini Pro / Ultra)
- **Role**: Evaluating next-generation Trailing entries and exits by tracking dynamic extremums and price rebound offsets.
- **Rationals**:
  - **Numerical Accuracy**: Correctly translating fractional currency values into precise integer points.
  - **Tasks**: `CXTaskTrail_L_Evaluate` handles complex "If-Then" logic for trailing triggers.

### 3.4 Tier 4: Code Generation and Agentic Build Tools (Gemini Ultra / Advanced)
- **Role**: Crafting compile-ready MQL5 test runner modifications, unit tests, and automation orchestration pipelines.
- **Rationals**:
  - **Compilation Guard**: MQL5 code must satisfy zero-warnings and zero-errors criteria.

---

## 4. Integration Protocol Guidelines

1. **Fallback Strategy**: If Tier 3 models encounter timeouts, fallback to Tier 2.
2. **Context Compression**: Strip audit-trail strings for Tier 1 and Tier 2 tasks.
3. **Session Cache Utilization**: Use prompt caching for stable task descriptions.
