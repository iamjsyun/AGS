#ifndef CX_SCENARIO_LOADER_MQH
#define CX_SCENARIO_LOADER_MQH

#include <Arrays\ArrayObj.mqh>
#include "CXScenarioParam.mqh"

/**
 * @class CXScenarioLoader
 * @brief CSV 파일을 읽어 시나리오 큐(CXScenarioParam)로 변환 (v13.8 Granular)
 */
class CXScenarioLoader {
public:
    static int Load(string filename, CArrayObj* queue) {
        if(CheckPointer(queue) == POINTER_INVALID) return 0;
        
        int handle = FileOpen(filename, FILE_READ|FILE_CSV|FILE_ANSI, ',');
        if(handle == INVALID_HANDLE) {
            PrintFormat("[SCENARIO-LOADER] ERROR: Failed to open %s. Error: %d", filename, GetLastError());
            return 0;
        }

        // Header Skip
        if(!FileIsEnding(handle)) FileReadString(handle);

        int count = 0;
        while(!FileIsEnding(handle)) {
            CXScenarioParam* p = new CXScenarioParam();
            
            p.release_delay = (int)StringToInteger(FileReadString(handle));
            p.action = FileReadString(handle);
            p.sid = FileReadString(handle);
            p.cno = (int)StringToInteger(FileReadString(handle));
            p.sno = (int)StringToInteger(FileReadString(handle));
            p.symbol = FileReadString(handle);
            p.dir = (int)StringToInteger(FileReadString(handle));
            p.type = (int)StringToInteger(FileReadString(handle));
            p.lot = StringToDouble(FileReadString(handle));
            p.sl_pts = (int)StringToInteger(FileReadString(handle));
            p.tp_pts = (int)StringToInteger(FileReadString(handle));
            
            // [v13.8] Granular TE/TS Reading
            p.te_start = (int)StringToInteger(FileReadString(handle));
            p.te_step  = (int)StringToInteger(FileReadString(handle));
            p.te_limit = (int)StringToInteger(FileReadString(handle));
            p.ts_start = (int)StringToInteger(FileReadString(handle));
            p.ts_step  = (int)StringToInteger(FileReadString(handle));
            
            p.exp_status = FileReadString(handle); 
            p.comment = FileReadString(handle);

            if(p.action != "") {
                queue.Add(p);
                count++;
            } else {
                delete p;
            }
        }

        FileClose(handle);
        PrintFormat("[SCENARIO-LOADER] SUCCESS: Loaded %d scenarios from %s", count, filename);
        return count;
    }
};

#endif
