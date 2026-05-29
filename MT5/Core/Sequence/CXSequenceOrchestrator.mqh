#ifndef CXSEQUENCEORCHESTRATOR_MQH
#define CXSEQUENCEORCHESTRATOR_MQH

#include <Arrays\ArrayObj.mqh>
#include <Generic\HashMap.mqh>
#include "..\Defines\CXDefine.mqh"
#include "..\Interfaces\ICXSequenceOrchestrator.mqh"
#include "CXSequenceRegistry.mqh"
#include "CXSequenceStage.mqh"

/**
 * @class CXSequenceOrchestrator
 * @brief [v16.7] 시퀀스 구성을 위한 기반 프레임워크 (추상 클래스 역할)
 */
class CXSequenceOrchestrator : public ICXSequenceOrchestrator {
protected:
    CArrayObj*             m_watcher_map;       // Entry Watcher Map
    CArrayObj*             m_watcher_exit_map;  // Exit Watcher Map
    CArrayObj*             m_session_map;
    CArrayObj*             m_system_map;        // [v19.32] Bootstrap-only Map (Watcher와 분리)
    CHashMap<string, int>* m_registry;
    int                    m_auto_id_counter;

public:
    CXSequenceOrchestrator() {
        m_watcher_map = new CArrayObj();
        m_watcher_exit_map = new CArrayObj();
        m_session_map = new CArrayObj();
        m_system_map = new CArrayObj();  // [v19.32]
        m_registry = new CHashMap<string, int>();
        m_auto_id_counter = 1000;
    }

    virtual ~CXSequenceOrchestrator() {
        SAFE_DELETE(m_watcher_map);
        SAFE_DELETE(m_watcher_exit_map);
        SAFE_DELETE(m_session_map);
        SAFE_DELETE(m_system_map);  // [v19.32]
        SAFE_DELETE(m_registry);
    }

    /**
     * @brief [v16.7] 오케스트레이터 초기화 (가상 함수 호출 패턴)
     */
    virtual void Initialize() {
        RegisterStandardNames();
        InitWatcherMap();
        InitSessionMap();
    }

    void BuildWatcherSequence(CXFluentSequence* seq) {
        CXSequenceRegistry::BuildSequence(seq, m_watcher_map);
    }

    void BuildWatcherEntrySequence(CXFluentSequence* seq) {
        CXSequenceRegistry::BuildSequence(seq, m_watcher_map);
    }

    void BuildWatcherExitSequence(CXFluentSequence* seq) {
        CXSequenceRegistry::BuildSequence(seq, m_watcher_exit_map);
    }

    void BuildSessionSequence(CXFluentSequence* seq) {
        CXSequenceRegistry::BuildSequence(seq, m_session_map);
    }

    virtual bool Bind(ICXContext* ctx) {
        if(IS_INVALID(ctx)) return false;
        
        bool success = true;
        
        // 1. Watcher Sequence 검증
        CXFluentSequence* watcherSeq = new CXFluentSequence(ctx, "TestWatcherSeq");
        if(IS_VALID(watcherSeq)) {
            BuildWatcherSequence(watcherSeq);
            if(!watcherSeq.Bind()) {
                Print("[FATAL] Watcher Sequence DI Binding Failed.");
                success = false;
            }
            delete watcherSeq;
        } else success = false;

        // 2. Watcher Exit Sequence 검증
        if(m_watcher_exit_map.Total() > 0) {
            CXFluentSequence* watcherExitSeq = new CXFluentSequence(ctx, "TestWatcherExitSeq");
            if(IS_VALID(watcherExitSeq)) {
                BuildWatcherExitSequence(watcherExitSeq);
                if(!watcherExitSeq.Bind()) {
                    Print("[FATAL] Watcher Exit Sequence DI Binding Failed.");
                    success = false;
                }
                delete watcherExitSeq;
            } else success = false;
        }

        // 3. Session Sequence 검증
        CXFluentSequence* sessionSeq = new CXFluentSequence(ctx, "TestSessionSeq");
        if(IS_VALID(sessionSeq)) {
            BuildSessionSequence(sessionSeq);
            if(!sessionSeq.Bind()) {
                Print("[FATAL] Session Sequence DI Binding Failed.");
                success = false;
            }
            delete sessionSeq;
        } else success = false;

        return success;
    }

    /**
     * @brief [v16.7] 명칭 기반 ID 확인 (Public Access)
     */
    int ResolveId(string value) {
        string val = Clean(value);
        if(val == "") return -1;
        if(IsDigit(val)) return (int)StringToInteger(val);
        int id;
        if(m_registry.TryGetValue(val, id)) return id;
        RegisterStateName(val);
        m_registry.TryGetValue(val, id);
        return id;
    }

