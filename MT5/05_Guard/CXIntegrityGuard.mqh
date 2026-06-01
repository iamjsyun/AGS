#ifndef CXINTEGRITYGUARD_MQH
#define CXINTEGRITYGUARD_MQH

#include "..\01_Core\Interfaces\ICXIntegrityGuard.mqh"
#include "..\01_Core\Interfaces\ICXConfig.mqh"
#include "..\01_Core\Interfaces\IDatabase.mqh"
#include "..\01_Core\Interfaces\IRepository.mqh"
#include "..\01_Core\Interfaces\ICXAssetManager.mqh"
#include "..\01_Core\Interfaces\ICXPriceManager.mqh"
#include "..\01_Core\Interfaces\ICXSymbolManager.mqh"
#include "..\01_Core\Interfaces\ICXRiskManager.mqh"
#include "..\01_Core\Interfaces\IXTerminalPlatform.mqh"
#include "..\01_Core\Interfaces\IXExitManager.mqh"
#include "..\01_Core\Macros\CXMacros.mqh"
#include <Arrays\ArrayString.mqh>
#include <Generic\HashMap.mqh>

/**
 * @class CXIntegrityGuard
 * @brief [v2.2] System-wide Dependency & Resource Integrity Auditor (Consolidated)
 */
class CXIntegrityGuard : public ICXIntegrityGuard {
private:
    CArrayString m_errors;
    string       m_report;

public:
    CXIntegrityGuard() {
        m_report = "";
    }

    virtual ~CXIntegrityGuard() {}

    /**
     * @brief Pre-flight Environment Audit (Files & Paths)
     */
    virtual bool AuditEnvironment(string scenarioFile) override {
        m_errors.Clear();
        m_report = "--- AGS Environmental Audit Report ---\n";
        
        if(scenarioFile == "") {
            AddError("Target file path is empty.");
            GenerateReport(false);
            return false;
        }

        int len = StringLen(scenarioFile);
        string ext4 = (len >= 4) ? StringSubstr(scenarioFile, len - 4) : "";
        string ext3 = (len >= 3) ? StringSubstr(scenarioFile, len - 3) : "";

        if(ext4 != ".tsd" && ext3 != ".db") {
            AddError(StringFormat("Invalid file extension. Expected '.tsd' or '.db'. File: '%s'", scenarioFile));
            GenerateReport(false);
            return false;
        }

        if(ext4 == ".tsd") {
            if(!FileIsExist(scenarioFile, 0) && !FileIsExist(scenarioFile, FILE_COMMON)) {
                AddError(StringFormat("Scenario file not found on disk (Sandbox or Common path): '%s'", scenarioFile));
                GenerateReport(false);
                return false;
            }
        }
        // [v2.2] Note: .db files are skipped for existence check as they are auto-created by CXDatabase::Open

        GenerateReport(true);
        return true;
    }

    /**
     * @brief Main Integrity Inspection (Consolidated DI & Assembly Audit)
     */
    virtual bool Inspect(ICXContext* globalCtx, ICXSequenceOrchestrator* orchestrator) override {
        m_errors.Clear();
        m_report = "--- AGS Assembly Integrity Report ---\n";
        
        Print("==================================================");
        Print("Starting Dependency Injection Verification...");
        Print("==================================================");

        bool success = true;

        // 1. Service Registry Audit
        if(!AuditServices(globalCtx)) success = false;

        // 2. Structural Binding Test (PVB)
        if(!AuditOrchestrator(globalCtx, orchestrator)) success = false;

        // 3. Ownership Conflict Scan
        if(!AuditOwnership(globalCtx)) success = false;

        // 4. Singleton Resource (SSOT) Audit
        if(!AuditResources(globalCtx)) success = false;

        Print("==================================================");
        if(success) {
            Print("Dependency Injection Verification SUCCESS.");
        } else {
            Print("[EXEC-ENTRY-FAIL] Dependency Injection Verification FAILED.");
        }
        Print("==================================================");

        GenerateReport(success);
        return success;
    }

