# [Design] AGS 프로젝트 폴더 구조 재배치 설계서 (v1.0)

**Status**: Proposed  
**Author**: Antigravity  
**Target**: MQL5 표준 규격(Standard Layout)에 정렬하고, 핵심 런타임과 테스트 인프라를 엄격히 격리하며 아키텍처적 맥락(Context)을 직관화함.

---

## 1. 개요 (Overview)

현재 AGS 프로젝트는 `MT5/` 루트 하위에 핵심 아키텍처(`Core`, `Engine`), 구체적인 런타임 구현체(`Service`), 오케스트레이터 및 태스크(`Workflow`), 그리고 테스트 인프라(`_Test`)가 수평적으로 공존하고 있습니다. 

이는 다음과 같은 문제점을 낳습니다:
1.  **MQL5 표준 배포판 호환성 부족**: 메타에디터/MT5 단말의 표준 디렉토리 구조(`MQL5\Experts`, `MQL5\Include`, `MQL5\Files`)로 이식하거나 배포할 때 물리적 수동 매핑 공수가 발생합니다.
2.  **배포 코드와 테스트 인프라 혼재**: 실 배포에 불필요한 가상 시나리오 러너 및 Mocks가 배포 경로상에 노출됩니다.
3.  **의존성 흐름 시각화 방해**: 인프라적 요소(Core)와 비즈니스 도메인 정책(Engine), 제어 제어부(Workflow)의 계층 구조가 불분명합니다.

---

## 2. 재배치 설계 원칙 (Design Principles)

1.  **MQL5 Standard Alignment (표준 지향)**: 단말에 복사-붙여넣기(Copy & Paste) 만으로 즉시 작동하도록 물리 폴더 구성을 MT5 표준 구조에 매핑합니다.
2.  **Core-Testing Decoupling (격리)**: 컴파일 및 배포 시 테스트 모듈(`_Test`)을 완전히 물리적으로 제외시킬 수 있는 환경을 만듭니다.
3.  **Strict Layering (엄격한 계층화)**: 
    - **Infrastructure Layer (Core)**: 플랫폼 기본 라이브러리 및 데이터 운반체
    - **Domain/Engine Layer (Engine)**: 거래 가격, 리스크 검증 등 비즈니스 코어 정책
    - **Execution Layer (Service)**: 브로커 실행 및 단말 물리 자산 인터페이스
    - **Orchestration Layer (Workflow)**: 시퀀스 조립 및 상태 전이 실행 흐름

---

## 3. 제안 폴더 구조 (Proposed Folder Tree)