    /**
     * @brief 시맨틱 기호 기반 DSL 파서 (Enum-less)
     */
    void BuildFromDSL(string &SEQS[], CArrayObj* map) {
        if(IS_INVALID(map)) return;

        for(int i = 0; i < ArraySize(SEQS); i++) {
            string nodeStr = SEQS[i];
            int firstDelim = FindFirstDelimiter(nodeStr);
            string idName = (firstDelim == -1) ? nodeStr : StringSubstr(nodeStr, 0, firstDelim);
            RegisterStateName(Clean(idName));
        }

        for(int i = 0; i < ArraySize(SEQS); i++) {
            string s = SEQS[i];
            int firstDelim = FindFirstDelimiter(s);
            string name = Clean(StringSubstr(s, 0, firstDelim));
            int id = ResolveId(name);
            
            // [v18.7] Support both '|' (Pipe) and '>' (Terminator)
            string delim = StringSubstr(s, firstDelim, 1);
            string logicPart = GetSegment(s, delim, "?!@*");
            string stageParts[];
            StringSplit(logicPart, StringGetCharacter(":", 0), stageParts);
            
            string typeStr = Clean(stageParts[0]);
            string alias   = "";
            string taskStr = "";
            if(ArraySize(stageParts) == 2) {
                // If only 1 colon is present, the second part represents the task list
                taskStr = Clean(stageParts[1]);
                alias = typeStr; // Default alias to the stage type
            } else if(ArraySize(stageParts) > 2) {
                // If 2 or more colons are present (v14.8 standard)
                alias = Clean(stageParts[1]);
                taskStr = Clean(stageParts[2]);
            }
            
            int next = ResolveId(GetSegment(s, "?", "|!@*"));
            int fail = ResolveId(GetSegment(s, "!", "|?@*"));
            
            string constStr = GetSegment(s, "@", "|?!*");
            string constParts[];
            StringSplit(constStr, StringGetCharacter(",", 0), constParts);
            int timeout = (ArraySize(constParts) > 0) ? ParseSuffixValue(constParts[0]) : 0;
            int retries = (ArraySize(constParts) > 1) ? ParseSuffixValue(constParts[1]) : 0;

            CXSequenceStage* node = new CXSequenceStage(id, typeStr, next, fail, timeout, retries, alias);
            
            string tasks[];
            if(StringSplit(taskStr, StringGetCharacter(",", 0), tasks) > 0) {
                for(int t = 0; t < ArraySize(tasks); t++) node.AddTask(Clean(tasks[t]));
            }
            
            string branchStr = GetSegment(s, "*", "|?!@");
            string cases[];
            if(StringSplit(branchStr, StringGetCharacter(",", 0), cases) > 0) {
                for(int c = 0; c < ArraySize(cases); c++) {
                    string kv[];
                    if(StringSplit(cases[c], StringGetCharacter("=", 0), kv) == 2) {
                        node.Case(ResolveId(Clean(kv[0])), ResolveId(Clean(kv[1])));
                    }
                }
            }
            map.Add(node);
        }
    }

protected:
    /**
     * @brief 상속을 위한 가상 함수 정의 (자식 클래스에서 구현)
     */
    virtual void RegisterStandardNames() {}
    virtual void InitWatcherMap() {}
    virtual void InitSessionMap() {}

    void RegisterStateName(string name) {
        if(name == "" || IsDigit(name)) return;
        int id;
        if(!m_registry.TryGetValue(name, id)) m_registry.Add(name, m_auto_id_counter++);
    }

    string Clean(string s) {
        string res = s;
        StringReplace(res, "\n", ""); StringReplace(res, "\r", ""); StringReplace(res, "\t", "");
        StringTrimLeft(res); StringTrimRight(res);
        return res;
    }

    int FindFirstDelimiter(string s) {
        string delims = "|?!@*>";
        int minPos = -1;
        for(int i=0; i<StringLen(delims); i++) {
            int pos = StringFind(s, StringSubstr(delims, i, 1));
            if(pos != -1 && (minPos == -1 || pos < minPos)) minPos = pos;
        }
        return minPos;
    }

    string GetSegment(string nodeStr, string startMarker, string endMarkers) {
        int start = StringFind(nodeStr, startMarker);
        if(start == -1) return "";
        start += StringLen(startMarker);
        int end = -1;
        for(int i=0; i<StringLen(endMarkers); i++) {
            int pos = StringFind(nodeStr, StringSubstr(endMarkers, i, 1), start);
            if(pos != -1 && (end == -1 || pos < end)) end = pos;
        }
        return (end == -1) ? StringSubstr(nodeStr, start) : StringSubstr(nodeStr, start, end - start);
    }

    bool IsDigit(string str) {
        if(str == "") return false;
        for(int i = 0; i < StringLen(str); i++) {
            ushort c = StringGetCharacter(str, i);
            if(c < '0' || c > '9') return false;
        }
        return true;
    }

    int ParseSuffixValue(string val) {
        string clean = Clean(val);
        StringReplace(clean, "s", ""); StringReplace(clean, "x", "");
        return (int)StringToInteger(clean);
    }
};
#endif
