//+------------------------------------------------------------------+
//|                                                  CXTsdlParser.mqh |
//|                                  Copyright 2026, Gemini CLI      |
//| [v1.1] TSDL (Test Scenario Definition Language) Parser           |
//+------------------------------------------------------------------+
//| [v1.1] TSDL (Test Scenario Definition Language) Parser           |
//+------------------------------------------------------------------+
#ifndef CX_TSDL_PARSER_MQH
#define CX_TSDL_PARSER_MQH

#include <Object.mqh>
#include <Arrays\ArrayObj.mqh>

/**
 * @class CXTsdlAction
 * @brief 시나리오 틱 동작 정보 (INJECT: signals, MARKET, etc.)
 */
class CXTsdlAction : public CObject {
public:
    string m_type;   // INJECT, MARKET, etc.
    string m_target; // signals, terminal, GOLD#, etc.
    string m_keys[];
    string m_values[];

    CXTsdlAction() : m_type(""), m_target("") {}
    virtual ~CXTsdlAction() override {}

    string GetParam(string key) {
        for(int i = 0; i < ArraySize(m_keys); i++) {
            if(m_keys[i] == key) return m_values[i];
        }
        return "";
    }

    double GetParamDouble(string key, double defaultVal = 0.0) {
        string val = GetParam(key);
        if(val == "") return defaultVal;
        return StringToDouble(val);
    }

    int GetParamInt(string key, int defaultVal = 0) {
        string val = GetParam(key);
        if(val == "") return defaultVal;
        return (int)StringToInteger(val);
    }

    bool GetParamBool(string key, bool defaultVal = false) {
        string val = GetParam(key);
        if(val == "") return defaultVal;
        if(val == "true" || val == "1") return true;
        if(val == "false" || val == "0") return false;
        return defaultVal;
    }
};

/**
 * @class CXTsdlExpect
 * @brief 시나리오 틱 검증 정보 (EXPECT: session : state=ORD_READY * xe_status=...)
 */
class CXTsdlExpect : public CObject {
public:
    string m_type;    // session, etc.
    string m_keys[];
    string m_values[];
    string m_failMsg;

    CXTsdlExpect() : m_type(""), m_failMsg("") {}
    virtual ~CXTsdlExpect() override {}

    string GetParam(string key) {
        for(int i = 0; i < ArraySize(m_keys); i++) {
            if(m_keys[i] == key) return m_values[i];
        }
        return "";
    }

    double GetParamDouble(string key, double defaultVal = 0.0) {
        string val = GetParam(key);
        if(val == "") return defaultVal;
        return StringToDouble(val);
    }

    int GetParamInt(string key, int defaultVal = 0) {
        string val = GetParam(key);
        if(val == "") return defaultVal;
        return (int)StringToInteger(val);
    }

    bool GetParamBool(string key, bool defaultVal = false) {
        string val = GetParam(key);
        if(val == "") return defaultVal;
        if(val == "true" || val == "1") return true;
        if(val == "false" || val == "0") return false;
        return defaultVal;
    }
};

/**
 * @class CXTsdlStep
 * @brief 특정 틱 번호 아래의 동작 및 검증 그룹
 */
class CXTsdlStep : public CObject {
public:
    int        m_tickNum;
    CArrayObj* m_actions;
    CArrayObj* m_expectations;

    CXTsdlStep(int tickNum) : m_tickNum(tickNum) {
        m_actions = new CArrayObj();
        m_expectations = new CArrayObj();
    }

    virtual ~CXTsdlStep() override {
        if(CheckPointer(m_actions) == POINTER_DYNAMIC) delete m_actions;
        if(CheckPointer(m_expectations) == POINTER_DYNAMIC) delete m_expectations;
    }
};

/**
 * @class CXTsdlScenario
 * @brief 전체 TSDL 시나리오 구조를 적재하는 최상위 모델
 */
class CXTsdlScenario : public CObject {
public:
    string     m_id;
    string     m_desc;
    
    // DEFINE 변수 (Key-Value)
    string     m_defKeys[];
    string     m_defValues[];

    // PRICER 설정
    string     m_pricerSymbol;
    string     m_pricerModel;
    string     m_pricerKeys[];
    string     m_pricerValues[];

    CArrayObj* m_steps;

