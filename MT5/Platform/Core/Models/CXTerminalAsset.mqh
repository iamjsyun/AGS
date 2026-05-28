#ifndef CX_TERMINAL_ASSET_MQH
#define CX_TERMINAL_ASSET_MQH

#include <Object.mqh>
#include "..\Defines\CXDefine.mqh"

/**
 * @class CXTerminalAsset
 * @brief 터미널 스캔 결과를 담는 DTO
 */
class CXTerminalAsset : public CObject {
public:
    string  sid;
    ulong   ticket;
    string  symbol;
    int     magic;
    int     type;
    double  lot;

    CXTerminalAsset() : sid(""), ticket(0), symbol(""), magic(0), type(0), lot(0.0) {}
};

#endif
