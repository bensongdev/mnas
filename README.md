# macOS Native AI Development System

**macOS 네이티브 SwiftUI 앱을 위한 AI 구현 → 빌드 → 테스트 → 스크린샷 증거 → 사람 승인 템플릿**

> **개발이 처음이라면 [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)부터 읽으세요.** 설치부터 첫 실행, 결과 확인, AI에게 첫 기능을 시키는 방법까지 차례대로 설명합니다. 이 README는 이미 익숙한 사람을 위한 참조 문서입니다.

> 상태: 2026-11-18 macOS 26.6.2 / Xcode 27.0 / Apple Silicon(M1, 8GB)에서 `scripts/verify.sh all`(빌드·린트·단위 테스트·화면 밖 스냅샷)과 `full`(+ 실제 클릭 UI 테스트) 실행 검증. 다른 Xcode 버전에서는 첫 실행 시 다시 검증하세요.

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

**`verify.sh all`은 마우스·키보드를 쓰지 않습니다.** 화면 증거는 SwiftUI 화면을 창에 띄우지 않고 메모리에서 그리는 스냅샷 테스트(`AppTests/SnapshotTestCase.swift`)로 남기고, 단위 테스트가 앱을 호스트로 실행할 때도 창을 띄우거나 앞으로 나오지 않습니다(`App/NativeStarterApp.swift`의 `AppEntry`). 그래서 작업하면서 검증을 돌려도 됩니다.

실제 클릭 흐름을 확인하는 UI 테스트(`AppUITests`)는 앱 창을 띄우고 마우스·키보드를 조작합니다. macOS에는 화면 없는(headless) UI 테스트가 없기 때문입니다. 그래서 UI 테스트는 **GitHub CI에서 push/PR마다 실행**하고(`full` 모드), 로컬에서는 사람이 허락할 때만 `AI_UI_CONTROL=1 ./scripts/verify.sh full`로 실행합니다. 이 변수 없이 `ui`/`full`을 실행하면 스크립트가 거부합니다(종료 코드 2). 로컬 UI 테스트를 처음 실행하면 macOS 접근성/UI 자동화 권한 요청이 표시될 수 있습니다.

## 2. 실행 결과
`.artifacts/`는 이름이 점으로 시작하므로 Finder와 `ls`에서 기본적으로 숨겨집니다.
- Finder: 프로젝트 폴더에서 `⌘ + ⇧ + .` 를 누르면 숨김 항목이 표시됩니다 (다시 누르면 숨김).
- 터미널: `open .artifacts` 또는 최신 실행 폴더를 바로 열려면 `open "$(cat .artifacts/latest-run)"`
- 목록 확인: `ls -a`, 실행별 크기/결과는 `./scripts/prune-evidence.sh`

실행마다 `.artifacts/runs/YYYYMMDD-HHMMSS/` 폴더가 만들어지고, 그 안에 다음 파일이 생깁니다.
- `verification.md`: 항목별 결과와 사람 검토 체크리스트
- `xcodebuild.log`: 빌드 및 XCTest 로그
- `results.xcresult`: Xcode 테스트 결과 및 스크린샷 첨부물
- `attachments/`: `xcresulttool`로 추출한 원본 첨부물과 `manifest.json`
- `screenshots/<테스트 번들>.<테스트명>/<첨부 이름>.png`: 테스트 이름별로 정리한 스크린샷
- `test-summary.json`: xcresult 기준 테스트 합계와 실패 메시지
- `warnings.log`: 컴파일러/링커 경고 (개수는 보고서에 표시, 실패 처리하지 않음)

`.artifacts/latest-run`에는 마지막 실행 폴더 경로가 기록됩니다.

`verification.md`에는 린트, 빌드, 단위 테스트, UI 테스트, xcresult 합계, 스크린샷 수가 각각 PASS/FAIL/NOT RUN으로 기록됩니다. 다음 경우는 모두 **FAIL(종료 코드 1)** 입니다: 린트 위반, 컴파일 실패, 테스트 실패/크래시, 실행된 테스트 0개, xcresult 판독 불가, `all`/`ui`/`full` 모드인데 스크린샷 0장, 빈 화면 스냅샷, 이름 규칙 밖의 자동 첨부(화면 녹화 등). 잘못된 인자, 환경 오류, 동시 실행은 종료 코드 2입니다.

