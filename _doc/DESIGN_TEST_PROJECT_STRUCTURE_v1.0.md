# DESIGN: AGS Test Project Structure (v1.0)

## 1. Overview
The current AGS test environment mixes MQL5 source code, PowerShell scripts, configuration files, and test data. This document defines a systematic structure to separate "Logic" (MQL5) from "Data" (Scenarios/Config) and "Automation" (Scripts).

## 2. Structural Hierarchy

### 2.1. Non-Code Assets (`/_Test/`)
The root `_Test` folder is dedicated to assets that are NOT MQL5 source code.

| Folder | Content Type | Responsibility |
| :--- | :--- | :--- |
| `/_Test/Automation/` | `.ps1`, `.bat` | Test execution, build automation, and orchestration. |
| `/_Test/Config/` | `.ini`, `.json` | MT5 startup configurations, broker settings, and environment variables. |
| `/_Test/Scenarios/` | `.json`, `.tsdl` | Pure test scenario definitions (Input data for runners). |
| `/_Test/Results/` | `.txt`, `.log`, `.db` | Output artifacts, performance reports, and test logs. |

### 2.2. MQL5 Logic Assets (`/MT5/_Test/`)
The `MT5/_Test` folder remains within the MQL5 environment but is refactored for clarity.

| Category | Folder Path | Responsibility | Content Type |
| :--- | :--- | :--- | :--- |
| **Engine** | `/MT5/_Test/Runners/` | Main execution engines (AGSTestRunner, AGSScenarioRunner). | Program Code |
| **Suite** | `/MT5/_Test/Suites/` | Test suites containing logical assertions and unit tests. | Program Code |
| **Mock** | `/MT5/_Test/Mocks/` | Mock objects for isolating system dependencies. | Program Code |
| **Shared** | `/MT5/_Test/Framework/` | Shared testing utilities (Pricer, Loader, Assert library). | Program Code |

## 3. Implementation Plan

### 3.1. Directory Migration
1. Create `D:/Projects/AGS/_Test/` and its subdirectories.
2. Move root-level `.ps1` files to `_Test/Automation/`.
3. Move `.ini` files to `_Test/Config/`.
4. Migrate `MT5/_Test/Scenarios/scenario_manifest.json` to `_Test/Scenarios/`.

### 3.2. Script Refactoring
- Update `Automation/run_unit_tests.ps1` to reference `Config/unit_startup.ini`.
- Update Runners to look for scenario data in the standardized `CommonPath` or external data folders.

## 4. Verification Criteria
- All tests must pass using the new paths.
- No "Data" files (JSON/INI) should be mixed with "Logic" files (MQ5/MQH) in the same directory levels.
- The `_Test/Results/` folder should remain empty in source control (via `.gitignore`).
