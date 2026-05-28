#ifndef CXSEQUENCESTAGE_MQH
#define CXSEQUENCESTAGE_MQH

#include <Object.mqh>
#include <Generic\HashMap.mqh>
#include <Arrays\ArrayString.mqh>
#include "..\Defines\CXDefine.mqh"

/**
 * @class CXSequenceStage
 * @brief [v16.6] 시퀀스 구성을 위한 노드 데이터 클래스 (Enum-less 문자열 기반)
 */
class CXSequenceStage : public CObject {
private:
    int                 m_state_id;
    string              m_stage_type_str;    // [v16.6] Enum 대신 문자열 저장
    int                 m_next_id;
    int                 m_fail_id;
    int                 m_timeout;
    int                 m_retries;
    string              m_name;
    CHashMap<int, int>* m_branches;
    CArrayString*       m_tasks;            // [v16.6] 태스크 리스트를 문자열 배열로 관리

public:
    CXSequenceStage(int id, string typeStr, int next, int fail, int timeout = 0, int retries = 0, string name = "") 
        : m_state_id(id), m_stage_type_str(typeStr), m_next_id(next), m_fail_id(fail), m_timeout(timeout), m_retries(retries), m_name(name) {
        m_branches = new CHashMap<int, int>();
        m_tasks = new CArrayString();
    }

    ~CXSequenceStage() {
        SAFE_DELETE(m_branches);
        SAFE_DELETE(m_tasks);
    }

    CXSequenceStage* Case(int code, int next_state) {
        if(IS_VALID(m_branches)) m_branches.Add(code, next_state);
        return GetPointer(this);
    }

    CXSequenceStage* AddTask(string taskName) {
        if(IS_VALID(m_tasks)) m_tasks.Add(taskName);
        return GetPointer(this);
    }

    int             GetStateId()     const { return m_state_id; }
    string          GetStageTypeStr() const { return m_stage_type_str; }
    int             GetNextId()      const { return m_next_id; }
    int             GetFailId()      const { return m_fail_id; }
    int             GetTimeout()     const { return m_timeout; }
    int             GetRetries()     const { return m_retries; }
    string          GetName()        const { return m_name; }
    
    CHashMap<int, int>* GetBranches() const { return m_branches; }
    CArrayString*       GetTasks()    const { return m_tasks; }
};

#endif
