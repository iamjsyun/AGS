#ifndef CXTRANSACTION_MQH
#define CXTRANSACTION_MQH

#include "..\Interfaces\ICXParam.mqh"
#include "..\Interfaces\ICXSignal.mqh"
#include "..\Interfaces\IRepository.mqh"
#include "..\Interfaces\IXOrderManager.mqh"
#include "..\Interfaces\IXExitManager.mqh"
#include "..\Interfaces\ICXPriceManager.mqh"
#include "..\Interfaces\ICXServiceFactory.mqh"
#include "..\Macros\CXMacros.mqh"

/**
 * @class CXTransaction
 * @brief [v1.4] Base class for atomic trading operations
 */
class CXTransaction : public CObject {
protected:
    ICXParam*   m_xp;
    IRepository* m_repo;
    bool        m_isCommitted;

public:
    CXTransaction(ICXParam* xp, IRepository* repo) 
        : m_xp(xp), m_repo(repo), m_isCommitted(false) {}
    
    virtual ~CXTransaction() {}

    virtual bool Execute() = 0;
    virtual void Commit() { m_isCommitted = true; }
    virtual void Rollback() = 0;
};

/**
 * @class CXEntryTransaction
 * @brief Encapsulates the multi-step entry process (Price -> DB Lock -> Order)
 */
class CXEntryTransaction : public CXTransaction {
private:
    IXOrderManager*    m_orderMgr;
    ICXServiceFactory* m_factory;

public:
    CXEntryTransaction(ICXParam* xp, IRepository* repo, IXOrderManager* orderMgr, ICXServiceFactory* factory) 
        : CXTransaction(xp, repo), m_orderMgr(orderMgr), m_factory(factory) {}

    virtual bool Execute() override {
        if(IS_INVALID(m_xp) || IS_INVALID(m_orderMgr) || IS_INVALID(m_factory)) return false;
        ICXSignal* sig = m_xp.GetSignal();
        if(IS_INVALID(sig)) return false;

        // Step 1: Price Preparation (Modernization v1.4)
        ICXPriceManager* priceMgr = m_factory.CreatePriceManager(m_xp.GetContext());
        if(IS_VALID(priceMgr)) {
            string sym = sig.GetSymbol(); int dir = sig.GetDir();
            double execPrice = priceMgr.CalculateExecPrice(m_xp, sym, dir, sig.GetType(), sig.GetTELimit());
            double basePrice = (sig.GetType() == ORDER_MARKET) ? priceMgr.GetMarketPrice(sym, dir) : execPrice;
            sig.SetPriceOpen(execPrice);
            sig.SetPriceSL(priceMgr.CalculateSL(m_xp, sym, dir, basePrice, sig.GetSL()));
            sig.SetPriceTP(priceMgr.CalculateTP(m_xp, sym, dir, basePrice, sig.GetTP()));
            SAFE_DELETE(priceMgr);
        }

        // Step 2: Pre-Entry DB Lock (Atomic Lock Mandate v1.2)
        sig.SetStatus(XE_PENDING_REQ);
        sig.SetStatusMsg("Transaction Initiated: Locking DB...");
        if(IS_VALID(m_repo)) m_repo.UpdateStatus(sig);

        // Step 3: Broker Execution
        if(!m_orderMgr.ExecuteEntry(m_xp)) {
            Rollback();
            return false;
        }

        Commit();
        return true;
    }

    virtual void Rollback() override {
        ICXSignal* sig = m_xp.GetSignal();
        if(IS_VALID(sig)) {
            sig.SetStatus(XE_ERROR);
            sig.SetStatusMsg("Transaction Rollback: Entry Failed.");
            if(IS_VALID(m_repo)) m_repo.UpdateStatus(sig);
        }
    }
};

/**
 * @class CXExitTransaction
 * @brief Encapsulates the liquidation process
 */
class CXExitTransaction : public CXTransaction {
private:
    IXExitManager* m_exitMgr;

public:
    CXExitTransaction(ICXParam* xp, IRepository* repo, IXExitManager* exitMgr) 
        : CXTransaction(xp, repo), m_exitMgr(exitMgr) {}

    virtual bool Execute() override {
        if(IS_INVALID(m_xp) || IS_INVALID(m_exitMgr)) return false;
        
        // Step 1: Execute Exit via Manager
        if(!m_exitMgr.ExecuteExit(m_xp)) {
            Rollback();
            return false;
        }

        Commit();
        return true;
    }

    virtual void Rollback() override {
        ICXSignal* sig = m_xp.GetSignal();
        if(IS_VALID(sig)) {
            sig.SetStatus(XE_ERROR);
            sig.SetStatusMsg("Transaction Rollback: Exit Failed.");
            if(IS_VALID(m_repo)) m_repo.UpdateStatus(sig);
        }
    }
};

#endif