검증 종료 코드가 0이어도 **스크린샷은 사람이 직접 확인해야 합니다.** 화면이 정상이라고 자동 승인한 것이 아닙니다.

## 3. 명령어
```bash
./scripts/verify.sh all     # 기본: 린트 + 빌드 + 단위 테스트 + 화면 밖 스냅샷 (화면 조작 없음)
./scripts/verify.sh build   # 빌드만
./scripts/verify.sh unit    # 단위 테스트만 (스냅샷 포함, 스크린샷 수 검사 안 함)
AI_UI_CONTROL=1 ./scripts/verify.sh full  # all + 실제 클릭 UI 테스트 (마우스·키보드 사용, CI 기본)
AI_UI_CONTROL=1 ./scripts/verify.sh ui    # UI 테스트만 (마우스·키보드 사용)
./scripts/prune-evidence.sh # 실행별 크기/결과 목록만 표시 (삭제하지 않음)
./scripts/check-spec.sh docs/PRODUCT_SPEC.md  # 명세 승인/형식 검사 (4절)
./scripts/new-project.sh --spec <명세.md>     # 승인된 명세로 새 프로젝트 만들기 (5절)
./scripts/new-project.sh MyApp com.mycompany  # 이름만 정해 새 프로젝트 만들기
./scripts/rename-app.sh MyApp com.mycompany  # 현재 폴더의 앱 이름/번들 ID 변경
```

`verify.sh`는 실행할 때마다 `xcodegen generate --use-cache`로 `project.yml` 변경을 반영하고, `.artifacts/verify.lock`으로 동시 실행을 막습니다. 비정상 종료로 잠금이 남으면 실행 중인 검증이 없는지 확인한 뒤 해당 디렉터리를 지우세요.

`AI_DERIVED_DATA_PATH=/Volumes/ExternalSSD/BuildCache ./scripts/verify.sh all` 로 빌드 캐시를 외장 SSD에 둘 수도 있습니다. 외장 SSD를 이동/제거하면 빌드 캐시 경로가 유효하지 않을 수 있습니다.

## 4. AI 에이전트 사용법: 명세 → 승인 → 구현
기능은 사람이 승인한 제품 명세(`docs/PRODUCT_SPEC.md`)에 있는 것만 구현합니다. Claude Code에서는 다음 명령을 씁니다.

| 단계 | 누가 | 명령 / 할 일 |
|---|---|---|
| 1. 명세 초안 | AI | 새 앱: `/new-app <요구사항>` (5절) · 기존 프로젝트의 변경: `/spec <바뀐 요구사항>` |
| 2. 검토·승인 | 사람 | 명세를 읽고 고친 뒤 `- 상태: 초안` → `- 상태: 승인`, 미결 질문은 `- 없음` |
| 3. 구현·검증 | AI | `/implement F-1` → 승인 검사(`check-spec.sh`) 통과 시에만 구현, `verify.sh all`, 명세에 검증 결과 기록 |
| 4. 최종 판정 | 사람 | `verification.md`와 스크린샷 확인, 수용 기준 체크박스 체크 |

- 명세 형식은 `docs/PRODUCT_SPEC_TEMPLATE.md`입니다. 기능은 `F-1`, 수용 기준은 `F-1.AC-1`처럼 번호를 붙이고, 모든 수용 기준은 테스트 계획 표에 연결되어야 합니다.
- `./scripts/check-spec.sh docs/PRODUCT_SPEC.md`가 승인 여부와 형식을 검사합니다(통과 0, 문제 1, 사용법 오류 2). `--draft`는 초안의 형식만 봅니다.
- Claude Code가 아닌 에이전트에는 다음처럼 요청합니다.

