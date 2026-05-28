#ifndef CXSTAGEFACTORY_MQH
#define CXSTAGEFACTORY_MQH

#include "..\..\Platform\Core\Interfaces\IXStage.mqh"
#include "..\..\Platform\Core\Macros\CXMacros.mqh"
#include "..\..\Watcher\WatcherWorkflow\CXStageEntryDiscovery.mqh"
#include "..\..\Watcher\WatcherWorkflow\CXStageEntryExecute.mqh"
#include "..\..\Watcher\WatcherWorkflow\CXStageExitDiscovery.mqh"
#include "..\..\Watcher\WatcherWorkflow\CXStageExitExecute.mqh"
#include "..\..\Watcher\WatcherWorkflow\CXStageSystemSetup.mqh"

#include "CXTaskFactory.mqh"
#include "..\..\Session\Workflow\CXCompositeStage.mqh"
#include <Arrays\ArrayString.mqh>

/**
 * @class CXStageFactory
 * @brief [v18.30] 코어 트레이딩 파이프라인에 최적화된 스테이지 팩토리
 */
class CXStageFactory {
public:
    static bool Exists(string name) {
        if(name == "SystemSetup")    return true;
        if(name == "EntryDiscovery") return true;
        if(name == "EntryExecute")   return true;
        if(name == "ExitDiscovery")  return true;
        if(name == "ExitExecute")    return true;
        if(name == "Composite")      return true;
        if(StringFind(name, "Stage_") == 0) return true;
        return false;
    }

    static IXStage* CreateStage(string typeName, string alias = "", CArrayString* taskNames = NULL) {
        if(typeName == "SystemSetup")    return new CXStageSystemSetup();
        if(typeName == "EntryDiscovery") return new CXStageEntryDiscovery();
        if(typeName == "EntryExecute")   return new CXStageEntryExecute();
        if(typeName == "ExitDiscovery")  return new CXStageExitDiscovery();
        if(typeName == "ExitExecute")    return new CXStageExitExecute();
        
        if(typeName == "Composite" || StringFind(typeName, "Stage_") == 0) {
            return CreateCompositeStage(alias == "" ? typeName : alias, taskNames);
        }
        return NULL;
    }

private:
    static IXStage* CreateCompositeStage(string name, CArrayString* taskList) {
        CXCompositeStage* stage = new CXCompositeStage(name);
        if(IS_INVALID(stage)) return NULL;

        if(IS_VALID(taskList)) {
            for(int i = 0; i < taskList.Total(); i++) {
                IXTask* task = CXTaskFactory::CreateTask(taskList.At(i));
                if(IS_VALID(task)) stage.AddTask(task);
            }
        }
        return stage;
    }
};

#endif
