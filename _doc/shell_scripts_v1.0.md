# AGS Shell Scripts Overview v1.0

This document provides a summary of the utility PowerShell scripts available in the **[AGS](file:///d:/Projects/AGS)** workspace.

| Script Name | Purpose | Key Details |
| :--- | :--- | :--- |
| **[bags.ps1](file:///d:/Projects/AGS/bags.ps1)** | Build Script | Compiles `MT5\AGS.mq5` using MT5 MetaEditor and logs results to `_log\build_*.log`. |
| **[cags.ps1](file:///d:/Projects/AGS/cags.ps1)** | Syntax Check Script | Compiles `MT5\AGS.mq5` for syntax verification, logging to `_log\check_*.log`. |
| **[run_unit_tests.ps1](file:///d:/Projects/AGS/run_unit_tests.ps1)** | Unit Test Suite Runner | Runs the unit test runner (`AGSTestRunner.mq5`) under the MT5 terminal. |
| **[run_all_scenarios.ps1](file:///d:/Projects/AGS/run_all_scenarios.ps1)** | All Scenarios E2E Runner | Runs all E2E scenarios listed in `scenario_manifest.json` and outputs a test summary report. |
| **[run_single_scenario.ps1](file:///d:/Projects/AGS/run_single_scenario.ps1)** | Single Scenario Runner | Runs a single designated scenario in MT5 for isolated debugging/testing. |

---

## Script Descriptions

### 1. Build Script: [bags.ps1](file:///d:/Projects/AGS/bags.ps1)
* **Compiler Path**: `D:\Program Files\XM Global MT5\MetaEditor64.exe`
* **Log Location**: `d:\Projects\AGS\_log\build_YYYYMMDD.log`
* **Flow**:
  1. Ensures the target log directory exists.
  2. Runs `Start-Process` synchronously to compile `MT5\AGS.mq5`.
  3. Inspects the generated log file for `'Result:\s+0\s+errors'` to declare success.

### 2. Syntax Check Script: [cags.ps1](file:///d:/Projects/AGS/cags.ps1)
* **Compiler Path**: `D:\Program Files\XM Global MT5\MetaEditor64.exe`
* **Log Location**: `d:\Projects\AGS\_log\check_YYYYMMDD.log`
* **Flow**:
  1. Performs a non-linking syntax build of `MT5\AGS.mq5`.
  2. Ensures error count is zero.

### 3. Unit Test Suite Runner: [run_unit_tests.ps1](file:///d:/Projects/AGS/run_unit_tests.ps1)
* **Terminal Path**: `C:\Program Files\XM Global MT5\terminal64.exe`
* **Common Directory**: `%APPDATA%\MetaQuotes\Terminal\Common\Files\AGS`
* **Flow**:
  1. Kills any running instances of `terminal64.exe`.
  2. Prepares the SQLite database `AGS.db` by copying the template `ats.db`.
  3. Writes `"UNIT_TEST"` into `scenario_target.txt`.
  4. Launches MT5 with config `d:\Projects\AGS\unit_startup.ini`.
  5. Polls for `scenario_result.txt` (up to 40 seconds) to verify tests passed.

### 4. Scenario E2E Runner: [run_all_scenarios.ps1](file:///d:/Projects/AGS/run_all_scenarios.ps1)
* **Flow**:
  1. Syncs all `.tsd` scenario files to the MT5 common directory folder (`Core`, `Trade`, `Resilience`).
  2. Reads `scenario_manifest.json`.
  3. Sequentially writes each scenario file target, launches MT5 with `runner_startup.ini`, waits for `scenario_result.txt`, kills terminal, and tracks passed/failed statistics.
  4. Outputs a combined JSON summary to `_doc\result\test_results_summary.json`.