> docs/PRODUCT_SPEC.md의 F-1을 구현해. 먼저 scripts/check-spec.sh docs/PRODUCT_SPEC.md 를 실행해서 통과하지 않으면 멈춰. 완료 시 scripts/verify.sh all을 실행하고, 스크린샷을 직접 확인한 뒤 명세의 검증 결과를 채워. 실행할 수 없는 검증은 NOT RUN으로 보고하고 성공했다고 주장하지 마. 커밋/푸시는 하지 마.

화면 상태의 증거는 `AppTests`의 스냅샷 테스트로 남깁니다. 뷰가 원하는 상태를 생성자로 받게 하고(예: `ContentView(initialCount: 2)`), assertion 뒤에 `snapshot(뷰, name: "02-count-2")`를 부릅니다. 빈 화면으로 그려지면 테스트가 실패합니다. 실제 클릭 흐름은 `AppUITests/<Name>UITests.swift`에 작성하며 CI에서 실행됩니다. 기본 UI 테스트는 카운터의 최초 실행/증가 전/증가 후/초기화 후 상태를 캡처합니다.
- 스크린샷은 `capture("NN-상태-설명")` 형식으로 이름을 붙입니다 (예: `01-initial-launch`, `03-after-increment`). 이 이름이 `screenshots/` 아래 파일명이 됩니다.
- macOS에서 SwiftUI `Text`의 문자열은 접근성 `label`이 아니라 `value`로 노출됩니다. 테스트의 `text(of:)` 도우미를 사용하고, `contains` 대신 정확히 일치하는지 비교하세요.
- 상태 변화는 반드시 assertion으로 검증하고, 스크린샷은 그 뒤에 증거로 남깁니다.

## 5. 다른 앱에 재사용
1. **권장: 명세부터 만들고 프로젝트를 만듭니다.**
   ```text
   /new-app 할 일 목록 앱. 마감일이 지나면 빨간색으로 표시해 줘
   ```
   Claude Code에서 아무 폴더에서나 실행하면 `~/app-specs/<앱이름>/PRODUCT_SPEC.md`에 명세 초안이 생깁니다(프로젝트는 아직 만들지 않음). 명세를 검토해 상태를 `승인`으로 바꾼 뒤:
   ```bash
   new-mac-app --spec ~/app-specs/<앱이름>/PRODUCT_SPEC.md
   ```
   명세 검사를 통과해야만 만들어지고, 명세의 앱 이름·번들 ID 접두사·최소 macOS 버전이 적용되며 명세는 `docs/PRODUCT_SPEC.md`로 복사됩니다. 그 다음은 4절의 `/implement F-1`부터입니다.

   `/new-app`은 사용자 전역 스킬이라 한 번 설치해야 합니다.
   ```bash
   mkdir -p ~/.claude/skills
   ln -s "$PWD/claude/global-skills/new-app" ~/.claude/skills/new-app
   ```
   이름과 번들 ID만 정해 바로 만들 수도 있습니다.
   ```bash
   ./scripts/new-project.sh MyApp com.mycompany            # 홈 폴더에 ~/MyApp 생성
   ./scripts/new-project.sh MyApp com.mycompany ~/Dev/MyApp # 만들 폴더 지정
   ```
   마지막 커밋의 파일만 복사하고(`.artifacts/`, `*.xcodeproj`, 커밋하지 않은 변경은 제외), 앱 이름과 번들 ID를 바꾸고, `git init`과 Xcode 프로젝트 생성까지 합니다. 커밋은 하지 않습니다. 이미 있는 폴더에는 만들지 않습니다.

   어느 폴더에서든 `new-mac-app MyApp com.mycompany`로 쓰려면 한 번만 설치합니다.
   ```bash
   mkdir -p ~/.local/bin
   ln -s "$PWD/scripts/new-project.sh" ~/.local/bin/new-mac-app
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc   # 이미 PATH에 있으면 생략
   ```
   링크는 이 템플릿 폴더를 가리키므로 템플릿 폴더를 옮기면 다시 설치해야 합니다.
