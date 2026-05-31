#ifndef CXRISKEVALUATOR_MQH
#define CXRISKEVALUATOR_MQH

#include <Object.mqh>
#include "..\..\..\01_Core\Interfaces\ICXParam.mqh"
#include "..\..\..\01_Core\Interfaces\ICXContext.mqh"
#include "..\..\..\01_Core\Interfaces\IXTerminalPlatform.mqh"
#include "..\..\..\01_Core\Macros\CXMacros.mqh"
#include "..\..\..\01_Core\Logger\CXAuditFormatter.mqh"

/**
 * @class CXRiskEvaluator
 * @brief [v1.0] 계좌 리스크 및 증거금 가용성 판별 전담 클래스 (Subdivision Phase 1)
 */
class CXRiskEvaluator : public CObject {
public:
    /**
     * @brief 가용 증거금 확인 (Pure Calculation based on platform input)
     */
    static bool IsMarginSufficient(ICXParam* xp, ICXContext* ctx, double requiredMargin) {
        IXTerminalPlatform* terminal = CX_GET_OBJ(ctx, "terminal_platform", IXTerminalPlatform);
        double freeMargin = IS_VALID(terminal) ? terminal.GetAccountFreeMargin() : AccountInfoDouble(ACCOUNT_MARGIN_FREE);

        if(freeMargin < requiredMargin) {
            XP_LOG_ERROR(xp, CXAuditFormatter::Build("RISK-NO-MONEY", xp, StringFormat("Free:%.2f, Req:%.2f", freeMargin, requiredMargin)));
            return false;
        }
        return true;
    }

    /**
     * @brief 글로벌 로트 캡(Lot Ceiling) 검증
     */
    static bool IsLotWithinGlobalLimit(ICXParam* xp, double lot) {
        if(lot <= 0 || lot > 50.0) {
            XP_LOG_ERROR(xp, CXAuditFormatter::Build("RISK-LOT-CEILING-VIOLATION", xp, StringFormat("Lot:%.2f forbidden (0 < Lot <= 50)", lot)));
            return false;
        }
        return true;
    }
};

#endif
