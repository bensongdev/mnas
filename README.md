# macOS Native AI Development System

**macOS 네이티브 SwiftUI 앱을 위한 AI 구현 → 빌드 → 테스트 → 스크린샷 증거 → 사람 승인 템플릿**

> **개발이 처음이라면 [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)부터 읽으세요.** 설치부터 첫 실행, 결과 확인, AI에게 첫 기능을 시키는 방법까지 차례대로 설명합니다. 이 README는 이미 익숙한 사람을 위한 참조 문서입니다.

> 상태: 2026-11-18 macOS 26.6.2 / Xcode 27.0 / Apple Silicon(M1, 8GB)에서 `scripts/verify.sh all` 실행 검증(빌드·린트·단위·UI 테스트·스크린샷). 다른 Xcode 버전에서는 첫 실행 시 다시 검증하세요.

## 0. 준비
- 호환되는 **전체 Xcode**가 설치된 macOS (Command Line Tools만으로는 부족). 앱은 macOS 13+를 지원하지만 테스트 실행에는 macOS 14+가 필요합니다.
- Homebrew (설치된 경우)
- `brew install xcodegen swiftlint`
- Xcode 라이선스 수락, `xcode-select`가 Xcode를 가리키도록 설정

## 1. 시작
```bash
cd mac-native-ai-system
./scripts/bootstrap.sh
open NativeStarter.xcodeproj   # 이름을 바꿨다면 <Name>.xcodeproj
./scripts/verify.sh all
```

`*.xcodeproj`는 `project.yml`에서 생성되는 파일이라 Git에 올리지 않습니다(`.gitignore`). 빌드 설정과 타깃은 Xcode가 아니라 `project.yml`에서 수정하세요. Xcode에서 바꾼 설정은 다음 `bootstrap.sh`/`verify.sh` 실행 때 덮어써집니다.

**처음 테스트할 때 macOS 접근성/UI 자동화 권한 요청이 표시될 수 있습니다.** UI 테스트 중에는 앱 창이 화면에 나타나 클릭되므로 마우스/키보드를 건드리지 마세요. 해당 권한이 없거나 CI가 GUI 세션을 제공하지 않으면 UI 테스트가 실패할 수 있습니다. 이 경우 원인을 보고하고, 테스트를 건너뛴 상태를 PASS로 간주하지 마세요.

## 2. 실행 결과
`.artifacts/`는 이름이 점으로 시작하므로 Finder와 `ls`에서 기본적으로 숨겨집니다.
- Finder: 프로젝트 폴더에서 `⌘ + ⇧ + .` 를 누르면 숨김 항목이 표시됩니다 (다시 누르면 숨김).
- 터미널: `open .artifacts` 또는 최신 실행 폴더를 바로 열려면 `open "$(cat .artifacts/latest-run)"`
- 목록 확인: `ls -a`, 실행별 크기/결과는 `./scripts/prune-evidence.sh`

실행마다 `.artifacts/runs/YYYYMMDD-HHMMSS/` 폴더가 만들어지고, 그 안에 다음 파일이 생깁니다.
- `verification.md`: 항목별 결과와 사람 검토 체크리스트
- `xcodebuild.log`: 빌드 및 XCTest 로그
- `results.xcresult`: Xcode 테스트 결과 및 스크린샷 첨부물
- `attachments/`: `xcresulttool`로 추출한 원본 첨부물과 `manifest.json` (실패 시 화면 녹화 mp4 포함)
- `screenshots/<테스트 번들>.<테스트명>/<첨부 이름>.png`: 테스트 이름별로 정리한 스크린샷
- `test-summary.json`: xcresult 기준 테스트 합계와 실패 메시지
- `warnings.log`: 컴파일러/링커 경고 (개수는 보고서에 표시, 실패 처리하지 않음)

`.artifacts/latest-run`에는 마지막 실행 폴더 경로가 기록됩니다.

