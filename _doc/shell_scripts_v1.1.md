# AGS Shell Scripts Overview v1.1

## Document History
| Version | Date | Description | Author |
| :--- | :--- | :--- | :--- |
| v1.0 | 2026-05-31 | Initial Shell Scripts Guide | Antigravity |
| v1.1 | 2026-05-31 | Standardized Naming Rule Applied ([Action]_[Target]_[Detail]) | Antigravity |

---

This document provides a summary of the standardized utility PowerShell scripts available in the **[Automation](file:///d:/Projects/AGS/Automation)** workspace.

| Script Name | Purpose | Key Details |
| :--- | :--- | :--- |
| **`build_ags_main.ps1`** | Build Script | Compiles `MT5\04_AppBootstrap\AGS.mq5` and logs to `_log\build_*.log`. |
| **`check_ags_syntax.ps1`** | Syntax Check Script | Compiles for syntax verification, logging to `_log\check_*.log`. |
| **`build_tests.ps1`** | Test Framework Build | Compiles test runners in `MT5\99_TestFramework`. |
| **`run_unit_tests.ps1`** | Standard Unit Test Runner | Runs the unit test runner (`AGSTestRunner.mq5`). |
| **`run_unit_tests_pc201.ps1`** | PC201 Dedicated Runner | Unit test runner optimized for PC ID 201 environment. |
| **`run_all_scenarios.ps1`** | E2E Scenario Runner | Runs all E2E scenarios listed in `scenario_manifest.json`. |
| **`run_scenario_id102.ps1`** | Scenario 102 Runner | Isolated runner for Scenario ID 102. |
| **`inspect_db_pc201.py`** | PC201 DB Inspector | Database inspection tool for PC ID 201. |
| **`setup_mt5_junction.ps1`** | MT5 Junction Setup | Recreates symbolic link between project and MT5 Experts. |

---

## Script Descriptions

### 1. Build: `build_ags_main.ps1`
* **Path**: `Automation\Build\build_ags_main.ps1`
* **Flow**:
  1. Ensures the target log directory exists.
  2. Compiles the main engine entry point.
  3. Verifies zero errors in `_log\build_YYYYMMDD.log`.

### 2. Check: `check_ags_syntax.ps1`
* **Path**: `Automation\Build\check_ags_syntax.ps1`
* **Flow**:
  1. Performs a non-linking syntax build for fast verification.

### 3. Setup: `setup_mt5_junction.ps1`
* **Path**: `Automation\Setup\setup_mt5_junction.ps1`
* **Purpose**: Synchronizes the project source with the MT5 terminal's Expert directory using a Junction.
* **Flow**:
  1. Removes existing links or folders in the MT5 data path.
  2. Creates a new Junction pointing to the project root.

### 3. Execution: `run_unit_tests_pc201.ps1`
* **Purpose**: Targeted testing for machine 201.
* **Flow**: Prepares SQLite DB, launches MT5 with specific PC settings, and polls for results.
