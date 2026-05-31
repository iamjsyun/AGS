# PLAN: AGS 프로젝트 폴더 정비 및 빌드 복구 계획서 (v1.0)

**Status**: Proposed  
**Author**: Antigravity  
**Target**: AGS 프로젝트 폴더 구조 (`D:\projects\ags`)  
**Reference**: [DESIGN_AGS_UNIFIED_STRUCTURE_v1.2.md](file:///D:/projects/ags/_doc/DESIGN_AGS_UNIFIED_STRUCTURE_v1.2.md) 및 [GEMINI.md](file:///D:/projects/ags/GEMINI.md)

---

## 1. 개요 (Overview)

본 계획서는 AGS 프로젝트의 폴더 구조를 최신 **Dual-Zone Architecture (v1.2)** 규격에 일치시키고, 현재 발생하고 있는 메인 프로젝트 컴파일 에러를 완벽하게 해결하기 위한 정비 작업 로드맵입니다. 

---

## 2. 현황 분석 및 문제점 (Current Issues)

### 2.1. 소스코드 컴파일 에러
- **원인**: `CXPositionManager.mqh` 파일의 26개 지점에서 포인터 유효성을 검사할 때 `CXLogDispatcher::IsOk(ptr)` 대신 `CXLogDispatcher::Ok(ptr)`를 호출하고 있습니다.
- **영향**: 컴파일러가 이를 `ICXLogger::Ok(ICXParam*, string, ENUM_LOG_POLICY)`로 잘못 매핑하여 매개변수 개수 부족 오류(`error 199`)가 발생하고, 전체 빌드가 실패합니다.

### 2.2. 과거 폴더 구조 잔재 (Leftovers)
- **MT5/Session**: 과거 아키텍처용 폴더로 현재 소스코드는 없고 컴파일 잔재 파일(`test_compilation.ex5`)만 존재합니다.
- **MT5/_Test**: 테스트 도구 컴파일 결과물(`AGSScenarioRunner.ex5`, `AGSTestRunner.ex5`)이 직접 컴파일 폴더가 아닌 이곳으로 출력되었거나 잔재로 남아있습니다.
- **MT5 루트의 AGS.ex5, ATS.ex5**: 메인 EA 컴파일 잔재로, 새 구조에서는 `MT5\04_AppBootstrap\AGS.ex5` 경로에 빌드 결과물이 위치하게 됩니다.

### 2.3. 신규 구조상 미생성 폴더
- **Test/03_Results**: 테스트 수행 보고서 및 DB 스냅샷을 저장할 공간이 아직 생성되지 않았습니다.
- **Test/04_Logs**: 시스템 실행 로그 아카이브 보관 폴더가 누락되어 있습니다.

---

## 3. 정비 작업 단계 (Action Items)

### [Phase 1] 컴파일 오류 수정 및 소스코드 복구
1. **대상 파일**: [CXPositionManager.mqh](file:///D:/projects/ags/MT5/03_Platform/Execution/CXPositionManager.mqh)
2. **조치 사항**: `CXLogDispatcher::Ok` 문자열을 static 헬퍼인 `CXLogDispatcher::IsOk`로 안전하게 치환 (총 26개소).
3. **목적**: 빌드 정합성을 복구하고 100% 성공적인 컴파일 환경 확보.

### [Phase 2] 과거 잔재 폴더 및 이진 파일(Binaries) 제거
1. **대상 폴더 및 파일**:
   - `D:\projects\ags\MT5\Session` 폴더 트리 삭제 (비워진 폴더)
   - `D:\projects\ags\MT5\_Test` 폴더 트리 삭제 (비워진 폴더)
   - `D:\projects\ags\MT5\AGS.ex5` 파일 삭제
   - `D:\projects\ags\MT5\ATS.ex5` 파일 삭제
2. **목적**: `MT5/` 하위를 `01` ~ `99` 번호 매김 계층 폴더들로만 깔끔하게 유지하여 가시성과 이식성 확보.

### [Phase 3] User/Designer Zone 폴더 구조 보강
1. **조치 사항**:
   - `D:\projects\ags\Test\03_Results` 폴더 생성
   - `D:\projects\ags\Test\04_Logs` 폴더 생성
2. **목적**: TSDL 기반 극한 시나리오 테스트 환경의 출력 로그 및 결과 보고서 디렉토리를 표준 규격에 맞게 사전 구축.

### [Phase 4] 빌드 스크립트 실행을 통한 최종 검증
1. **검증 커맨드**:
   - 메인 EA 빌드: `powershell -ExecutionPolicy Bypass -File D:\projects\ags\Automation\Build\bags.ps1`
   - 테스트 러너 빌드: `powershell -ExecutionPolicy Bypass -File D:\projects\ags\Automation\Build\build_tests.ps1`
2. **합격 기준**: 두 스크립트 모두 종료 코드 `0`을 반환하며 빌드에 성공할 것.

---

## 4. 기대 효과 (Expected Outcomes)
- 100% 성공적인 컴파일 및 빌드 빌드 신뢰도 회복.
- 불필요한 빌드 파편과 빈 디렉토리 제거로 소스 보관소 경량화 및 가독성 제고.
- `v1.2` 아키텍처 설계와 로컬 디렉토리 구조의 완벽한 일치화.