`verification.md`에는 린트, 빌드, 단위 테스트, UI 테스트, xcresult 합계, 스크린샷 수가 각각 PASS/FAIL/NOT RUN으로 기록됩니다. 다음 경우는 모두 **FAIL(종료 코드 1)** 입니다: 린트 위반, 컴파일 실패, 테스트 실패/크래시, 실행된 테스트 0개, xcresult 판독 불가, UI 모드인데 스크린샷 0장. 잘못된 인자, 환경 오류, 동시 실행은 종료 코드 2입니다.

검증 종료 코드가 0이어도 **스크린샷은 사람이 직접 확인해야 합니다.** 화면이 정상이라고 자동 승인한 것이 아닙니다.

## 3. 명령어
```bash
./scripts/verify.sh build   # 빌드 (UI 화면 캡처 없음)
./scripts/verify.sh unit    # 단위 테스트만
./scripts/verify.sh ui      # UI 테스트 + 스크린샷 첨부
./scripts/verify.sh all     # 전체 테스트
./scripts/prune-evidence.sh # 실행별 크기/결과 목록만 표시 (삭제하지 않음)
./scripts/rename-app.sh MyApp com.mycompany  # 복제한 템플릿의 앱 이름/번들 ID 변경
```

`verify.sh`는 실행할 때마다 `xcodegen generate --use-cache`로 `project.yml` 변경을 반영하고, `.artifacts/verify.lock`으로 동시 실행을 막습니다. 비정상 종료로 잠금이 남으면 실행 중인 검증이 없는지 확인한 뒤 해당 디렉터리를 지우세요.

`AI_DERIVED_DATA_PATH=/Volumes/ExternalSSD/BuildCache ./scripts/verify.sh all` 로 빌드 캐시를 외장 SSD에 둘 수도 있습니다. 외장 SSD를 이동/제거하면 빌드 캐시 경로가 유효하지 않을 수 있습니다.

## 4. AI 에이전트 사용법
`AGENTS.md`를 프로젝트 루트에 둡니다. 에이전트에게 다음 메시지를 줍니다.

> docs/FEATURE_TEMPLATE.md에 수용 기준을 정리한 후 기능을 구현해. 완료 시 scripts/verify.sh all을 실행하고, 영향 받은 화면의 UI 테스트 스크린샷과 verification.md를 제출해. 실행할 수 없는 검증은 NOT RUN으로 보고하고 성공했다고 주장하지 마. .artifacts의 이미지도 직접 확인해 문제를 보고해. 커밋/푸시는 하지 마.

UI 기능을 추가할 때는 `AppUITests/<Name>UITests.swift`에서 화면 이동 및 스크린샷 시점을 확장하세요. 기본 테스트는 카운터의 최초 실행/증가 전/증가 후/초기화 후 상태를 캡처합니다.
- 스크린샷은 `capture("NN-상태-설명")` 형식으로 이름을 붙입니다 (예: `01-initial-launch`, `03-after-increment`). 이 이름이 `screenshots/` 아래 파일명이 됩니다.
- macOS에서 SwiftUI `Text`의 문자열은 접근성 `label`이 아니라 `value`로 노출됩니다. 테스트의 `text(of:)` 도우미를 사용하고, `contains` 대신 정확히 일치하는지 비교하세요.
- 상태 변화는 반드시 assertion으로 검증하고, 스크린샷은 그 뒤에 증거로 남깁니다.

