# AGS AI Model Execution & Selection Matrix (v1.1)

## 1. Introduction

In the AGS (Antigravity System) framework, runtime tasks are hyper-atomized to separate core trading logic, data persistence, and platform verification. To ensure high execution reliability and cost efficiency, this document defines the standard for selecting and routing tasks to the appropriate AI model class based on execution frequency, latency tolerances, and reasoning depth, standardized for the Gemini 2.5 to 3.1 version family.

---

## 2. Selection Matrix

The framework routes tasks to models in four distinct categories:

| Tier | Task Type | Example Classes / Workflows | Target Metrics | Recommended AI Model |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1** | **Verification & Polling** | `CXTaskActive_V_Terminal`<br>`CXTaskExit_V_Terminal`<br>`CXTaskSync_V_Stale` | - Latency < 100ms<br>- High API frequency<br>- Low-cost scaling | **Gemini 2.5/3.0 Flash** |
| **Tier 2** | **Stateful Decisions** | `CXTaskPending_V_Sync`<br>`CXTaskIntentWatch`<br>`CXTaskExit_P_Lock`<br>`CXTaskExit_P_Finalize` | - Strict rules compliance<br>- Reliable state routing<br>- Medium latency | **Gemini 2.5/3.0/3.1 Pro** |
| **Tier 3** | **Mathematical Evaluation** | `CXTaskTrail_L_Evaluate`<br>`CXTaskTrail_R_Execute`<br>Dynamic SL/TP Fitting | - Analytical deduction<br>- Statistical confidence<br>- Multivariable heuristics | **Gemini 2.5/3.0/3.1 Pro / Ultra** |
| **Tier 4** | **Agentic Engineering** | TSDL test creation (`Test*.mqh`), PowerShell scripts, code generation | - Perfect code compile (`0 errors`) | **Gemini 2.5/3.0/3.1 Ultra / Advanced** |

---

## 3. Tier Specifications & Architectural Rationales

### 3.1 Tier 1: Real-time Verification & Polling (Gemini 2.5/3.0 Flash)
- **Role**: Validating physical terminal asset existence and detecting timeouts on every market tick.
- **Rationals**:
  - **Latency is Critical**: Multi-millisecond delays during high-frequency volatility can cause slippage or execution failures.
  - **High API Footprint**: Continuous polling across multiple active sessions generates substantial API volume. Gemini 2.5/3.0 Flash offers the required performance-to-cost ratio.
  - **Context Limits**: These verification operations process isolated data parameters (e.g., ticket ID and current platform response), requiring minimal reasoning.

### 3.2 Tier 2: Stateful Logic & Transition Gates (Gemini 2.5/3.0/3.1 Pro)
- **Role**: Making deterministic state machine state updates (e.g., shifting from `PENDING` to `ACTIVE`, detecting manual exit bypasses).
- **Rationals**:
  - **Zero Tolerance for Split-Brain**: Transition mistakes (e.g., marking a closed position as active) can cause duplicate order placements or orphaned sessions.
  - **Complex Constraints**: Rules require parsing DB states (`IRepository`) alongside physical status, demanding robust instruction-following capabilities.

### 3.3 Tier 3: Mathematical Heuristics (Gemini 2.5/3.0/3.1 Pro / Ultra)
- **Role**: Evaluating next-generation Trailing entries and exits by tracking dynamic extremums and price rebound offsets.
- **Rationals**:
  - **Numerical Accuracy**: Correctly translating fractional currency values into precise integer points based on symbol attributes.
  - **Long-term Trends**: Tracking previous tick arrays to filter out noise, requiring deep contextual attention over short history feeds.

### 3.4 Tier 4: Code Generation and Agentic Build Tools (Gemini 2.5/3.0/3.1 Ultra / Advanced)
- **Role**: Crafting compile-ready MQL5 test runner modifications, unit tests, and automation orchestration pipelines.
- **Rationals**:
  - **Compilation Guard**: MQL5 code must satisfy zero-warnings and zero-errors criteria under strict include constraints.
  - **Knowledge Breadth**: Agentic coding models handle workspace structures and inter-class dependencies across various languages (MQL5, JSON, PowerShell).

---

## 4. Integration Protocol Guidelines

When implementing AI-driven routers in future AGS components:
1. **Fallback Strategy**: If Tier 3 models encounter timeouts or rate limits, the routing controller should fallback to Tier 2 models instead of aborting the operation.
2. **Context Compression**: For Tier 1 and Tier 2 tasks, strip audit-trail strings and comments from model payloads to minimize latency and input token counts.
3. **Session Cache Utilization**: Reuse state context logs to benefit from input prompt caching mechanisms, reducing computational overhead.