    virtual string GetDetailedReport() const override {
        return m_report;
    }

private:
    bool AuditServices(ICXContext* ctx) {
        if(IS_INVALID(ctx)) {
            AddError("GlobalContext is NULL.");
            return false;
        }

        string requirements[] = {
            "config", "logger", "orchestrator", "guard", 
            "db", "repo", "asset_mgr", "price_mgr", 
            "sym_mgr", "risk_mgr", "exit_mgr", "terminal_platform",
            "order_mgr", "pos_mgr"
        };

        bool allPresent = true;
        for(int i = 0; i < ArraySize(requirements); i++) {
            if(IS_INVALID(ctx.Get(requirements[i]))) {
                string msg = StringFormat("Missing Core Service: '%s'", requirements[i]);
                AddError(msg);
                PrintFormat("  [FAIL] %s", msg);
                allPresent = false;
            } else {
                PrintFormat("  [PASS] Service '%s' is registered and valid.", requirements[i]);
            }
        }
        return allPresent;
    }

    bool AuditOrchestrator(ICXContext* ctx, ICXSequenceOrchestrator* orchestrator) {
        if(IS_INVALID(orchestrator)) {
            AddError("Orchestrator is NULL.");
            Print("  [FAIL] Orchestrator is missing in context.");
            return false;
        }

        if(!orchestrator.Bind(ctx)) {
            AddError("Orchestrator Structural Binding Failed (Recursive Check).");
            Print("  [FAIL] Sequence/Task Pre-Validated Binding (PVB) failed.");
            return false;
        }
        Print("  [PASS] Sequence/Task Pre-Validated Binding (PVB) success.");
        return true;
    }

    bool AuditOwnership(ICXContext* ctx) {
        if(IS_INVALID(ctx)) return false;

        string keys[];
        int total = ctx.GetKeys(keys);
        CHashMap<CObject*, string> managedObjects;
        bool passed = true;

        for(int i = 0; i < total; i++) {
            CObject* obj = ctx.Get(keys[i]);
            if(obj == NULL) continue;
            
            if(ctx.IsManaged(keys[i])) {
                if(managedObjects.ContainsKey(obj)) {
                    string otherKey = "";
                    managedObjects.TryGetValue(obj, otherKey);
                    string err = StringFormat("[Ownership Conflict] Object is double-managed by keys '%s' and '%s'.", otherKey, keys[i]);
                    AddError(err);
                    PrintFormat("  [FAIL] %s", err);
                    passed = false;
                } else {
                    managedObjects.Add(obj, keys[i]);
                }
            }
        }
        if(passed) Print("  [PASS] Resource Ownership Integrity verified.");
        managedObjects.Clear();
        return passed;
    }

    bool AuditResources(ICXContext* ctx) {
        if(IS_INVALID(ctx)) return false;

        string keys[];
        int total = ctx.GetKeys(keys);
        
        IDatabase* firstDb = NULL;
        string firstDbKey = "";
        bool passed = true;

        for(int i = 0; i < total; i++) {
            CObject* obj = ctx.Get(keys[i]);
            if(obj == NULL) continue;

            IDatabase* dbCheck = dynamic_cast<IDatabase*>(obj);
            if(dbCheck != NULL) {
                if(firstDb == NULL) {
                    firstDb = dbCheck;
                    firstDbKey = keys[i];
                } else if(GetPointer(firstDb) != GetPointer(dbCheck)) {
                    string err = StringFormat("[SSOT Conflict] Duplicate Database instances: '%s' and '%s'.", firstDbKey, keys[i]);
                    AddError(err);
                    PrintFormat("  [FAIL] %s", err);
                    passed = false;
                }
            }
        }
        if(passed) Print("  [PASS] Singleton Resource (SSOT) integrity verified.");
        return passed;
    }

    void AddError(string msg) {
        m_errors.Add(msg);
    }

    void GenerateReport(bool success) {
        m_report += StringFormat("Status: %s\n", success ? "PASS" : "FAIL");
        m_report += StringFormat("Errors Found: %d\n", m_errors.Total());
        for(int i = 0; i < m_errors.Total(); i++) {
            m_report += StringFormat("[%d] %s\n", i + 1, m_errors.At(i));
        }
        m_report += "-------------------------------------";
    }
};

#endif