2. 직접 복사한 폴더라면 `./scripts/rename-app.sh MyApp com.mycompany` 로 이름만 바꿀 수 있습니다(`new-project.sh`가 내부에서 쓰는 스크립트). `project.yml`, Swift 파일 내용/파일명(`@testable import` 포함)을 바꾸고 아무것도 삭제하지 않습니다. 번들 ID는 `<bundleIdPrefix>.<타깃명>`으로 생성됩니다.
   기존 `NativeStarter.xcodeproj`는 남겨 두므로, 새 이름으로 빌드되는 것을 확인한 뒤 직접 지우세요.
   스크립트는 `project.yml`의 `name:`에서 scheme(`<Name>`)과 테스트 번들(`<Name>Tests`, `<Name>UITests`)을 읽습니다. 이 규칙을 벗어나면 `SCHEME`, `UNIT_TARGET`, `UI_TARGET` 환경 변수로 지정하세요.
3. `App/`에 실제 코드와 모델을 넣고, `AppTests`/`AppUITests`에 각 기능의 테스트를 작성합니다.
4. 요구사항은 `docs/PRODUCT_SPEC.md`에 둡니다 (명세 없이 만들었다면 `/spec`이 템플릿에서 만들어 줍니다).
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
- 스냅샷은 화면 밖에서 그린 이미지라 실제 창의 테두리, 포커스, 클릭 반응은 담지 않습니다. 그 부분은 UI 테스트가 확인합니다.
- UI 자동화는 접근성 및 실행 환경에 영향을 받습니다. CI(`.github/workflows/verify.yml`)는 push/PR마다 `verify.sh full`(단위 + 스냅샷 + UI 테스트)을 실행하고, `verification.md`를 GitHub 실행 요약에 표시하며 스크린샷을 아티팩트(7일)로 올립니다.
- 코드 서명은 로컬 ad-hoc(`CODE_SIGN_IDENTITY = -`, 팀/인증서 불필요)입니다. Apple Silicon은 서명되지 않은 UI 테스트 러너를 종료시키므로 `CODE_SIGNING_ALLOWED=NO`를 쓰지 마세요. ad-hoc 서명으로 App Sandbox 권한이 실제로 적용됩니다. 배포용 Developer ID 서명과 공증은 `scripts/release.sh`가 담당합니다 (8절).
- 테스트 타깃만 macOS 14.0으로 빌드합니다 (현재 XCTest가 14.0+용). 앱의 최소 지원 버전은 13.0이지만 macOS 13 실기기에서는 검증하지 않았습니다.
- 개인정보, 인증 토큰, 사용자가 실제 작성한 문서가 화면에 노출되면 캡처를 공유하지 마세요.
- Xcode는 기본값으로 UI 테스트가 실패하면 **화면 전체**를 녹화해 `.xcresult`에 넣습니다. 다른 앱의 개인 정보가 증거에 남으므로 `project.yml` 스킴에서 녹화와 자동 첨부를 끕니다(`preferredScreenCaptureFormat: screenshots`, `systemAttachmentLifetime: keepNever`). 테스트가 직접 붙인 창 스크린샷은 그대로 남습니다. 그래도 이름 규칙(`NN-상태-설명`) 밖의 첨부(녹화 등)가 나오면 `verify.sh`가 `## 자동 첨부 (FAIL)`로 보고하고 실패 처리합니다. 그런 실행 폴더는 열어 보지 말고 통째로 지우세요(2026-11-18, macOS 26.6.2, Xcode 27.0에서 설정 유무로 녹화 0개/2개 확인).

## 8. 배포: Developer ID 서명과 Apple 공증
이 템플릿으로 만든 앱을 다른 사람의 Mac에서 경고 없이 실행되도록 배포할 때 씁니다. 앱을 Apple 서버로 보내는 외부 작업이므로 평소 검증(`verify.sh`)과 분리되어 있고, 배포할 때만 실행합니다. 예제 앱(NativeStarter)은 배포 대상이 아니므로 공증하지 않습니다.

