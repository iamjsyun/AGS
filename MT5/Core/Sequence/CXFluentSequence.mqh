#ifndef CXFLUENTSEQUENCE_MQH
#define CXFLUENTSEQUENCE_MQH

#include "..\Interfaces\ICXFluentSequence.mqh"
#include "..\Interfaces\IXStage.mqh"
#include "..\Interfaces\IXGuard.mqh"
#include "..\Defines\CXDefine.mqh"
#include "..\Macros\CXMacros.mqh"
#include <Generic\HashMap.mqh>

/**
 * @class CXStageNode
 * @brief 시퀀스 노드 데이터 관리용 (Infra 전용)
 */
class CXStageNode : public CObject {
public:
    IXStage*            stage;
    IXGuard*            guard; 
    int                 if_true;
    int                 if_false;
    int                 timeout_sec;
    int                 max_retries;
    int                 current_retries;
    CHashMap<int, int>* branches;

    CXStageNode(IXStage* s, int t_path, int f_path, int timeout = 0, int retries = 0, IXGuard* g = NULL) 
        : stage(s), if_true(t_path), if_false(f_path), 
          timeout_sec(timeout), max_retries(retries), current_retries(0), guard(g) {
        branches = new CHashMap<int, int>();
        if(IS_INVALID(branches)) { /* Critical Error */ }
    }
          
    ~CXStageNode() { 
        SAFE_DELETE(stage); 
        SAFE_DELETE(guard); 
        SAFE_DELETE(branches);
    }
};

/**
 * @class CXFluentSequence
 * @brief ATSE 고도화 로직을 반영한 인터페이스 기반 시퀀스 엔진
 */
class CXFluentSequence : public ICXFluentSequence {
private:
    ICXContext*                  m_ctx;
    int                          m_current_state;
    datetime                     m_state_entered;
    CHashMap<int, CXStageNode*>* m_map;
    string                       m_name;
    int                          m_first_state;
    
    // Log Suppression
    int                          m_last_log_from;
    int                          m_last_log_to;

    // Builder State
    int                          m_tmp_from;
    IXStage*                     m_tmp_stage;
    IXGuard*                     m_tmp_guard;
    int                          m_tmp_success;
    int                          m_tmp_fail;
    int                          m_tmp_timeout;
    int                          m_tmp_retries;
    CHashMap<int, int>*          m_tmp_branches;

public:
    CXFluentSequence(ICXContext* ctx, string name) 
        : m_ctx(ctx), m_name(name), m_current_state(-1), m_tmp_from(-1), m_first_state(-1),
          m_tmp_stage(NULL), m_tmp_guard(NULL), m_tmp_success(-1), m_tmp_fail(-1),
          m_tmp_timeout(0), m_tmp_retries(0), m_last_log_from(-1), m_last_log_to(-1) {
        m_map = new CHashMap<int, CXStageNode*>();
        m_tmp_branches = new CHashMap<int, int>();
        if(IS_VALID(m_tmp_branches)) {
            m_state_entered = TimeCurrent();
        }
    }
    
    ~CXFluentSequence() {
        int keys[];
        CXStageNode* values[];
        m_map.CopyTo(keys, values);
        for(int i = 0; i < ArraySize(values); i++) if(IS_VALID(values[i])) SAFE_DELETE(values[i]);
        m_map.Clear();
        SAFE_DELETE(m_map);
        SAFE_DELETE(m_tmp_branches);
    }

    //-- Fluent API
    CXFluentSequence* From(int state) { 
        CommitCurrent(); 
        m_tmp_from = state; 
        if(m_first_state == -1) m_first_state = state; 
        return GetPointer(this); 
    }
    CXFluentSequence* Execute(IXStage* stage) { m_tmp_stage = stage; return GetPointer(this); }
    CXFluentSequence* Guard(IXGuard* guard) { m_tmp_guard = guard; return GetPointer(this); }
    CXFluentSequence* OnSuccess(int next) { m_tmp_success = next; return GetPointer(this); }
    CXFluentSequence* OnFail(int next) { m_tmp_fail = next; return GetPointer(this); }
    CXFluentSequence* Timeout(int sec) { m_tmp_timeout = sec; return GetPointer(this); }
    CXFluentSequence* Retries(int count) { m_tmp_retries = count; return GetPointer(this); }
    CXFluentSequence* Case(int code, int state) { m_tmp_branches.Add(code, state); return GetPointer(this); }

