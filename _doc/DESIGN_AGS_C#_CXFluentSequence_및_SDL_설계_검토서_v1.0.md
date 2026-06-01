# [Design] C# CXFluentSequence 및 SDL 설계 및 구현 검토서 (v1.0)

본 설계서는 AGS MQL5 엔진의 상태 머신 시퀀스 제어기인 `CXFluentSequence`와 텍스트 기반 시퀀스 정의 언어인 `SDL` (Sequence/State Definition Language) 기능을 C# 환경으로 이식하고 고도화하기 위한 설계 및 구현 검토 내용을 기술합니다.

---

## 1. 개요 및 이식 배경

AGS (Anti-Gravity System)의 MQL5 코드는 비즈니스 흐름을 구조화하기 위해 `CXFluentSequence` 엔진과 텍스트 형태의 선언형 DSL(즉, SDL)을 사용합니다. 이를 통해 하드코딩된 상태 전이를 배제하고, 설정 파일이나 텍스트 스트림을 통해 동적으로 트레이딩 워크플로우를 빌드합니다.

C# 백엔드 서버 또는 시뮬레이터 환경에서 MQL5와 동일한 시퀀스 동작 및 검증 성능을 유지하기 위해, 본 문서에서는 다음 사항을 보증하는 C# 기반 설계안을 제시합니다:
1. **행동 정합성**: MQL5의 즉시 전이 루프(Immediate Transition Loop), 타임아웃, 재시도(Retry), 그리고 다중 분기(Case Case) 동작 방식과 100% 정합성을 유지합니다.
2. **C# 아키텍처 최적화**: 가비지 컬렉션(GC), 제네릭 컬렉션(Generic Dictionary), 인터페이스 기반 다형성을 활용하여 메모리 누수를 원천 차단하고 형식 안정성(Type Safety)을 극대화합니다.
3. **테스트 용이성**: 하드코딩된 시간 함수 대신 시간 제공 인터페이스(`ITimeProvider`)를 주입하여, 초 단위 타임아웃 테스트를 동기적이고 결정론적(Deterministic)으로 수행할 수 있도록 설계합니다.

---

## 2. MQL5 vs C# 구조 매핑 매트릭스

| MQL5 핵심 컴포넌트 | C# 매핑 클래스/인터페이스 | 구조적 차이 및 개선점 |
| :--- | :--- | :--- |
| `ICXFluentSequence` | `ICXFluentSequence` (인터페이스) | 다형성 확보 및 Mock 시퀀스 구현 지원 |
| `CXFluentSequence` | `CXFluentSequence` | 가비지 컬렉션 적용으로 `SAFE_DELETE` 및 댕글링 포인터 차단 |
| `CXStageNode` | `CXStageNode` | `Dictionary<int, int>`를 사용하여 속도 및 안전성 향상 |
| `IXStage` / `IXGuard` | `IXStage` / `IXGuard` | C# 표준 프로퍼티(`string Name { get; }`) 및 DI 컨테이너 연동 |
| `CXSequenceOrchestrator` | `SDLParser` / `SDLCompiler` | 파싱 엔진과 실행 오케스트레이터를 분리하여 단일 책임 원칙(SRP) 준수 |
| `TimeCurrent()` | `ITimeProvider` (추상화) | 가상 시간 주입을 통한 시간 기반 엣지 케이스 테스트 지원 |

---

## 3. C# 상세 설계 및 코드 스펙

### 3.1. 핵심 추상화 인터페이스

```csharp
using System;

namespace AGS.Core.Orchestration
{
    /// <summary>
    /// 트레이딩 세션 및 시퀀스의 실행 컨텍스트를 나타냅니다.
    /// </summary>
    public interface ICXContext
    {
        ICXParam GetParam();
        void LogInfo(string message);
        void LogWarn(string message);
        void LogError(string message);
    }

    /// <summary>
    /// 시퀀스 실행에 사용되는 전역/세션 변수 컨테이너입니다.
    /// </summary>
    public interface ICXParam
    {
        string GetString();
        void SetString(string val);
    }

    /// <summary>
    /// 시스템 시간 의존성을 제거하여 테스트 가능성을 높이기 위한 시간 인터페이스입니다.
    /// </summary>
    public interface ITimeProvider
    {
        DateTime GetCurrentTime();
    }

    public class DefaultTimeProvider : ITimeProvider
    {
        public DateTime GetCurrentTime() => DateTime.UtcNow;
    }
}
```

