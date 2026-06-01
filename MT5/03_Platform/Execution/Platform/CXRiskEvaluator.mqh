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
 * @brief [v1.0] Class dedicated to determining account risk and margin availability (Subdivision Phase 1)
 */
class CXRiskEvaluator : public CObject {
public:
    /**
     * @brief Verify free margin (Pure Calculation based on platform input)
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
     * @brief Verify global lot ceiling
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
