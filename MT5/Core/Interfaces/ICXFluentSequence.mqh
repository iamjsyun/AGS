#ifndef ICXFLUENTSEQUENCE_MQH
#define ICXFLUENTSEQUENCE_MQH

#include <Object.mqh>
#include "ICXContext.mqh"
#include "ICXParam.mqh"

class IXStage;

class ICXFluentSequence : public CObject {
public:
    virtual ~ICXFluentSequence() {}
    virtual void AddStage(int state_id, IXStage* stage) = 0;
    virtual void Pulse(ICXParam* xp) = 0;
    virtual int  State() const = 0;
    virtual void ForceState(int next_state) = 0;
    virtual void Build() = 0;
    virtual void ResetState() = 0;
};

#endif