    CXTsdlScenario() : m_id(""), m_desc(""), m_pricerSymbol(""), m_pricerModel("") {
        m_steps = new CArrayObj();
    }

    virtual ~CXTsdlScenario() override {
        if(CheckPointer(m_steps) == POINTER_DYNAMIC) delete m_steps;
    }

    void AddDefine(string key, string val) {
        int n = ArraySize(m_defKeys);
        ArrayResize(m_defKeys, n + 1);
        ArrayResize(m_defValues, n + 1);
        m_defKeys[n] = key;
        m_defValues[n] = val;
    }

    string GetDefine(string key) {
        for(int i = 0; i < ArraySize(m_defKeys); i++) {
            if(m_defKeys[i] == key) return m_defValues[i];
        }
        return "";
    }

    /**
     * @brief 시나리오의 최대 틱 번호 확인
     */
    int GetMaxTick() {
        int maxTick = 0;
        for(int i = 0; i < m_steps.Total(); i++) {
            CXTsdlStep* step = (CXTsdlStep*)m_steps.At(i);
            if(step.m_tickNum > maxTick) maxTick = step.m_tickNum;
        }
        return maxTick;
    }

    /**
     * @brief 특정 틱 번호의 스텝 정보 반환
     */
    CXTsdlStep* GetStep(int tickNum) {
        for(int i = 0; i < m_steps.Total(); i++) {
            CXTsdlStep* step = (CXTsdlStep*)m_steps.At(i);
            if(step.m_tickNum == tickNum) return step;
        }
        return NULL;
    }

    void AddPricerParam(string key, string val) {
        int n = ArraySize(m_pricerKeys);
        ArrayResize(m_pricerKeys, n + 1);
        ArrayResize(m_pricerValues, n + 1);
        m_pricerKeys[n] = key;
        m_pricerValues[n] = val;
    }

    string GetPricerParam(string key) {
        for(int i = 0; i < ArraySize(m_pricerKeys); i++) {
            if(m_pricerKeys[i] == key) return m_pricerValues[i];
        }
        return "";
    }
};

/**
 * @class CXTsdlParser
 * @brief TSDL 소스 스트림을 기계적으로 해석하는 파싱 엔진
 */
class CXTsdlParser {
private:
    /**
     * @brief MQL5 규격에 맞게 문자열 양끝 공백 제거 (Wrapper)
     */
    static string Trim(string s) {
        string res = s;
        StringTrimLeft(res);
        StringTrimRight(res);
        return res;
    }

    /**
     * @brief [v1.2] 독립 주석 라인(#으로 시작) 처리
     * 주의: GOLDF# 등 심볼명에 '#'이 포함될 수 있으므로,
     * '#'이 라인의 첫 번째 비공백 문자인 경우에만 전체 라인을 주석으로 처리.
     * 값 내부의 '#'(예: GOLDF#)은 주석으로 취급하지 않는다.
     */
    static string TrimComment(string line) {
        string trimmed = Trim(line);
        // '#'이 첫 번째 비공백 문자인 경우에만 comment로 처리
        if(StringLen(trimmed) > 0 && StringSubstr(trimmed, 0, 1) == "#") return "";
        return trimmed;
    }

    /**
     * @brief Key=Value 리스트 문자열 해석 및 적재
     */
    static void ParseParams(string paramStr, string &keys[], string &values[]) {
        string tokens[];
        ushort u_comma = StringGetCharacter(",", 0);
        int numTokens = StringSplit(paramStr, u_comma, tokens);
        for(int i = 0; i < numTokens; i++) {
            string t = tokens[i];
            t = Trim(t);
            if(t == "") continue;

            int eqPos = StringFind(t, "=");
            if(eqPos > 0) {
                string k = StringSubstr(t, 0, eqPos);
                string v = StringSubstr(t, eqPos + 1);
                k = Trim(k);
                v = Trim(v);

                // 큰따옴표가 감싸고 있다면 제거
                if(StringLen(v) >= 2 && StringSubstr(v, 0, 1) == "\"" && StringSubstr(v, StringLen(v)-1, 1) == "\"") {
                    v = StringSubstr(v, 1, StringLen(v)-2);
                }
                int n = ArraySize(keys);
                ArrayResize(keys, n + 1);
                ArrayResize(values, n + 1);
                keys[n] = k;
                values[n] = v;
            }
        }
    }

