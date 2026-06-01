#ifndef EA_MANAGER_MQH
#define EA_MANAGER_MQH

#include "..\..\99_TestFramework\UnitTests\Infrastructure\Test_Pipeline_DB_Conn.mqh"
#include "..\..\99_TestFramework\UnitTests\Entry_Stage\Test_Pipeline_Signal_Det.mqh"

#define EA_CMD_FILE "DB\\ea_command.txt"

void TestDispatcher(string task, string fn) {
    // Mapping Task/Fn to MQL5 test functions
    if(task == "CXDatabase" && fn == "Open") Run_Pipeline_DB_Conn_Test();
    else if(task == "CXSignalWatcher" && fn == "ValidateSymbol") Run_Pipeline_Signal_Det_Test();
    else Print("[EA-MGR] Unknown test target: ", task, "::", fn);
}

void CheckEaCommand() {
   string file_path = EA_CMD_FILE;
   if(!FileIsExist(file_path, FILE_COMMON)) return;
   
   int file_handle = FileOpen(file_path, FILE_READ | FILE_TXT | FILE_COMMON);
   if(file_handle == INVALID_HANDLE) return;
   
   string cmd = FileReadString(file_handle);
   FileClose(file_handle);
   
   if(StringLen(cmd) == 0) return;
   
   string parts[];
   StringSplit(cmd, '|', parts);
   
   if(parts[0] == "TEST") {
      string task = parts[1];
      string fn = parts[2];
      Print("[EA-MGR] TEST command received for: ", task, "::", fn);
      TestDispatcher(task, fn);
   }
   
   FileDelete(file_path, FILE_COMMON);
}

#endif
