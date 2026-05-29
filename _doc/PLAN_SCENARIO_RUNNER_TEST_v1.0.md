# AGSScenarioRunner Test Plan (v1.0)

## 1. Overview

`AGSScenarioRunner.mq5` is a deterministic E2E test runner designed to parse TSDL (Test Scenario Definition Language) scripts and simulate tick-level execution over a mocked trading sandbox. 

This test plan defines the positive validation cases, negative error-injection scenarios, and memory cleanup standards to ensure the runner operates reliably without runtime failures, file-lock contentions, or memory leaks.

---

## 2. Positive Verification Scenarios

### Case P-1: Golden Path TSDL Parsing & Execution
* **Objective**: Verify that the runner successfully parses a standard scenario and executes all steps.
* **Test Scenario**: Set `InpScenarioFile = "AGS\\test_golden_path.tsd"`.
* **Execution Flow**:
  1. Boot the runner EA.
  2. Confirm `CXTsdlParser::Parse()` returns a valid scenario object without grammar warnings.
  3. Let the tick loop advance through defined steps, updating prices and checks.
* **Expected Outcome**:
  - The tick counter increases sequentially up to the scenario maximum.
  - All expectations check out as PASSED in terminal logs.
  - Generates `scenario_result.txt` containing `status=PASSED`.

### Case P-2: Virtual Pricing and Broker Triggers
* **Objective**: Confirm that the virtual pricer generates bid/ask streams and triggers SL/TP exits.
* **Test Scenario**: Set `InpScenarioFile = "AGS\\test_broker_sl_tp.tsd"`.
* **Execution Flow**:
  1. Inject a mock position with SL = 2345.00 and TP = 2355.00.
  2. Virtual pricer generates bid/ask ticks.
  3. Action overrides bid to 2344.90 (crossing SL).
* **Expected Outcome**:
  - `MockTerminalPlatform::UpdateBrokerTriggeredExits` triggers and deletes the position.
  - History is written with `closeStatus = XE_CLOSED_SL`.
  - Expectation `terminal ticket=xxx exists=false` resolves to PASSED.

### Case P-3: Dynamic Redirection Control
* **Objective**: Ensure the runner dynamically overrides hardcoded parameters via external files.
* **Test Scenario**: Write `"AGS\\test_manual_exit.tsd"` to `scenario_target.txt` inside terminal common files.
* **Execution Flow**:
  1. Initialize `AGSScenarioRunner.mq5`.
  2. Confirm console outputs: `[RUNNER] Redirecting target to: AGS\\test_manual_exit.tsd`.
* **Expected Outcome**:
  - `InpScenarioFile` parameter is bypassed.
  - The engine runs and completes the redirected `test_manual_exit` script.

---

## 3. Negative & Robustness Scenarios

### Case N-1: Extension Verification Bypass (Fail-Fast)
* **Objective**: Prevent parser loops on files with invalid formats.
* **Test Scenario**: Write `"AGS\\test_script.txt"` to `scenario_target.txt`.
* **Execution Flow**:
  1. Boot the runner EA.
  2. `AuditEnvironment` analyzes the extension.
* **Expected Outcome**:
  - Audit logs error: `Invalid file extension. Expected '.tsd' or '.db'`.
  - Init fails with `INIT_FAILED`, preventing service initialization or parsing.

### Case N-2: Missing TSDL File Handling
* **Objective**: Safely abort if the targeted script file is deleted or missing from the sandbox.
* **Test Scenario**: Request target file `"AGS\\non_existent_scenario.tsd"`.
* **Execution Flow**:
  1. Boot the runner EA.
  2. `AuditEnvironment` performs `FileIsExist` checks on both sandbox and common paths.
* **Expected Outcome**:
  - Logs error: `File not found on disk`.
  - EA terminates immediately with `INIT_FAILED` without throwing runtime pointer exceptions.

### Case N-3: Broker Offline Simulation (Action FAIL)
* **Objective**: Ensure expectation failures are tracked when a simulated broker trade fails.
* **Test Scenario**: Inject `FAIL broker next=true` action, followed by a close request.
* **Expected Outcome**:
  - `MockTerminalPlatform` returns false on the next transaction and sets error code 10013.
  - Runner logs assertion failure: `terminal Asset Ticket:xxx Exists: Exp:False, Act:True`.
  - Scenario ends with `status=FAILED`.

---

## 4. Memory Leak Detection Protocol

To prevent leak build-ups during continuous CI/CD automated E2E runs (e.g. 22 consecutive scenario E2E loops):
* **Audit Rule**:
  - Every allocated object (`g_app`, `g_factory`, `g_pricer`, `g_scenario`, `g_traces`) must be cleanly deleted in `OnDeinit` using the `SAFE_DELETE` macro.
* **Check Procedure**:
  1. Boot runner.
  2. Terminate runner.
  3. Scan MT5 Expert logs for the text `"x bytes of leaked memory"`.
* **Expected Outcome**:
  - Zero memory leaks are reported by the MT5 compiler runtime upon deinitialization.
