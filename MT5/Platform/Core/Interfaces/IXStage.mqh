#ifndef IXSTAGE_MQH
#define IXSTAGE_MQH

#include <Object.mqh>
#include "ICXParam.mqh"
#include "ICXContext.mqh"

class IXStage : public CObject {
public:
    virtual string    Name() = 0;
    virtual bool      OnCondition(ICXParam* xp, ICXContext* ctx, int current_state) = 0;
    virtual int       OnProcess(ICXParam* xp, ICXContext* ctx) = 0;
    
    virtual void      OnEnter(ICXContext* ctx) = 0;
    virtual void      OnExit(ICXContext* ctx) = 0;
};

#endif
