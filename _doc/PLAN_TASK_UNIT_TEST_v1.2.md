# AGS Task-Level Unit Test Plan (v1.2)

## 1. Objectives

This document defines the plan, scenarios, and verification metrics for the isolated task-level unit tests of the AGS (Antigravity System) framework. By mocking database and terminal endpoints, we achieve high-speed testing of individual tasks (Pending, Active, Exit stages) without actual broker environments.

---

## 2. Test Targets & Checklist

The following micro-tasks inside the orchestrator workflow are targeted for verification:

- `[x]` **Pending Phase Tasks**
  - [x] `CXTaskPending_V_Sync` (TASK_P_V_SYNC) - State synchronization post-placement.
- `[x]` **Active Phase Tasks**
  - [x] `CXTaskSync_V_Stale` (TASK_A_V_STALE) - Cleanup for stale pending requests.
  - [x] `CXTaskActive_V_Terminal` (TASK_A_V_TERMINAL) - Verification of active terminals.
  - [x] `CXTaskActive_P_Align` (TASK_A_P_ALIGN) - Database-to-terminal alignment.
- `[x]` **Exit Phase Tasks**
  - [x] `CXTaskExit_L_Prepare` (TASK_X_L_PREPARE) - Pre-liquidation gatekeeper.
  - [x] `CXTaskExit_P_Lock` (TASK_X_P_LOCK) - Database lock execution.
  - [x] `CXTaskExit_R_Order` (TASK_X_R_ORDER) - Liquidation order dispatcher.
  - [x] `CXTaskExit_V_Error` (TASK_X_V_ERROR) - Broker retry timeout handler.
  - [x] `CXTaskExit_V_Terminal` (TASK_X_V_TERMINAL) - Physical asset absence validator.
  - [x] `CXTaskExit_P_Finalize` (TASK_X_P_FINALIZE) - Database close finalizer.

---

## 3. Detailed Scenario Design

### 3.1 TestPendingSync (CXTaskPending_V_Sync)
- **Objective**: Ensure that a pending signal resolves into the active cycle or is cleaned up depending on terminal realities.
- **Scenarios**:
  - **Scenario A (Forced Liquidation)**: If exit intent (`xa_exit == XA_ACTIVE`) is flagged externally, transition state directly to `SESSION_LIQUIDATING`.
  - **Scenario B (Broker Order Filled)**: If `IsPositionExists(ticket)` returns true, update database status to `XE_EXECUTED` and transition state to `SESSION_ACTIVE`.
  - **Scenario C (Broker Order Rejected)**: If status is flagged as `XE_ERROR`, transition state to `SESSION_ERROR`.
  - **Scenario D (Orphaned Order)**: If ticket ID <= 0, prevent blocking and return `TASK_BREAK`.

### 3.2 TestActiveSync (Active Synchronization Bundle)
- **Objective**: Ensure that zombie pending requests are rolled back and manual exits at the terminal level align with the DB.
- **Scenarios**:
  - **Scenario A (Zombie Request Rollback)**: If a request is stuck in `XE_PENDING_REQ` and `IsTimedOut()` triggers, rollback signal status to `XE_READY` to allow re-evaluation.
  - **Scenario B (Terminal Alignment)**:
    - *Case 1 (Asset present)*: Verify `CXTaskActive_V_Terminal` outputs success (1) and `CXTaskActive_P_Align` remains neutral.
    - *Case 2 (Asset missing)*: Verify `CXTaskActive_V_Terminal` outputs missing (0) and `CXTaskActive_P_Align` triggers alignment using `posMgr.Pulse()`.

### 3.3 TestExitWorkflow (Liquidation Pipeline Integration)
- **Objective**: Ensure the full liquidation pipeline executes sequentially under normal and failure modes.
- **Scenarios**:
  - **Scenario A (Successful Normal Exit)**: Run Prepare -> Lock -> Order (sends request) -> Error Check -> Terminal Check (absence confirmed) -> Finalize. Ensure state transitions to `SESSION_CLOSED` and `xa_exit == 2`.
  - **Scenario B (Broker Disconnection Recovery)**: Simulate a broker disconnect where `SweepBySid` returns false. Verify `Exit_R_Order` returns `TASK_YIELD` to retry rather than locking up.
  - **Scenario C (Asset Absence Verification Timeout)**: Simulate an asset that refuses to disappear from MT5. Verify `Exit_V_Terminal` fails and returns `SESSION_ERROR` after 5 failed check pulses.

---

## 4. AI Model Selection Matrix (Gemini 2.5 ~ 3.1)

Execution routing of the test scenario generator and workspace runner is optimized under the following parameters:

| Tier | Function | Recommended AI Model | Metric Guidelines |
| :--- | :--- | :--- | :--- |
| **Tier 1** | Verification & Polling Tasks | **Gemini 2.5/3.0 Flash** | Latency < 100ms, low-cost high frequency throughput |
| **Tier 2** | Stateful Routing Decisions | **Gemini 2.5/3.0/3.1 Pro** | Zero split-brain tolerance, strict schema checks |
| **Tier 3** | Algorithmic Trail Logic | **Gemini 2.5/3.0/3.1 Pro / Ultra** | Double-precision math, price rebound analysis |
| **Tier 4** | Code Generation & Tooling | **Gemini 2.5/3.0/3.1 Ultra / Advanced** | Strict compliance with compiler checks (`0 errors, 0 warnings`) |