```csharp
namespace AGS.Core.Orchestration
{
    /// <summary>
    /// 시퀀스의 특정 상태(State)에서 실행될 비즈니스 단위입니다.
    /// </summary>
    public interface IXStage
    {
        string Name { get; }
        
        /// <summary>
        /// 해당 스테이지가 실행 가능한 상태인지 점검합니다.
        /// </summary>
        bool OnCondition(ICXParam xp, ICXContext ctx, int currentState);
        
        /// <summary>
        /// 비즈니스 핵심 로직을 수행하고 다음 상태 코드를 반환합니다.
        /// </summary>
        int OnProcess(ICXParam xp, ICXContext ctx);
        
        /// <summary>
        /// 상태에 진입할 때 실행되는 훅입니다.
        /// </summary>
        void OnEnter(ICXContext ctx);
        
        /// <summary>
        /// 상태에서 이탈할 때 실행되는 훅입니다.
        /// </summary>
        void OnExit(ICXContext ctx);
    }

    /// <summary>
    /// 스테이지 실행 전 통과해야 하는 무결성 가드 인터페이스입니다.
    /// </summary>
    public interface IXGuard
    {
        bool Check(ICXParam xp, ICXContext ctx);
    }
}
```

### 3.2. CXStageNode 구성

```csharp
using System.Collections.Generic;

namespace AGS.Core.Orchestration
{
    /// <summary>
    /// 시퀀스 노드 데이터 및 실행 규칙(성공/실패 경로, 타임아웃, 재시도, 분기)을 관리합니다.
    /// </summary>
    public class CXStageNode
    {
        public IXStage Stage { get; }
        public IXGuard Guard { get; }
        public int IfTrue { get; }
        public int IfFalse { get; }
        public int TimeoutSec { get; }
        public int MaxRetries { get; }
        public int CurrentRetries { get; set; }
        public Dictionary<int, int> Branches { get; } = new();

        public CXStageNode(IXStage stage, int ifTrue, int ifFalse, int timeoutSec = 0, int maxRetries = 0, IXGuard guard = null)
        {
            Stage = stage;
            IfTrue = ifTrue;
            IfFalse = ifFalse;
            TimeoutSec = timeoutSec;
            MaxRetries = maxRetries;
            Guard = guard;
        }
    }
}
```

### 3.3. CXFluentSequence 구현체