## 5. 다른 앱에 재사용
1. 디렉터리를 복제합니다 (`.artifacts/`와 `*.xcodeproj`는 복사하지 않아도 됩니다).
2. `./scripts/rename-app.sh MyApp com.mycompany` 를 실행합니다. `project.yml`, Swift 파일 내용/파일명(`@testable import` 포함)을 바꾸고 아무것도 삭제하지 않습니다. 번들 ID는 `<bundleIdPrefix>.<타깃명>`으로 생성됩니다.
   기존 `NativeStarter.xcodeproj`는 남겨 두므로, 새 이름으로 빌드되는 것을 확인한 뒤 직접 지우세요.
   스크립트는 `project.yml`의 `name:`에서 scheme(`<Name>`)과 테스트 번들(`<Name>Tests`, `<Name>UITests`)을 읽습니다. 이 규칙을 벗어나면 `SCHEME`, `UNIT_TARGET`, `UI_TARGET` 환경 변수로 지정하세요.
3. `App/`에 실제 코드와 모델을 넣고, `AppTests`/`AppUITests`에 각 기능의 테스트를 작성합니다.
4. 요구사항은 `docs/FEATURE_TEMPLATE.md`에서 시작합니다.
5. `scripts/verify.sh all` 실행 결과와 화면 증거를 승인합니다.

## 6. 공간 관리 (8GB/256GB 맥북)
- 기본 빌드 캐시는 `.artifacts/DerivedData/`로 격리됩니다 (약 140MB).
- 성공한 `all` 실행은 약 1MB, 실패한 실행은 약 8MB입니다. Xcode 기본값은 실패할 때마다 약 190MB의 시스템 진단을 첨부하므로 `verify.sh`는 이를 끕니다 (`-collect-test-diagnostics never`). 필요하면 `AI_TEST_DIAGNOSTICS=on-failure ./scripts/verify.sh ui`로 켜세요.
- 한 번에 하나의 검증만 실행됩니다 (잠금). Xcode GUI 빌드와 동시에 실행하지 마세요.
- `.artifacts/`는 Git에 올라가지 않습니다. 저장 공간이 부족하면 **확인한 특정 실행 폴더**와 해당 프로젝트 빌드 캐시를 수동 삭제하세요.
- 결과 번들과 이미지가 빠르게 누적될 수 있으므로 오래된 실행을 선별 정리하세요.
- macOS 네이티브 앱은 iOS Simulator Runtime 설치가 필요하지 않습니다.

## 7. 증거 해석과 한계
- `전체 결과: PASS`는 해당 `모드`에서 실행한 모든 검사(린트, 빌드, 테스트, 스크린샷 추출)가 통과했다는 뜻입니다. `NOT RUN` 항목은 검증되지 않은 것입니다.
- 보고서의 `화면 검토: PENDING`은 스크립트가 바꾸지 않습니다. 이미지를 직접 확인한 사람(또는 이미지를 볼 수 있는 에이전트)이 판정합니다.
- 스크린샷은 모양/상태 증거입니다. 기능의 정확성은 assertion 및 로그로 확인합니다.
- UI 자동화는 접근성 및 실행 환경에 영향을 받습니다. CI는 기본적으로 **단위 테스트만** 수행합니다. UI 테스트는 로컬 GUI 세션에서 실행을 권장합니다. `.github/workflows/verify.yml`은 2026-11-18 GitHub macos-15 러너(macOS 15.8.2, Xcode 16.4)에서 단위 테스트 6개 PASS를 확인했습니다.
- 코드 서명은 로컬 ad-hoc(`CODE_SIGN_IDENTITY = -`, 팀/인증서 불필요)입니다. Apple Silicon은 서명되지 않은 UI 테스트 러너를 종료시키므로 `CODE_SIGNING_ALLOWED=NO`를 쓰지 마세요. ad-hoc 서명으로 App Sandbox 권한이 실제로 적용됩니다. 배포용 Developer ID 서명/공증은 별도 설정과 검증이 필요합니다.
- 테스트 타깃만 macOS 14.0으로 빌드합니다 (현재 XCTest가 14.0+용). 앱의 최소 지원 버전은 13.0이지만 macOS 13 실기기에서는 검증하지 않았습니다.
- 개인정보, 인증 토큰, 사용자가 실제 작성한 문서가 화면에 노출되면 캡처를 공유하지 마세요.
