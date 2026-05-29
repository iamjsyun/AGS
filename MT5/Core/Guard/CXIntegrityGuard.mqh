#ifndef CXINTEGRITYGUARD_MQH
#define CXINTEGRITYGUARD_MQH

#include "..\Interfaces\ICXIntegrityGuard.mqh"
#include "..\Interfaces\ICXConfig.mqh"
#include "..\Interfaces\IDatabase.mqh"
#include "..\Interfaces\IRepository.mqh"
#include "..\Interfaces\ICXAssetManager.mqh"
#include "..\Interfaces\ICXPriceManager.mqh"
#include "..\Interfaces\ICXSymbolManager.mqh"
#include "..\Interfaces\ICXRiskManager.mqh"
#include "..\Interfaces\IXTerminalPlatform.mqh"
#include "..\Interfaces\IXExitManager.mqh"
#include "..\Macros\CXMacros.mqh"
#include <Arrays\ArrayString.mqh>
#include <Generic\HashMap.mqh>

/**
 * @class CXIntegrityGuard
 * @brief [v2.2] 시스템 전역 의존성, 소유권 이중 해제, 자원 단일성(SSOT) 및 환경을 정밀 진단하는 독립 검사기
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
     * @brief 기동 전 환경(파일 및 확장자) 선제 검증
     */
    virtual bool AuditEnvironment(string scenarioFile) override {
        m_errors.Clear();
        m_report = "--- AGS Environmental Audit Report ---\n";
        
        if(scenarioFile == "") {
            AddError("Target file path is empty.");
            GenerateReport(false);
            return false;
        }

        // 1. 확장자 검사 (.tsd, .db 허용)
        int len = StringLen(scenarioFile);
        string ext4 = "";
        if(len >= 4) ext4 = StringSubstr(scenarioFile, len - 4);
        string ext3 = "";
        if(len >= 3) ext3 = StringSubstr(scenarioFile, len - 3);

        if(ext4 != ".tsd" && ext3 != ".db") {
            AddError(StringFormat("Invalid file extension. Expected '.tsd' or '.db'. File: '%s'", scenarioFile));
            GenerateReport(false);
            return false;
        }

        // 2. 물리적 존재성 확인 (MQL5 샌드박스 및 공용 폴더 모두 검색)
        if(!FileIsExist(scenarioFile, 0) && !FileIsExist(scenarioFile, FILE_COMMON)) {
            AddError(StringFormat("File not found on disk (Sandbox or Common path): '%s'", scenarioFile));
            GenerateReport(false);
            return false;
        }

        GenerateReport(true);
        return true;
    }

    /**
     * @brief 시스템 조립 상태 전수 검사
     */
    virtual bool Inspect(ICXContext* globalCtx, ICXSequenceOrchestrator* orchestrator) override {
        m_errors.Clear();
        m_report = "--- AGS Assembly Integrity Report ---\n";
        
        bool success = true;

        // 1. Service Registry Audit (필수 전역 서비스 검증)
        if(!AuditServices(globalCtx)) success = false;

        // 2. Structural Binding Test (시퀀스 및 태스크 검증)
        if(!AuditOrchestrator(globalCtx, orchestrator)) success = false;

        // 3. Ownership Conflict Scan (이중 해제 위험 검증)
        if(!AuditOwnership(globalCtx)) success = false;

        // 4. Singleton Resource (SSOT) Audit (중복 DB 생성 등 검증)
        if(!AuditResources(globalCtx)) success = false;

        // 리포트 생성
        GenerateReport(success);
        return success;
    }

    virtual string GetDetailedReport() const override {
        return m_report;
    }

private:
    /**
     * @brief 전역 서비스 등록 상태 확인
     */
    bool AuditServices(ICXContext* ctx) {
        if(IS_INVALID(ctx)) {
            AddError("GlobalContext is NULL.");
            return false;
        }

        string requirements[] = {
            "config", "logger", "orchestrator", "guard", 
            "db", "repo", "asset_mgr", "price_mgr", 
            "sym_mgr", "risk_mgr", "exit_mgr", "terminal_platform"
        };

        bool allPresent = true;
        for(int i = 0; i < ArraySize(requirements); i++) {
            if(IS_INVALID(ctx.Get(requirements[i]))) {
                AddError(StringFormat("Missing Core Service: '%s'", requirements[i]));
                allPresent = false;
            }
        }
        return allPresent;
    }

    /**
     * @brief 오케스트레이터 구조 및 바인딩 확인
     */
    bool AuditOrchestrator(ICXContext* ctx, ICXSequenceOrchestrator* orchestrator) {
        if(IS_INVALID(orchestrator)) {
            AddError("Orchestrator is NULL.");
            return false;
        }

        // Orchestrator의 Bind()는 내부의 모든 시퀀스와 태스크를 재귀적으로 Bind 시도함
        if(!orchestrator.Bind(ctx)) {
            AddError("Orchestrator Structural Binding Failed (Recursive Check).");
            return false;
        }
        return true;
    }

    /**
     * @brief [v2.2] 포인터 이중 해제(Double Free) 위험 사전 스캔
     */
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
                    AddError(StringFormat("[Ownership Conflict] Object is double-managed by keys '%s' and '%s'. Possible double-free crash.", 
                                          otherKey, keys[i]));
                    passed = false;
                } else {
                    managedObjects.Add(obj, keys[i]);
                }
            }
        }
        managedObjects.Clear();
        return passed;
    }

    /**
     * @brief [v2.2] 자원 단일성(SSOT) 및 중복 할당 검사
     */
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

            // dynamic_cast로 IDatabase 구현체 추출
            IDatabase* dbCheck = dynamic_cast<IDatabase*>(obj);
            if(dbCheck != NULL) {
                if(firstDb == NULL) {
                    firstDb = dbCheck;
                    firstDbKey = keys[i];
                } else if(GetPointer(firstDb) != GetPointer(dbCheck)) {
                    AddError(StringFormat("[SSOT Conflict] Duplicate Database instances detected: '%s' and '%s'. Potential lock conflict and leaks.", 
                                          firstDbKey, keys[i]));
                    passed = false;
                }
            }
        }
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