**준비 (한 번만)**
- 키체인에 `Developer ID Application` 인증서 (Apple Developer 계정에서 발급, `security find-identity -v -p codesigning`으로 확인)
- 공증용 로그인 정보를 키체인에 저장합니다 (Mac마다 한 번이며, 이 템플릿으로 만든 모든 프로젝트가 같이 씁니다). 비밀번호 칸에는 [appleid.apple.com](https://appleid.apple.com)에서 만든 **앱 암호**를 입력합니다.
  ```bash
  xcrun notarytool store-credentials "mac-native-ai-notary" --apple-id <애플ID> --team-id <팀ID>
  ```
  계정 정보는 키체인에만 저장되고 저장소에는 들어가지 않습니다. 팀 ID는 스크립트가 인증서 이름에서 읽습니다.
  이 명령은 **macOS 터미널 앱에서 직접** 실행하세요. AI 에이전트 대화창의 셸 실행 기능(예: Claude Code의 `!`)은 숨김 암호 입력을 제대로 전달하지 못해, 올바른 앱 암호도 `401 Invalid credentials`로 실패할 수 있습니다.
  저장 확인: `xcrun notarytool history --keychain-profile "mac-native-ai-notary"` (기록 조회만 하며 업로드하지 않음)

**실행**
```bash
./scripts/release.sh --sign-only   # 1~3단계만: Apple로 보내지 않고 서명까지 점검 (계정 정보 불필요)
./scripts/release.sh               # 전체: 서명 → 공증 → staple → 배포 검증
```
1. `verify.sh all` 사전 검증 (실패하면 배포하지 않음)
2. Release 아카이브(`xcodebuild archive`) → Developer ID로 내보내기(`-exportArchive`, method `developer-id`). Xcode가 배포용으로 다시 서명하며 디버그 권한만 빼고 앱의 권한은 유지합니다.
3. 서명 검사: 유효성, Developer ID, 타임스탬프, Hardened Runtime, 디버그 권한(`get-task-allow`) 없음, **개발 빌드에 있던 권한(예: App Sandbox)이 배포 빌드에서 빠지지 않았는지**
4. Apple 공증 제출 후 결과 대기 (보통 수 분)
5. 공증 티켓 첨부 (`stapler`)
6. Gatekeeper 배포 검증 (`spctl`의 `Notarized Developer ID`, `syspolicy_check distribution`)
7. 배포 파일 `<Name>-<버전>.zip` 생성

결과는 `.artifacts/releases/<시각>/`에 저장됩니다. `release-verification.md`(단계별 PASS/FAIL/NOT RUN), `.xcarchive`(크래시 분석용 dSYM 포함), 공증 로그(`notary-log.json`), 서명 정보, 배포 zip이 들어 있습니다. 한 단계라도 실패하면 즉시 멈추고 종료 코드 1을 반환합니다.

- 버전은 `project.yml`의 `MARKETING_VERSION`(표시 버전)과 `CURRENT_PROJECT_VERSION`(빌드 번호)에서 바꿉니다.
- 실제 배포 전에는 번들 ID 접두사를 본인 도메인으로 바꾸세요 (`rename-app.sh`). `com.example`로도 공증은 됩니다.
- 처음 서명할 때 macOS가 "codesign이 키체인의 키에 접근하려고 합니다"라고 물으면 **항상 허용**을 선택하세요.
- 환경 변수: `NOTARY_PROFILE`(프로필 이름, 기본 `mac-native-ai-notary`), `SIGN_IDENTITY`(Developer ID 인증서가 여러 개일 때).
- 검증 상태: 2026-11-18 예제 앱으로 `--sign-only`(1~3단계)를 실제 실행해 PASS를 확인했습니다. 4~7단계(공증, staple, Gatekeeper)는 첫 실제 배포 때 처음 실행되므로, 그 결과 보고서를 꼭 확인하세요.
- 공증할 때마다 앱이 Apple로 전송되고 계정에 제출 기록이 남습니다. CI 자동 공증은 인증서와 계정 정보를 GitHub Secrets에 올려야 하므로 설정하지 않았습니다.