```csharp
using System;
using System.Collections.Generic;

namespace AGS.Core.Orchestration
{
    public interface ICXFluentSequence
    {
        void AddStage(int stateId, IXStage stage);
        void Pulse(ICXParam xp);
        int State { get; }
        void ForceState(int nextState);
        void Build();
        void ResetState();
        bool Bind();
    }

    public class CXFluentSequence : ICXFluentSequence
    {
        private readonly ICXContext _ctx;
        private readonly string _name;
        private readonly ITimeProvider _timeProvider;
        private readonly Dictionary<int, CXStageNode> _map = new();
        
        private int _currentState = -1;
        private int _firstState = -1;
        private DateTime _stateEntered;

        // Builder 임시 변수 (Fluent API용)
        private int _tmpFrom = -1;
        private IXStage _tmpStage;
        private IXGuard _tmpGuard;
        private int _tmpSuccess = -1;
        private int _tmpFail = -1;
        private int _tmpTimeout = 0;
        private int _tmpRetries = 0;
        private readonly Dictionary<int, int> _tmpBranches = new();

        public int State => _currentState;

        public CXFluentSequence(ICXContext ctx, string name, ITimeProvider timeProvider = null)
        {
            _ctx = ctx ?? throw new ArgumentNullException(nameof(ctx));
            _name = name;
            _timeProvider = timeProvider ?? new DefaultTimeProvider();
            _stateEntered = _timeProvider.GetCurrentTime();
        }

        private void CommitCurrent()
        {
            if (_tmpFrom == -1 || _tmpStage == null) return;

            var node = new CXStageNode(_tmpStage, _tmpSuccess, _tmpFail, _tmpTimeout, _tmpRetries, _tmpGuard);
            foreach (var kvp in _tmpBranches)
            {
                node.Branches[kvp.Key] = kvp.Value;
            }
            _tmpBranches.Clear();

            _map[_tmpFrom] = node;

            // 임시 빌더 상태 초기화
            _tmpFrom = -1;
            _tmpStage = null;
            _tmpGuard = null;
            _tmpSuccess = -1;
            _tmpFail = -1;
            _tmpTimeout = 0;
            _tmpRetries = 0;
        }

        //--- Fluent API 구현
        public CXFluentSequence From(int state)
        {
            CommitCurrent();
            _tmpFrom = state;
            if (_firstState == -1) _firstState = state;
            return this;
        }

        public CXFluentSequence Execute(IXStage stage)
        {
            _tmpStage = stage;
            return this;
        }

        public CXFluentSequence Guard(IXGuard guard)
        {
            _tmpGuard = guard;
            return this;
        }

        public CXFluentSequence OnSuccess(int next)
        {
            _tmpSuccess = next;
            return this;
        }

        public CXFluentSequence OnFail(int next)
        {
            _tmpFail = next;
            return this;
        }

        public CXFluentSequence Timeout(int sec)
        {
            _tmpTimeout = sec;
            return this;
        }

        public CXFluentSequence Retries(int count)
        {
            _tmpRetries = count;
            return this;
        }

        public CXFluentSequence Case(int code, int state)
        {
            _tmpBranches[code] = state;
            return this;
        }

        public void AddStage(int stateId, IXStage stage)
        {
            var node = new CXStageNode(stage, -1, -1);
            _map[stateId] = node;
        }

        public void Build()
        {
            CommitCurrent();
            if (_currentState == -1)
            {
                _currentState = _firstState;
                _ctx.LogInfo($"[SEQ:{_name}] Sequence Started at State: {_currentState}");
            }
            TriggerOnEnter(_currentState);
        }

        public bool Bind()
        {
            // DI 컨테이너 연동 또는 스테이지 사전 검증에 사용
            return _ctx != null;
        }

        public void ResetState()
        {
            _currentState = _firstState;
            _stateEntered = _timeProvider.GetCurrentTime();
        }

        public void ForceState(int nextState)
        {
            UpdateState(nextState);
        }

        /// <summary>
        /// 매 틱/이벤트마다 호출되며 상태 전환 및 비즈니스 프로세스를 실행합니다.
        /// </summary>
        public void Pulse(ICXParam xp)
        {
            if (_currentState == -1) return;

            // [Immediate Transition Loop]
            // 다음 틱까지 기다리지 않고 상태를 즉시 순차 이동 (최대 3회 허용하여 무한 루프 방지)
            for (int loop = 0; loop < 3; loop++)
            {
                if (!_map.TryGetValue(_currentState, out var node) || node == null) return;

                // 1. Guard 체크
                if (node.Guard != null && !node.Guard.Check(xp, _ctx)) return;

                // 2. 타임아웃 체크
                if (node.TimeoutSec > 0 && (_timeProvider.GetCurrentTime() - _stateEntered).TotalSeconds > node.TimeoutSec)
                {
                    int next = (node.IfFalse != -1) ? node.IfFalse : -99; // -99: SYS_ERROR fallback
                    _ctx.LogWarn($"[SEQ:{_name}] State {_currentState} Timeout ({node.TimeoutSec} sec). Moving to {next}");
                    UpdateState(next);
                    continue; // 변경된 상태로 즉시 재진입 평가
                }

                // 3. 실행 조건 평가
                if (node.Stage.OnCondition(xp, _ctx, _currentState))
                {
                    int nextState = node.Stage.OnProcess(xp, _ctx);

                    // Stage 성공 반환값을 지정된 IfTrue 성공 경로로 매핑
                    if (nextState == 0) // STAGE_SUCCESS = 0 가정
                    {
                        nextState = node.IfTrue;
                    }

                    // 상태 유지 또는 Yield 지시 시 루프 종료
                    if (nextState == _currentState || nextState == -1)
                    {
                        return;
                    }

                    // 실패 경로 발생 시 재시도 평가
                    if (nextState == node.IfFalse && node.MaxRetries > 0)
                    {
                        node.CurrentRetries++;
                        if (node.CurrentRetries <= node.MaxRetries)
                        {
                            _ctx.LogWarn($"[SEQ:{_name}] Stage '{node.Stage.Name}' failed. Retry {node.CurrentRetries}/{node.MaxRetries}...");
                            return; // 재시도를 위해 틱 산출 종료
                        }
                        else
                        {
                            _ctx.LogError($"[SEQ:{_name}] Stage '{node.Stage.Name}' exhausted retries. Moving to terminal fail state {node.IfFalse}.");
                            node.CurrentRetries = 0;
                            UpdateState(node.IfFalse);
                            continue;
                        }
                    }

                    // 다중 분기 조건(Case) 체크
                    if (node.Branches.TryGetValue(nextState, out int branchState))
                    {
                        node.CurrentRetries = 0;
                        UpdateState(branchState);
                        continue;
                    }

                    // 일반적인 상태 전이
                    if (nextState != _currentState && nextState != -1)
                    {
                        node.CurrentRetries = 0;
                        UpdateState(nextState);
                        continue;
                    }
                }
                break; // 조건을 만족하지 않으면 루프 탈출
            }
        }

        private void UpdateState(int next)
        {
            if (_currentState == next) return;
            if (!ValidateTransition(_currentState, next))
            {
                _ctx.LogError($"[SEQ:{_name}] CRITICAL: Illegal Transition Blocked ({_currentState} -> {next})");
                return;
            }

            TriggerOnExit(_currentState);
            _currentState = next;
            _stateEntered = _timeProvider.GetCurrentTime();
            TriggerOnEnter(_currentState);
        }

        private bool ValidateTransition(int from, int to)
        {
            // 도메인 규칙에 따른 상태 전이 유효성 검사 (예: 종료 상태에서의 전이 제한 등)
            return true;
        }

        private void TriggerOnEnter(int state)
        {
            if (_map.TryGetValue(state, out var node) && node != null)
            {
                node.Stage.OnEnter(_ctx);
            }
        }

        private void TriggerOnExit(int state)
        {
            if (_map.TryGetValue(state, out var node) && node != null)
            {
                node.Stage.OnExit(_ctx);
            }
        }
    }
}
```