    virtual void Build() override {
        CommitCurrent();
        if(m_current_state == -1) {
            m_current_state = m_first_state;
            XP_LOG_SEQ_INFO(m_ctx.GetParam(), StringFormat("[SEQ:%s] Sequence Started at State: %d", m_name, m_current_state));
        }
        TriggerOnEnter(m_current_state);
    }

    virtual bool Bind() override {
        if(IS_INVALID(m_ctx)) return false;
        int keys[];
        CXStageNode* values[];
        m_map.CopyTo(keys, values);
        bool success = true;
        for(int i = 0; i < ArraySize(values); i++) {
            if(IS_VALID(values[i])) {
                if(!values[i].stage.Bind(m_ctx)) {
                    PrintFormat("[FATAL] Sequence Bind Failed in '%s': State ID %d, Stage '%s'", m_name, keys[i], values[i].stage.Name());
                    success = false;
                }
            }
        }
        return success;
    }

    virtual void ResetState() override {
        m_current_state = m_first_state;
        m_state_entered = TimeCurrent();
    }

    virtual void Pulse(ICXParam* xp) override {
        if(m_current_state == -1) return;

        // [v18.15 Immediate Transition Loop]
        // 전이 발생 시 대기 없이 즉시 새로운 상태의 태스크를 실행 (최대 3회 전이까지 허용하여 무한루프 방지)
        for(int loop = 0; loop < 3; loop++) {
            CXStageNode* node = NULL;
            if(!m_map.TryGetValue(m_current_state, node) || IS_INVALID(node)) return;

            if(IS_VALID(node.guard) && !node.guard.Check(xp, m_ctx)) return;

            if(node.timeout_sec > 0 && (TimeCurrent() - m_state_entered > node.timeout_sec)) {
                int next = (node.if_false != -1) ? node.if_false : SYS_ERROR;
                XP_LOG_SEQ_WARN(xp, StringFormat("[SEQ:%s] State %d Timeout (%d sec). Moving to %d", m_name, m_current_state, node.timeout_sec, next));
                UpdateState(next);
                continue; 
            }

            if(node.stage.OnCondition(xp, m_ctx, m_current_state)) {
                int next_state = node.stage.OnProcess(xp, m_ctx);
                
                // [v18.8] Map STAGE_SUCCESS to DSL's ? (if_true) path
                if (next_state == STAGE_SUCCESS) {
                    next_state = node.if_true;
                }

                if(next_state == m_current_state || next_state == -1) {
                    return; // 현재 상태 유지 또는 Yield 시 루프 종료
                }

                if(next_state == node.if_false && node.max_retries > 0) {
                    node.current_retries++;
                    if(node.current_retries <= node.max_retries) {
                        XP_LOG_SEQ_WARN(xp, StringFormat("[SEQ:%s] Stage '%s' failed. Retry %d/%d...", 
                            m_name, node.stage.Name(), node.current_retries, node.max_retries));
                        return;
                    } else {
                        XP_LOG_SEQ_ERROR(xp, StringFormat("[SEQ:%s] Stage '%s' exhausted retries. Moving to terminal fail state %d.", 
                            m_name, node.stage.Name(), node.if_false));
                        node.current_retries = 0;
                        UpdateState(node.if_false);
                        continue;
                    }
                }

                int branch_state = -1;
                if(node.branches.TryGetValue(next_state, branch_state)) {
                    node.current_retries = 0;
                    UpdateState(branch_state);
                    continue; // 새로운 상태로 즉시 루프 재시작
                }

                if(next_state != m_current_state && next_state != -1) {
                    node.current_retries = 0;
                    UpdateState(next_state);
                    continue; // 새로운 상태로 즉시 루프 재시작
                }
            }
            break; // 조건 미충족 시 루프 종료
        }
    }

