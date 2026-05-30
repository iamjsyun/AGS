# DESIGN: AGS Test Project Structure (v1.2)

## 1. Overview
The Dual-Zone Architecture separates the test project into two distinct areas: the **Developer Zone** (TestFramework) for testing infrastructure and the **User/Designer Zone** (Test) for scenario definition and environment control.

## 2. Structural Hierarchy

### 2.1. User/Designer Zone (`/Test/`)
Dedicated to scenario design, environment configuration, and result analysis.

| Folder | Name | Content Type | Responsibility |
| :--- | :--- | :--- | :--- |
| `/Test/01_Scenarios/` | Design Zone | `.json`, `.tsdl` | Test scenario definitions (Input data). |
| `/Test/02_Config/` | Control Zone | `.ini`, `.json` | MT5 startup and environment settings. |
| `/Test/03_Results/` | Output Zone | `.txt`, `.db` | Test results and database snapshots. |
| `/Test/04_Logs/` | Archive Zone | `.log` | Execution logs for auditing. |

### 2.2. Developer Zone (`/MT5/TestFramework/` & `/Automation/`)
Contains the internal logic and infrastructure for running tests.

| Folder | Category | Responsibility | Content Type |
| :--- | :--- | :--- | :--- |
| `/MT5/TestFramework/Engine/` | Engine | Main execution engines (Runners). | Program Code |
| `/MT5/TestFramework/Suite/` | Suite | Test suites and logical assertions. | Program Code |
| `/MT5/TestFramework/Mock/` | Mock | Mock objects for isolation. | Program Code |
| `/MT5/TestFramework/Framework/` | Framework | Shared testing framework utilities. | Program Code |
| `/Automation/` | Infra | Build scripts and automation logic. | Scripts |

## 3. Ownership & Workflow
- **Developers**: Maintain the `Developer Zone`. They ensure the Engine correctly interprets scenarios and assertions.
- **Scenario Designers**: Work exclusively in the `Design Zone`. They define trading behaviors without touching MQL5 code.
- **Users**: Manage the `Control Zone` for execution environment and review the `Output Zone`.

## 4. Implementation Plan (v1.1 Update)
1. Rename and move root `.ps1` files to `_Automation/`.
2. Restructure `_Test/` into the numbered zones (`01_`, `02_`, etc.).
3. Update all script paths to follow the new hierarchy.
