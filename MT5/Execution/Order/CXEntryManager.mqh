#ifndef CXENTRYMANAGER_MQH
#define CXENTRYMANAGER_MQH

#include "..\..\Platform\Core\Interfaces\IXEntryManager.mqh"
#include "..\..\Platform\Core\Interfaces\ICXContext.mqh"
#include "..\..\Platform\Core\Interfaces\ICXParam.mqh"
#include "..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\Platform\Core\Interfaces\IXGuard.mqh"
#include "..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"

#include "..\..\Platform\Core\Interfaces\IXTerminalPlatform.mqh"
#include "..\..\Platform\Core\Interfaces\IRepository.mqh"
#include "..\..\Platform\Shared\Logging\CXMessageProvider.mqh"

/**
 * @class CXEntryManager
 * @brief 진입 로직 전반을 총괄하는 도메인 서비스 (v18.8 Gatekeeper Logic)
 */
class CXEntryManager : public IXEntryManager {
private:
    ICXContext*         m_ctx;

public:
    CXEntryManager(ICXContext* ctx) : m_ctx(ctx) {}
    virtual ~CXEntryManager() override {}

    /**
     * @brief [v18.8] Proactive Terminal Integrity Check & Binding
     * @return 전이 코드 (0:정상 진행, SESSION_PENDING:바인딩 성공/건너뛰기)
     */
    int ValidateTerminalIntegrity(ICXParam* xp) {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return -1;

        string sid = sig.GetSid(); StringTrimLeft(sid); StringTrimRight(sid);
        ulong magic = sig.GetMagic();

        // 1. [Proliferation Guard] Before any calculation, check if terminal already has this SID
        IXTerminalPlatform* terminal = CX_GET_OBJ(m_ctx, "terminal_platform", IXTerminalPlatform);
        if(IS_VALID(terminal)) {
            ulong existingTicket = terminal.GetTicketBySid(magic, sid);
            if(existingTicket > 0) {
                // 이미 자산이 존재함 -> 즉시 바인딩 및 시퀀스 점프 지시
                XP_LOG_OK(xp, CXAuditFormatter::Build("ENTRY-BIND", xp, StringFormat("PROACTIVE-GUARD: Asset %I64u already exists. Binding and skipping execution.", existingTicket)));
                
                sig.SetTicket(existingTicket);
                CXMessageProvider::UpdateStatus(sig, XE_IN_TRANSIT, "Bound to existing asset: " + (string)existingTicket);
                
                IRepository* repo = CX_GET_OBJ(m_ctx, "repo", IRepository);
                if(IS_VALID(repo)) repo.UpdateStatus(sig);
                
                return SESSION_PENDING; // Fast-track to monitoring phase
            }
        }
        return 0; // No asset found, proceed normally
    }

    /**
     * @brief 진입 전 파라미터 최적화 및 검증
     */
    virtual void Pulse(ICXParam* xp) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return;

        // 1. [v11.8] Identity Validation (Double-check)
        IXGuard* guard = CX_GET_OBJ(m_ctx, "guard", IXGuard);
        if(IS_VALID(guard)) {
            if(!guard.ValidateSID(sig.GetSid())) {
                XP_LOG_ERROR(xp, CXAuditFormatter::Build("ENTRY-GUARD-BLOCK", xp, guard.GetLastError()));
                return;
            }
        }

        // 진입 전략 설정 조정 로직
        XP_LOG_INFO(xp, CXAuditFormatter::Build("SANDBOX-ENTRY", xp));
    }
};

#endif