    /**
     * @brief 틱 구문 안의 액션 및 검증 해석 분기
     */
    static void ParseActionOrExpect(string text, CXTsdlStep* step) {
        text = Trim(text);
        if(text == "") return;

        if(StringSubstr(text, 0, 1) == ">") {
            // Action 구문: "> INJECT: signals : xa_entry=1, xa_exit=0"
            string actionPart = Trim(StringSubstr(text, 1));
            int posColon1 = StringFind(actionPart, ":");
            if(posColon1 >= 0) {
                string actionType = Trim(StringSubstr(actionPart, 0, posColon1));
                string rest = StringSubstr(actionPart, posColon1 + 1);

                int posColon2 = StringFind(rest, ":");
                string target = "";
                string paramsPart = "";
                if(posColon2 >= 0) {
                    target = Trim(StringSubstr(rest, 0, posColon2));
                    paramsPart = StringSubstr(rest, posColon2 + 1);
                } else {
                    target = Trim(rest);
                }

                CXTsdlAction* action = new CXTsdlAction();
                action.m_type = actionType;
                action.m_target = target;
                ParseParams(paramsPart, action.m_keys, action.m_values);
                step.m_actions.Add(action);
            }
        }
        else if(StringSubstr(text, 0, 1) == "?") {
            // Expect 구문: "? EXPECT: session : state=ORD_READY * xe_status=..."
            string expectPart = Trim(StringSubstr(text, 1));

            // 실패 메시지 (!) 존재 검사
            int posExcl = StringFind(expectPart, "!");
            string failMsg = "";
            if(posExcl >= 0) {
                string rest = StringSubstr(expectPart, posExcl + 1);
                rest = Trim(rest);
                if(StringSubstr(rest, 0, 9) == "FAIL_MSG:") {
                    failMsg = StringSubstr(rest, 9);
                } else {
                    failMsg = rest;
                }
                failMsg = Trim(failMsg);
                if(StringLen(failMsg) >= 2 && StringSubstr(failMsg, 0, 1) == "\"" && StringSubstr(failMsg, StringLen(failMsg)-1, 1) == "\"") {
                    failMsg = StringSubstr(failMsg, 1, StringLen(failMsg)-2);
                }
                expectPart = StringSubstr(expectPart, 0, posExcl);
            }

            int posExpect = StringFind(expectPart, "EXPECT:");
            if(posExpect >= 0) {
                expectPart = StringSubstr(expectPart, posExpect + 7);
            }
            expectPart = Trim(expectPart);

            int posColon = StringFind(expectPart, ":");
            string expectType = "";
            string paramsPart = "";
            if(posColon >= 0) {
                expectType = Trim(StringSubstr(expectPart, 0, posColon));
                paramsPart = StringSubstr(expectPart, posColon + 1);
            } else {
                expectType = expectPart;
            }

            paramsPart = Trim(paramsPart);
            // * 및 , 혼용 지원 (WPF/TSDL 통일성을 위해 *을 ,로 임시 치환하여 파싱)
            string cleanParams = paramsPart;
            StringReplace(cleanParams, "*", ",");

            CXTsdlExpect* expect = new CXTsdlExpect();
            expect.m_type = expectType;
            expect.m_failMsg = failMsg;
            ParseParams(cleanParams, expect.m_keys, expect.m_values);
            step.m_expectations.Add(expect);
        }
    }

public:
    /**
     * @brief TSDL 파일을 열어 파싱하여 시나리오 객체 반환 (FILE_COMMON 전용)
     */
    static CXTsdlScenario* Parse(string filename) {
        int handle = FileOpen(filename, FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON);
        
        if(handle == INVALID_HANDLE) {
            PrintFormat("[TSDL-PARSER] ERROR: Failed to open scenario file '%s' in FILE_COMMON. Error: %d", filename, GetLastError());
            return NULL;
        }

        CXTsdlScenario* scenario = new CXTsdlScenario();
        CXTsdlStep* currentStep = NULL;

        while(!FileIsEnding(handle)) {
            string lineStr = FileReadString(handle);
            lineStr = Trim(lineStr);
            if(lineStr == "") continue;

            // 라인 백슬래시(\) 연결자 처리
            while(StringLen(lineStr) >= 1 && StringSubstr(lineStr, StringLen(lineStr) - 1, 1) == "\\" && !FileIsEnding(handle)) {
                lineStr = StringSubstr(lineStr, 0, StringLen(lineStr) - 1);
                string nextLine = FileReadString(handle);
                nextLine = Trim(nextLine);
                lineStr = lineStr + " " + nextLine;
            }

            // 주석 제거
            lineStr = TrimComment(lineStr);
            if(lineStr == "") continue;

            // SCENARIO 선언부 파싱
            if(StringSubstr(lineStr, 0, 9) == "SCENARIO:") {
                string rest = StringSubstr(lineStr, 9);
                int posColon = StringFind(rest, ":");
                if(posColon >= 0) {
                    scenario.m_id = Trim(StringSubstr(rest, 0, posColon));
                    string desc = StringSubstr(rest, posColon + 1);
                    desc = Trim(desc);
                    if(StringLen(desc) >= 2 && StringSubstr(desc, 0, 1) == "\"" && StringSubstr(desc, StringLen(desc)-1, 1) == "\"") {
                        desc = StringSubstr(desc, 1, StringLen(desc)-2);
                    }
                    scenario.m_desc = desc;
                } else {
                    scenario.m_id = Trim(rest);
                }
                continue;
            }

            // DEFINE 변수 파싱
            if(StringSubstr(lineStr, 0, 7) == "DEFINE:") {
                string rest = StringSubstr(lineStr, 7);
                string keys[], values[];
                ParseParams(rest, keys, values);
                for(int i = 0; i < ArraySize(keys); i++) {
                    scenario.AddDefine(keys[i], values[i]);
                }
                continue;
            }

            // PRICER 설정 파싱
            if(StringSubstr(lineStr, 0, 8) == "PRICER:") {
                string rest = StringSubstr(lineStr, 8);
                int posArrow = StringFind(rest, ">");
                int posColon = StringFind(rest, ":");
                if(posArrow >= 0 && posColon >= 0) {
                    scenario.m_pricerSymbol = Trim(StringSubstr(rest, 0, posArrow));
                    scenario.m_pricerModel = Trim(StringSubstr(rest, posArrow + 1, posColon - posArrow - 1));
                    string paramsStr = StringSubstr(rest, posColon + 1);
                    string keys[], values[];
                    ParseParams(paramsStr, keys, values);
                    for(int i = 0; i < ArraySize(keys); i++) {
                        scenario.AddPricerParam(keys[i], values[i]);
                    }
                }
                continue;
            }

            // TICK 구문 파싱
            if(StringSubstr(lineStr, 0, 5) == "TICK:") {
                string rest = StringSubstr(lineStr, 5);
                int posArrow = StringFind(rest, ">");
                int posExpect = StringFind(rest, "?");
                int endOfTickNum = (posArrow >= 0) ? posArrow : ((posExpect >= 0) ? posExpect : StringLen(rest));
                string tickNumStr = Trim(StringSubstr(rest, 0, endOfTickNum));
                int tickNum = (int)StringToInteger(tickNumStr);

                currentStep = NULL;
                for(int i = 0; i < scenario.m_steps.Total(); i++) {
                    CXTsdlStep* step = (CXTsdlStep*)scenario.m_steps.At(i);
                    if(step.m_tickNum == tickNum) {
                        currentStep = step;
                        break;
                    }
                }
                if(currentStep == NULL) {
                    currentStep = new CXTsdlStep(tickNum);
                    scenario.m_steps.Add(currentStep);
                }

                string actionOrExpectPart = StringSubstr(rest, endOfTickNum);
                ParseActionOrExpect(actionOrExpectPart, currentStep);
                continue;
            }

            // 연속되는 틱 내부 구문 (> 및 ?로 시작)
            if(currentStep != NULL && (StringSubstr(lineStr, 0, 1) == ">" || StringSubstr(lineStr, 0, 1) == "?")) {
                ParseActionOrExpect(lineStr, currentStep);
            }
        }

        FileClose(handle);
        PrintFormat("[TSDL-PARSER] SUCCESS: Loaded scenario '%s' with %d steps.", scenario.m_id, scenario.m_steps.Total());
        return scenario;
    }
};

#endif