---

## 4. SDL (Sequence Definition Language) 파서 및 빌더 설계

SDL 문자열 패턴을 구문 분석하고 `CXFluentSequence` 설정을 기계적으로 구성하는 C# 구현 명세입니다. MQL5의 `BuildFromDSL` 알고리즘과 파싱 토큰 형식을 완벽하게 호환시킵니다.

### 4.1. 시퀀스 노드 설정 구조체

```csharp
using System.Collections.Generic;

namespace AGS.Core.Orchestration.SDL
{
    public class CXSequenceStageConfig
    {
        public int StateId { get; }
        public string StageTypeStr { get; }
        public int NextId { get; }
        public int FailId { get; }
        public int Timeout { get; }
        public int Retries { get; }
        public string Name { get; }
        public Dictionary<int, int> Branches { get; } = new();
        public List<string> Tasks { get; } = new();

        public CXSequenceStageConfig(int id, string typeStr, int next, int fail, int timeout = 0, int retries = 0, string name = "")
        {
            StateId = id;
            StageTypeStr = typeStr;
            NextId = next;
            FailId = fail;
            Timeout = timeout;
            Retries = retries;
            Name = name;
        }
    }
}
```

### 4.2. SDLParser 구현

```csharp
using System;
using System.Collections.Generic;

namespace AGS.Core.Orchestration.SDL
{
    public class SDLParser
    {
        private readonly Dictionary<string, int> _registry = new(StringComparer.OrdinalIgnoreCase);
        private int _autoIdCounter = 1000;

        public void RegisterStandardNames(Dictionary<string, int> standardNames)
        {
            foreach (var kvp in standardNames)
            {
                _registry[kvp.Key] = kvp.Value;
            }
        }

        public int ResolveId(string value)
        {
            string val = Clean(value);
            if (string.IsNullOrEmpty(val)) return -1;
            if (int.TryParse(val, out int id)) return id;
            
            if (_registry.TryGetValue(val, out int existingId)) return existingId;
            
            int newId = _autoIdCounter++;
            _registry[val] = newId;
            return newId;
        }

        /// <summary>
        /// SDL 스크립트 라인 배열을 해석하여 컴파일용 설정 객체 목록을 생성합니다.
        /// </summary>
        public List<CXSequenceStageConfig> ParseSDL(string[] dslLines)
        {
            // 1차 패스: 상태 식별자 및 이름 사전 등록
            foreach (var line in dslLines)
            {
                if (string.IsNullOrWhiteSpace(line)) continue;
                int firstDelim = FindFirstDelimiter(line);
                string idName = firstDelim == -1 ? line : line.Substring(0, firstDelim);
                string cleanIdName = Clean(idName);
                if (!string.IsNullOrEmpty(cleanIdName) && !int.TryParse(cleanIdName, out _))
                {
                    if (!_registry.ContainsKey(cleanIdName))
                    {
                        _registry[cleanIdName] = _autoIdCounter++;
                    }
                }
            }

            var configs = new List<CXSequenceStageConfig>();

            // 2차 패스: 상세 구성 파싱
            foreach (var s in dslLines)
            {
                if (string.IsNullOrWhiteSpace(s)) continue;
                int firstDelim = FindFirstDelimiter(s);
                if (firstDelim == -1) continue;

                string name = Clean(s.Substring(0, firstDelim));
                int id = ResolveId(name);

                string delim = s.Substring(firstDelim, 1);
                string logicPart = GetSegment(s, delim, "?!@*");
                string[] stageParts = logicPart.Split(':');

                string typeStr = Clean(stageParts[0]);
                string alias = typeStr;
                string taskStr = "";

                if (stageParts.Length == 2)
                {
                    taskStr = Clean(stageParts[1]);
                }
                else if (stageParts.Length > 2)
                {
                    alias = Clean(stageParts[1]);
                    taskStr = Clean(stageParts[2]);
                }

                int next = ResolveId(GetSegment(s, "?", "|!@*"));
                int fail = ResolveId(GetSegment(s, "!", "|?@*"));

                string constStr = GetSegment(s, "@", "|?!*");
                string[] constParts = constStr.Split(',');
                int timeout = constParts.Length > 0 ? ParseSuffixValue(constParts[0]) : 0;
                int retries = constParts.Length > 1 ? ParseSuffixValue(constParts[1]) : 0;

                var config = new CXSequenceStageConfig(id, typeStr, next, fail, timeout, retries, alias);

                // 태스크 파싱
                if (!string.IsNullOrEmpty(taskStr))
                {
                    string[] tasks = taskStr.Split(',');
                    foreach (var task in tasks)
                    {
                        string cleanTask = Clean(task);
                        if (!string.IsNullOrEmpty(cleanTask)) config.Tasks.Add(cleanTask);
                    }
                }

                // 조건 분기(Case) 파싱 (* 10=POS_MONITORING 등)
                string branchStr = GetSegment(s, "*", "|?!@");
                if (!string.IsNullOrEmpty(branchStr))
                {
                    string[] cases = branchStr.Split(',');
                    foreach (var c in cases)
                    {
                        string[] kv = c.Split('=');
                        if (kv.Length == 2)
                        {
                            config.Branches[ResolveId(Clean(kv[0]))] = ResolveId(Clean(kv[1]));
                        }
                    }
                }

                configs.Add(config);
            }

            return configs;
        }

        private string Clean(string s)
        {
            if (s == null) return "";
            return s.Replace("\n", "").Replace("\r", "").Replace("\t", "").Trim();
        }

        private int FindFirstDelimiter(string s)
        {
            string delims = "|?!@*>";
            int minPos = -1;
            for (int i = 0; i < delims.Length; i++)
            {
                int pos = s.IndexOf(delims[i]);
                if (pos != -1 && (minPos == -1 || pos < minPos)) minPos = pos;
            }
            return minPos;
        }

        private string GetSegment(string nodeStr, string startMarker, string endMarkers)
        {
            int start = nodeStr.IndexOf(startMarker);
            if (start == -1) return "";
            start += startMarker.Length;
            int end = -1;
            for (int i = 0; i < endMarkers.Length; i++)
            {
                int pos = nodeStr.IndexOf(endMarkers[i], start);
                if (pos != -1 && (end == -1 || pos < end)) end = pos;
            }
            return end == -1 ? nodeStr.Substring(start) : nodeStr.Substring(start, end - start);
        }

        private int ParseSuffixValue(string val)
        {
            string clean = Clean(val).Replace("s", "").Replace("x", "");
            return int.TryParse(clean, out int res) ? res : 0;
        }
    }
}
```