    virtual void AddStage(int state_id, IXStage* stage) override {
        CXStageNode* node = new CXStageNode(stage, -1, -1);
        if(IS_VALID(node)) m_map.Add(state_id, node);
    }

    virtual int State() const override { return m_current_state; }
    virtual void ForceState(int state) override { UpdateState(state); }

    string GetSequenceName() const { return m_name; }
    int    GetNodeCount() { return m_map.Count(); }
    string GetStateSummary() {
        int keys[]; CXStageNode* values[];
        m_map.CopyTo(keys, values);
        string summary = "";
        for(int i=0; i<ArraySize(keys); i++) {
            string stateName = (string)keys[i];
            if(m_name == "SessionSeq") stateName = EnumToString((ENUM_SESSION_STATE)keys[i]);
            else if(m_name == "WatcherSeq") stateName = EnumToString((ENUM_WATCHER_STATE)keys[i]);
            summary += (summary == "" ? "" : ", ") + StringFormat("%d:%s", keys[i], stateName);
        }
        return summary;
    }

private:
    void CommitCurrent() {
        if(m_tmp_from == -1 || IS_INVALID(m_tmp_stage)) return;
        CXStageNode* node = new CXStageNode(m_tmp_stage, m_tmp_success, m_tmp_fail, m_tmp_timeout, m_tmp_retries, m_tmp_guard);
        if(IS_INVALID(node)) return;
        
        int b_keys[]; int b_values[];
        m_tmp_branches.CopyTo(b_keys, b_values);
        for(int i = 0; i < ArraySize(b_keys); i++) node.branches.Add(b_keys[i], b_values[i]);
        m_tmp_branches.Clear();

        m_map.Add(m_tmp_from, node);
        m_tmp_from = -1; m_tmp_stage = NULL; m_tmp_guard = NULL; m_tmp_success = -1; m_tmp_fail = -1;
    }

    void UpdateState(int next) {
        if(m_current_state == next) return;
        if(!ValidateTransition(m_current_state, next)) {
            string illegalErr = StringFormat("[SEQ:%s] CRITICAL: Illegal Transition Blocked (%d -> %d)", m_name, m_current_state, next);
            XP_LOG_SEQ_ERROR(m_ctx.GetParam(), illegalErr);
            ICXParam* xp = m_ctx.GetParam();
            if(IS_VALID(xp)) xp.SetString(illegalErr);
            return;
        }

        // [v14.13 Fix] Ensure error message is set when moving to terminal error state
        if(next == SYS_ERROR || next == 99) {
            ICXParam* xp = m_ctx.GetParam();
            if(IS_VALID(xp) && xp.GetString() == "") {
                xp.SetString(StringFormat("[%s] Sequence reached terminal ERROR state from %d", m_name, m_current_state));
            }
        }

        TriggerOnExit(m_current_state);
        m_current_state = next;
        m_state_entered = TimeCurrent();
        TriggerOnEnter(m_current_state);
    }

    bool ValidateTransition(int from, int to) {
        if(to == SYS_ERROR || to == 99) return true;
        if(from == -1 || from == to) return true;
        if(m_name != "SessionSeq") return true;

        // 이미 종료된 세션에서의 전이는 원칙적 차단 (에러 제외)
        if(from == SYS_CLOSED || from == SYS_ERROR) return false;

        return true; 
    }

    void TriggerOnEnter(int state) {
        CXStageNode* node = NULL;
        if(m_map.TryGetValue(state, node) && IS_VALID(node)) node.stage.OnEnter(m_ctx);
    }

    void TriggerOnExit(int state) {
        CXStageNode* node = NULL;
        if(m_map.TryGetValue(state, node) && IS_VALID(node)) node.stage.OnExit(m_ctx);
    }
};

#endif
