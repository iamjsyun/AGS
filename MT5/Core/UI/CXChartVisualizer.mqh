#ifndef CXCHARTVISUALIZER_MQH
#define CXCHARTVISUALIZER_MQH

#include "..\Interfaces\ICXSignal.mqh"
#include "..\Interfaces\ICXParam.mqh"
#include "..\Interfaces\ICXContext.mqh"
#include "..\Models\CXParam.mqh"
#include "..\Macros\CXMacros.mqh"

/**
 * @class CXChartVisualizer
 * @brief [v16.20] 트레이딩 트리거 라인 시각화 유틸리티 (v18.37 Native API Integration)
 */
class CXChartVisualizer {
private:
    /**
     * @brief 터미널에 열려있는 차트 중 심볼이 일치하는 차트 ID 반환
     */
    static long GetTargetChartId(string symbol) {
        long currChart = ChartFirst();
        while(currChart >= 0) {
            if(ChartSymbol(currChart) == symbol) return currChart;
            currChart = ChartNext(currChart);
        }
        return 0; // 일치하는 차트가 없으면 현재 EA가 부착된 기본 차트(0) 사용
    }

public:
    /**
     * @brief TE Start 트리거 라인 드로잉
     * @param ctx 실행 컨텍스트 (로거 참조용)
     * @param sig 대상 신호
     * @param triggerPrice 계산된 트리거 가격
     * @param caller 호출자 식별 문자열 (디버깅용)
     */
    static void DrawTEStart(ICXContext* ctx, ICXSignal* sig, double triggerPrice, string caller = "Unknown") {
        if(IS_INVALID(sig) || IS_INVALID(ctx)) return;

        string sid = sig.GetSid();
        string name = "TE_START_" + sid;
        string cacheKey = "VisCache_Price_" + sid;
        long chartId = GetTargetChartId(sig.GetSymbol());

        // [v18.35] Use global system logger for visualization events
        ICXLogger* log = CX_GET_OBJ(ctx, "global_logger", ICXLogger);
        if(IS_INVALID(log)) log = ctx.GetLogger();

        CXParam xp;
        xp.SetSignal(sig);
        xp.SetContext(ctx);
        ICXParam* pXp = GetPointer(xp);

        // [v18.40 Debug] 모든 호출을 기록 (호출자 명시)
        if(IS_VALID(log)) log.Trace(pXp, StringFormat("[VISUALIZER-CALL] DrawTEStart called by [%s]. SID=%s, Price=%.5f", caller, sid, triggerPrice));

        if(triggerPrice <= 0) {
            if(IS_VALID(log)) log.Trace(pXp, StringFormat("[VISUALIZER] DrawTEStart aborted: TriggerPrice <= 0 for SID=%s", sid));
            return;
        }

        // [v18.38 Optimization] Context 기반 상태 캐싱으로 중복 로깅 완벽 차단
        ICXParam* pCache = ctx.GetParam(cacheKey);
        if(IS_VALID(pCache)) {
            if(MathAbs(pCache.GetDouble() - triggerPrice) < 0.000001) return; // 이미 동일 가격으로 드로잉 시도함
        } else {
            pCache = new CXParam();
            ctx.Set(cacheKey, pCache);
        }
        pCache.SetDouble(triggerPrice);

        if(IS_VALID(log)) log.Trace(pXp, StringFormat("[VISUALIZER] Drawing TE_START: SID=%s, Price=%.5f, ChartID=%I64d", sid, triggerPrice, chartId));

        // [v18.37 Fix] Native MQL5 API with Dynamic Chart Routing
        int findCode = ObjectFind(chartId, name);
        bool res = false;
        if(findCode < 0) {
            res = ObjectCreate(chartId, name, OBJ_HLINE, 0, 0, triggerPrice);
            if(!res) {
                if(IS_VALID(log)) log.Error(pXp, StringFormat("[VISUALIZER-ERR] ObjectCreate failed. ChartID=%I64d, Name=%s, Error=%d", chartId, name, GetLastError()));
            }
        } else {
            res = ObjectMove(chartId, name, 0, 0, triggerPrice);
            if(!res) {
                if(IS_VALID(log)) log.Error(pXp, StringFormat("[VISUALIZER-ERR] ObjectMove failed. ChartID=%I64d, Name=%s, Error=%d", chartId, name, GetLastError()));
            }
        }

        if(res) {
            ObjectSetInteger(chartId, name, OBJPROP_COLOR, clrBlue); 
            ObjectSetInteger(chartId, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(chartId, name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetString(chartId, name, OBJPROP_TEXT, "TE Start (" + sid + ")");
            ObjectSetInteger(chartId, name, OBJPROP_HIDDEN, false); // [CRITICAL] false ensures it shows in the Object List (Ctrl+B)
            ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE, true); // [v18.41] Selectable to easily find in UI
            ObjectSetInteger(chartId, name, OBJPROP_BACK, false); // [v18.40] 차트 봉 앞에 표시

            ChartRedraw(chartId);
        }
    }

    /**
     * @brief 시각화 객체 제거 (세션 종료 시)
     */
    static void RemoveTEStart(ICXContext* ctx, ICXSignal* sig) {
        if(IS_INVALID(sig) || IS_INVALID(ctx)) return;
        
        string name = "TE_START_" + sig.GetSid();
        long chartId = GetTargetChartId(sig.GetSymbol());
        
        if(ObjectFind(chartId, name) < 0) return;

        ObjectDelete(chartId, name);
        
        ICXLogger* log = CX_GET_OBJ(ctx, "global_logger", ICXLogger);
        if(IS_INVALID(log)) log = ctx.GetLogger();
        
        if(IS_VALID(log)) {
            CXParam xp; xp.SetSignal(sig); xp.SetContext(ctx);
            log.Debug(GetPointer(xp), StringFormat("[VISUALIZER] RemoveTEStart: SID=%s", sig.GetSid()));
        }
        ChartRedraw(chartId);
    }
};

#endif
