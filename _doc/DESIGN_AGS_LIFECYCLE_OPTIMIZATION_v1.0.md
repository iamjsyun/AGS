# AGS Lifecycle Optimization Design Review (v1.0)

## Document History
| Version | Date | Description | Author |
| :--- | :--- | :--- | :--- |
| v1.0 | 2026-06-01 | Initial architectural analysis and complexity reduction design report | Gemini CLI |

---

## 1. 개요 (Overview)
본 문서는 AGS 엔진의 부팅부터 청산까지의 라이프사이클을 정밀 분석하고, 현재 시스템의 복잡도 병목 지점을 식별하여 이를 해결하기 위한 고도화 설계안을 제시합니다.

## 2. 현재 구조 분석 (Complexity Hotspots)
| 프로세스 단계 | 핵심 컴포넌트 | 현재 복잡도 원인 |
| :--- | :--- | :--- |
| **부팅 및 검증** | `CXAppService`, `CXIntegrityGuard` | 수많은 서비스(14개 이상)의 수동 등록 및 소유권 관리의 모호함. |
| **신호 감지** | `CXSignalWatcher`, `CXFluentSequence` | DB 스캔과 시퀀스 전이가 단일 루프 내에서 밀접하게 결합됨. |
| **진입 및 주문** | `CXAssetManager`, `CXOrderManager` | 가격 계산, DB 고정, 주문 발송이 비선형적으로 얽혀 있음. |
| **포지션 관리** | `CXSessionTask`, `CXTaskTrail_*` | 틱 단위의 미세한 상태 전이가 루프 내에서 반복 실행됨 (CPU 부하). |
| **청산 처리** | `CXExitManager`, `CXTaskExit_*` | 물리 자산 삭제와 DB 데이터 정리 간의 비동기적 정합성 보장 필요. |

## 3. 고도화 설계안 (Proposed Solutions)
### 2.1. [부팅] 서비스 자동 등록 (Service Auto-Registry)
* **개선**: `CXServiceFactory`가 `Context` 객체를 통째로 빌드하여 반환하는 **'Assembly' 패턴** 도입.
* **효과**: 부팅 로직 코드 간결화 및 설정 누락 원천 차단.

### 2.2. [신호] 이벤트 기반 감지 (Event-Driven Detection)
* **개선**: 주기적 DB 스캔 방식에서 DB 변경 감지 시 즉시 이벤트를 발생시키는 **'Signal Dispatcher'** 도입.
* **효과**: 응답 속도 향상 및 불필요한 루프 오버헤드 제거.

### 2.3. [진입/청산] 원자적 트랜잭션 래퍼 (Atomic Transaction Wrapper)
* **개선**: 복잡한 실행 절차를 `CXTransaction` 클래스로 캡슐화 (`Begin` -> `Execute` -> `Commit`).
* **효과**: 상태 일관성 확보 및 롤백 제어 용이성.

### 2.4. [포지션] 상태 머신 최적화 (State Machine Flattening)
* **개선**: `CXFluentSequence` 내의 분기 로직을 **'State Handler Map'** 구조로 단순화.
* **효과**: 실행 성능 최적화 및 상태 관리 가독성 확보.

## 4. 고도화된 계층 구조 매핑
| 레벨 | 개선된 구조 | 역할 및 책임 |
| :--- | :--- | :--- |
| **System** | `AGS_Kernel` | 서비스 조립 및 전체 무결성 감시 (Guard 연동) |
| **Stage** | `ExecutionStage` | 진입/관리/청산의 거시적 단계 제어 |
| **Sequence** | `LogicStream` | 단계 내의 비즈니스 규칙 흐름 정의 (DSL 기반) |
| **Task** | `AtomicTask` | 단일 행위(주문 전송, SL 계산 등) 수행 |
| **Function** | `PureLogic` | 수학적 계산 및 단순 판별 (State-less) |

## 5. 결론 및 향후 계획
AGS는 '구조적 선언' 중심의 설계를 통해 절차적 복잡도를 제거해야 합니다. 본 보고서에 따라 부팅 로직 리팩토링(Assembly Pattern)부터 순차적으로 고도화를 진행할 것을 제안합니다.
