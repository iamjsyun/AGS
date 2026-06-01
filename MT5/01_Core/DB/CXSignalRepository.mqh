//+------------------------------------------------------------------+
//|                                           CXSignalRepository.mqh |
//|                                  Copyright 2026, Gemini CLI      |
//| [v20.3] Facade for modular repository implementations           |
//+------------------------------------------------------------------+
#ifndef CXSIGNALREPOSITORY_MQH
#define CXSIGNALREPOSITORY_MQH

#include <Arrays\ArrayObj.mqh>
#include "..\Interfaces\IRepository.mqh"
#include "..\Interfaces\IDatabase.mqh"
#include "..\..\02_Domain\Models\CXSignal.mqh"

// 1. Utility Classes (Mappers) - Outside Class
#include "Repo\CXRepoMapper.mqh"

/**
 * @class CXSignalRepository
 * @brief [v20.3] Signal CRUD/Query Facade with modular Body-Includes
 */
class CXSignalRepository : public IRepository {
private:
   IDatabase* m_db;
   
   //--- Cache query handles (Performance Optimization)
   int        m_hActiveSignals;
   int        m_hSignalBySid;

public:
   CXSignalRepository(IDatabase* db) : m_db(db), 
      m_hActiveSignals(INVALID_HANDLE), 
      m_hSignalBySid(INVALID_HANDLE) {}

   virtual ~CXSignalRepository() {
      if(m_hActiveSignals != INVALID_HANDLE) DatabaseFinalize(m_hActiveSignals);
      if(m_hSignalBySid != INVALID_HANDLE)  DatabaseFinalize(m_hSignalBySid);
   }

   virtual void LoadParam(ICXParam* param) override {
      // Implementation for loading dynamic parameters
   }

   //--- [Body-Includes] Split Implementations (Inside Class)
   #include "Repo\CXRepoInternal.mqh"
   #include "Repo\CXRepoPersistence.mqh"
   #include "Repo\CXRepoLookup.mqh"
   #include "Repo\CXRepoSync.mqh"
   #include "Repo\CXRepoLoader.mqh"
};

#endif