### 4.3. SDL Compiler (시퀀스 생성 결합기)

```csharp
using System;
using System.Collections.Generic;

namespace AGS.Core.Orchestration.SDL
{
    public static class SDLCompiler
    {
        /// <summary>
        /// 파싱된 SDL 설정을 바탕으로 CXFluentSequence 객체에 실체화된 Stage들을 매핑하고 빌드합니다.
        /// </summary>
        public static void Compile(
            CXFluentSequence seq, 
            List<CXSequenceStageConfig> configs, 
            Func<string, string, List<string>, IXStage> stageFactory)
        {
            if (seq == null) throw new ArgumentNullException(nameof(seq));
            if (configs == null) throw new ArgumentNullException(nameof(configs));
            if (stageFactory == null) throw new ArgumentNullException(nameof(stageFactory));

            foreach (var cfg in configs)
            {
                IXStage stage = stageFactory(cfg.StageTypeStr, cfg.Name, cfg.Tasks);
                if (stage == null)
                {
                    throw new InvalidOperationException($"Failed to create stage of type: {cfg.StageTypeStr}");
                }

                seq.From(cfg.StateId)
                   .Execute(stage)
                   .OnSuccess(cfg.NextId)
                   .OnFail(cfg.FailId)
                   .Timeout(cfg.Timeout)
                   .Retries(cfg.Retries);

                foreach (var branch in cfg.Branches)
                {
                    seq.Case(branch.Key, branch.Value);
                }
            }

            seq.Build();
        }
    }
}
```

