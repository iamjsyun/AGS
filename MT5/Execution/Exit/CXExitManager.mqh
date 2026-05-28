#ifndef CXEXITMANAGER_MQH
#define CXEXITMANAGER_MQH

#include "..\..\Platform\Core\Interfaces\IXExitManager.mqh"
#include "..\..\Platform\Core\Interfaces\ICXContext.mqh"
#include "..\..\Platform\Core\Interfaces\ICXParam.mqh"
#include "..\..\Platform\Core\Defines\CXDefine.mqh"
#include "..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\Platform\Shared\Logging\CXAuditFormatter.mqh"
#include "..\..\Platform\Core\Interfaces\IXTerminalPlatform.mqh"

/**
 * @class CXExitManager
 * @brief 샌드박스 세션 내의 청산 및 주문 취소 담당 (3-Layer Guard)
 */
class CXExitManager : public IXExitManager {
private:
    ulong               m_magic;
    ICXContext*         m_ctx;
    IXTerminalPlatform* m_terminal;

public:
    CXExitManager(ICXContext* ctx) : m_ctx(ctx), m_magic(0) {
        m_terminal = CX_GET_OBJ(m_ctx, "terminal_platform", IXTerminalPlatform);
    }
    virtual ~CXExitManager() override {}

    virtual void SetMagic(ulong magic) override { m_magic = magic; m_terminal.SetMagic(magic); }

    virtual bool ExecuteExit(ICXParam* xp) override {
        ICXSignal* sig = xp.GetSignal();
        if(IS_INVALID(sig)) return false;
        
        // [v1.0 Scenario E] SID-based Sweep for Partial Fill protection
        // Ensure magic is set for the sweep operation
        SetMagic(sig.GetMagic());
        return SweepBySid(xp, sig.GetSid());
    }

    /**
     * @brief Layer 1: 티켓 기반 정밀 청산 및 사후 검증
     */
    virtual bool CloseByTicket(ICXParam* xp, ICXSignal* sig) override {
        if(IS_INVALID(sig) || IS_INVALID(m_terminal)) return false;
        ulong ticket = (ulong)sig.GetTicket();
        string sid = sig.GetSid();
        if(ticket <= 0) return true;
        
        bool res = false;
        if(m_terminal.IsPositionExists(ticket)) {
            // [v14.0 Strict SID/Ticket Verification]
            string posComment = m_terminal.GetPositionComment(ticket);
            if(posComment != sid) {
                string mismatchErr = StringFormat("SID Mismatch. Ticket:%I64u belongs to %s, not %s", 
                                              ticket, posComment, sid);
                XP_LOG_ERROR(xp, CXAuditFormatter::Build("POS-CLOSE-ABORT", xp, mismatchErr));
                return false;
            }

            // [v11.10] Pre-Call Raw Parameter Audit
            string rawParams = StringFormat("Raw: [Ticket:%I64u, SID:%s]", ticket, sid);
            XP_LOG_INFO(xp, CXAuditFormatter::Build("AUDIT-CALL:PositionClose", xp, rawParams));
            
            if(m_terminal.PositionClose(xp, ticket)) {
                // 재확인: 포지션 소멸 확인
                if(!m_terminal.IsPositionExists(ticket)) {
                    XP_LOG_OK(xp, CXAuditFormatter::Build("POS-CLOSE-SUCCESS", xp, StringFormat("Ticket %I64u Closed.", ticket)));
                    res = true;
                }
            }
            
            if(!res) {
                string retMsg = m_terminal.GetLastRetCodeDescription();
                uint retCode = m_terminal.GetLastRetCode();
                int sysErr = GetLastError();
                string err_msg = StringFormat("Broker Code:%u(%s), SysErr:%d. Ticket:%I64u", 
                                                retCode, retMsg, sysErr, ticket);
                XP_LOG_ERROR(xp, CXAuditFormatter::Build("POS-CLOSE-FAIL", xp, err_msg));
                if(IS_VALID(xp)) xp.SetString("[POS-CLOSE-FAIL] " + err_msg);
                ResetLastError();
            }
        }
        else if(m_terminal.IsOrderExists(ticket)) {
            // [v14.0 Strict SID/Ticket Verification]
            string ordComment = m_terminal.GetOrderComment(ticket);
            if(ordComment != sid) {
                string mismatchErr = StringFormat("SID Mismatch. Ticket:%I64u belongs to %s, not %s", 
                                              ticket, ordComment, sid);
                XP_LOG_ERROR(xp, CXAuditFormatter::Build("ORDER-DELETE-ABORT", xp, mismatchErr));
                return false;
            }

            // [v11.10] Pre-Call Raw Parameter Audit
            string rawParams = StringFormat("Raw: [Ticket:%I64u, SID:%s]", ticket, sid);
            XP_LOG_INFO(xp, CXAuditFormatter::Build("AUDIT-CALL:OrderDelete", xp, rawParams));

            if(m_terminal.OrderDelete(xp, ticket)) {
                // 재확인: 주문 소멸 확인
                if(!m_terminal.IsOrderExists(ticket)) {
                    XP_LOG_OK(xp, CXAuditFormatter::Build("ORDER-DELETE-SUCCESS", xp, StringFormat("Ticket %I64u Deleted.", ticket)));
                    res = true;
                }
            }
            
            if(!res) {
                string retMsg = m_terminal.GetLastRetCodeDescription();
                uint retCode = m_terminal.GetLastRetCode();
                int sysErr = GetLastError();
                string err_msg = StringFormat("Broker Code:%u(%s), SysErr:%d. Ticket:%I64u", 
                                                retCode, retMsg, sysErr, ticket);
                XP_LOG_ERROR(xp, CXAuditFormatter::Build("ORDER-DELETE-FAIL", xp, err_msg));
                if(IS_VALID(xp)) xp.SetString("[ORDER-DELETE-FAIL] " + err_msg);
                ResetLastError();
            }
        }
        else {
            return true; // 티켓을 찾을 수 없는 경우(이미 소멸) 성공
        }
        
        return res;
    }

    virtual bool SweepBySid(ICXParam* xp, string sid) override {
        return m_terminal.SweepBySid(xp, m_magic, sid);
    }

    virtual bool SweepByMagic(ICXParam* xp, ulong magic) override {
        return m_terminal.SweepByMagic(xp, magic);
    }

    virtual bool VerifyPhysicalAbsence(string sid) override {
        return m_terminal.VerifyPhysicalAbsence(m_magic, sid);
    }
};

#endif