```text
AGS/  (Project Root)
├── _doc/                   # 설계 공유 문서 (디자인 아티팩트)
├── _log/                   # 컴파일 및 빌드 결과 로그
├── build/                  # 빌드 보조 스크립트 및 환경 구성 (bags.ps1, cags.ps1 등)
│
├── Experts/                # MT5 Experts 배포본 위치 (MQL5/Experts)
│   ├── AGS/                # 실배포용 AGS 상용 EA
│   │   └── AGS.mq5         # 메인 엔진 엔트리 포인트
│   └── Test/               # 테스트용 전용 EA
│       ├── AGSTestRunner.mq5
│       └── CXScenarioRunner.mq5
│
├── Include/                # 모든 공통 라이브러리 소스코드 (MQL5/Include)
│   └── AGS/
│       ├── Core/           # L1. 인프라 기반 레이어 (UDP, Context, Base Classes)
│       │   ├── DB/         # SQLite DB 및 Repository 인터페이스/구현
│       │   ├── Defines/    # 공통 ID 매니저, 데이터 타입 정의
│       │   ├── Guard/      # DI 및 엔진 자폭 방지 검증 모듈
│       │   ├── Interfaces/ # 모든 공통 추상 인터페이스
│       │   ├── Logger/     # 디스패처, 파일, 원격, 탭 로거 시스템
│       │   ├── Macros/     # 프레임워크 전역 매크로 (CXMacros.mqh 등)
│       │   ├── Models/     # 기본 DTO 모델 (CXConfig, CXParam 등)
│       │   └── UI/         # UI 드로잉 및 차트 비주얼라이저
│       │
│       ├── Engine/         # L2. 비즈니스 도메인 정책 서비스 (SSOC)
│       │   ├── Price/      # 시장가 보정, SL/TP 진입 가격 산출기
│       │   ├── Risk/       # 증거금, 최대 로트, 위험가드 필터
│       │   └── Symbol/     # Digits, Point 등 심볼 속성 캐싱 조회기
│       │
│       ├── Service/        # L3. 물리 단말 집행 및 자산 인벤토리 레이어
│       │   ├── App/        # App 서비스 라이프사이클 관리
│       │   ├── Execution/  # 오더 진입, 수정, 삭제 물리 집행기
│       │   ├── Session/    # 자산 세션 생성 및 스캐너, 역주입 관리
│       │   └── Watcher/    # 진입/청산 신호 감지기
│       │
│       ├── Workflow/       # L4. 시퀀스 조립 및 상태 전이 실행 흐름
│       │   ├── Orchestration/ # Stage/Task 팩토리 및 Orchestrator
│       │   ├── Session/    # 복합 스테이지 및 런타임 세션 제어
│       │   └── Tasks/      # 마이크로 태스크 모음 (IntentWatch, Align 등)
│       │
│       └── Test/           # L5. 테스트 모의 프레임워크 (테스트 컴파일 시에만 사용)
│           ├── Mocks/      # Mock 데이터베이스, 터미널 플랫폼
│           ├── Scenarios/  # TSDL Loader, Parser, Virtual Pricer
│           └── UnitTests/  # 정적 단위 테스트 스위트 파일들
│
└── Files/                  # 로컬 가상 샌드박스 데이터 (MQL5/Files)
    └── ATSE/               # 극한 테스트용 12종 TSDL 시나리오 스크립트 모음
```

---

## 4. 구조 변경 대비 매핑 가이드 (Migration Path)

폴더가 이동하더라도 소스코드 내 `#include` 지시자의 상대 경로 및 컴파일러 절대 참조가 깨지지 않도록 하기 위해 다음 조치를 단계별로 밟습니다.

1.  ** include 경로 표준화**:
    - 기존: `#include "..\..\Core\Interfaces\IXTask.mqh"` (상대 경로 복잡화)
    - 개선: `#include <AGS\Core\Interfaces\IXTask.mqh>` 와 같이 메타에디터 Include 루트 폴더를 기준으로 꺽쇠괄호(`< >`) 절대경로 포맷을 적용하여 물리적 폴더가 이동하더라도 include가 안전하게 유지되도록 고도화합니다.
2.  **가상 테스트 파일 공간 표준화**:
    - 테스트 시나리오 스크립트들의 저장소를 가상 단말 경로인 `Files\ATSE\` 내부로 일관화하고, 샌드박스 설정(`InpUseCommonPath`)에 정렬하여 이식성을 확보합니다.

---

## 5. 기대 효과 (Benefits)

1.  **배포 단순성**: `Experts/` 및 `Include/`의 하위 내용만 MetaTrader 5 설치 폴더 내에 통째로 덮어쓰는 것으로 로컬 배포가 1초 만에 완료됩니다.
2.  **모듈성 강화**: L1~L5의 계층 구분이 폴더 트리상에서 명확히 드러남으로써, 신규 인프라 확장(L1)이나 비즈니스 정책 수정(L2) 시 작업 공간이 철저하게 정렬됩니다.
3.  **테스트 격리**: 실 배포물에서 `Include/AGS/Test/` 만 누락시킨 상태로 컴파일하더라도 컴파일 정합성이 전혀 깨지지 않는 **테스트 격리 아키텍처**를 완성할 수 있습니다.