---

## 5. 설계 검토 의견 및 안정성 분석

### 5.1. 가비지 컬렉션(GC) 및 루프 안정성 보장
- **MQL5 이슈**: MQL5 환경에서는 순회 루프 도중 해제 지연이나 허상 포인터(Dangling Pointer) 발생 우려로 인해 `RULE[GEMINI.md]`(Loop Stability & Atomic Batch Delete Mandate)와 같은 일괄 해제 규격이 강조되었습니다.
- **C# 개선안**: C# 클래스들은 생명주기가 만료되는 즉시 GC에 의해 안전하게 수거되므로 명시적 삭제 루틴이 단순화되며, 인덱스 훼손으로 인한 안전성 저하가 발생하지 않습니다.

### 5.2. `ITimeProvider`를 이용한 유닛 테스트 혁신
- **MQL5 이슈**: MQL5 내에서는 타임아웃(`node.timeout_sec`) 테스트 시 가짜로 대기 시간을 발생시키거나, 틱 시뮬레이터에서 실시간 타임스탬프를 강제 조작해야 하는 등 검증이 까다롭습니다.
- **C# 개선안**: 유닛 테스트 실행 시 `MockTimeProvider`를 주입하여 시간을 강제로 `AddSeconds(301)` 형태로 조작함으로써, 스레드 대기(`Thread.Sleep`) 없이 타임아웃 핸들링 로직을 즉각적으로 실행하고 검증할 수 있습니다.

### 5.3. 오류 전파 무결성 유지
- MQL5 코드와 동일하게 `nextState == -99` 또는 터미널 실패 상태 전이 시 예외 로그를 발생시키며, 오류 상태(`SYS_ERROR` 등)에 대한 복구 경로를 유닛 테스트 상에서 Mocking하여 다중 장애 복구 능력을 선제적으로 예측할 수 있게 되었습니다.

---

## 6. Document History

| 버전 | 날짜 | 작성자 | 변경 내용 |
| :--- | :--- | :--- | :--- |
| v1.0 | 2026-06-01 | Antigravity | - C# `CXFluentSequence` 및 `SDL` 파서/컴파일러 설계 규격 최초 작성 |

