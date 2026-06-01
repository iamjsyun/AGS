#ifndef CXSIGNALDISPATCHER_MQH
#define CXSIGNALDISPATCHER_MQH

#include "..\..\01_Core\Interfaces\ICXParam.mqh"
#include "..\..\01_Core\Interfaces\ICXSignal.mqh"
#include "..\..\01_Core\Interfaces\IRepository.mqh"
#include "..\..\01_Core\Macros\CXMacros.mqh"

/**
 * @interface ICXSignalListener
 * @brief Interface for objects that react to new signal events
 */
class ICXSignalListener : public CObject {
public:
    virtual void OnSignalDetected(ICXParam* xp) = 0;
};

/**
 * @class CXSignalDispatcher
 * @brief [v1.4] Monitors DB for new signals and dispatches events to listeners (Event-Driven)
 */
class CXSignalDispatcher : public CObject {
private:
    IRepository*      m_repo;
    CArrayObj*        m_listeners;

public:
    CXSignalDispatcher(IRepository* repo) : m_repo(repo) {
        m_listeners = new CArrayObj();
    }

    virtual ~CXSignalDispatcher() {
        SAFE_DELETE(m_listeners);
    }

    void AddListener(ICXSignalListener* listener) {
        if(IS_VALID(listener)) m_listeners.Add(listener);
    }

    /**
     * @brief Scans DB for new signals and notifies all listeners
     */
    void Dispatch(ICXParam* xp) {
        if(IS_INVALID(m_repo)) return;

        CArrayObj signals;
        // Corrected: Use LoadEntrySignals instead of GetPendingSignals
        if(m_repo.LoadEntrySignals(GetPointer(signals)) > 0) {
            for(int i = 0; i < signals.Total(); i++) {
                ICXSignal* sig = CX_CAST(ICXSignal, signals.At(i));
                if(IS_VALID(sig)) {
                    if(IS_VALID(xp)) {
                        xp.Reset();
                        xp.SetSignal(sig);
                        
                        // Notify all listeners of the new signal
                        for(int j = 0; j < m_listeners.Total(); j++) {
                            ICXSignalListener* listener = CX_CAST(ICXSignalListener, m_listeners.At(j));
                            if(IS_VALID(listener)) listener.OnSignalDetected(xp);
                        }
                    }
                }
            }
        }
    }
};

#endif
