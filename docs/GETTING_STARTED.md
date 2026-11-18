# 처음 시작하는 사람을 위한 안내서

개발을 해 본 적이 없어도 이 문서를 위에서부터 차례대로 따라 하면 됩니다.
모르는 단어가 나오면 맨 아래 [용어 사전](#9-용어-사전)을 보세요.

> 이 문서의 명령어 결과는 2026-11-18, macOS 26.6.2 · Xcode 27.0 · MacBook Air(M1, 8GB)에서 실제로 실행해 확인했습니다.
> 단, 설치 단계(2장)는 이미 도구가 설치된 Mac에서 작성했기 때문에, 처음부터 따라 해 보며 확인하지는 못했습니다. 막히는 곳이 있으면 알려 주세요.

---

## 1. 이 시스템은 무엇을 해 주나요?

Mac에서 돌아가는 앱을 **AI에게 만들게 하고, 제대로 만들었는지 자동으로 검사한 뒤, 마지막으로 내가 눈으로 확인하는** 작업 틀입니다.

```
 ① 내가 원하는 기능을 글로 적는다
        ↓
 ② AI 에이전트가 코드를 고친다
        ↓
 ③ 검사 스크립트(verify.sh)가 자동으로
    - 코드 스타일 검사
    - 앱 빌드(실행 파일 만들기)
    - 자동 테스트 실행
    - 앱 화면을 실제로 띄워 버튼을 눌러 보고 스크린샷 저장
        ↓
 ④ 결과 보고서(verification.md)와 스크린샷이 만들어진다
        ↓
 ⑤ 내가 보고서와 스크린샷을 보고 승인한다
```

핵심은 **AI가 "다 됐어요"라고 말하는 것을 그대로 믿지 않는다**는 점입니다. 검사 스크립트가 실제로 실행한 결과와 스크린샷이 증거가 됩니다.

지금 들어 있는 앱은 연습용 예제입니다. 숫자를 보여 주고 `Increment`(1 올리기)와 `Reset`(0으로 되돌리기) 버튼이 있습니다.

---

## 2. 준비하기 (처음 한 번만)

전체 1~2시간 정도 걸립니다. 대부분은 Xcode 다운로드를 기다리는 시간입니다.

### 2-1. 필요한 것
- Apple Silicon(M1 이상) 또는 Intel Mac
- 디스크 여유 공간 **20GB 이상** 권장 (Xcode 설치 과정에서 공간을 많이 씁니다)
- 인터넷 연결, Mac 로그인 비밀번호(관리자 권한)

### 2-2. 터미널 열기
터미널은 글자로 Mac에 명령을 내리는 프로그램입니다.

1. `⌘ + Space`를 눌러 Spotlight를 엽니다.
2. `터미널` 또는 `Terminal`을 입력하고 Enter를 누릅니다.
3. 검은색(또는 흰색) 창에 `사용자이름@컴퓨터이름 ~ %` 같은 글자가 보이면 준비된 것입니다.

> 이 문서의 회색 상자 안 명령어는 **한 줄씩 복사해서 터미널에 붙여 넣고 Enter**를 누르면 됩니다.
> 비밀번호를 물어보면 Mac 로그인 비밀번호를 입력합니다. 입력해도 화면에 아무것도 표시되지 않는 것이 정상입니다.

### 2-3. Xcode 설치
Xcode는 Apple이 만든 Mac/iPhone 앱 개발 도구입니다.

1. **App Store**를 열고 `Xcode`를 검색해 설치합니다. (용량이 커서 오래 걸립니다)
2. 설치가 끝나면 Xcode를 **한 번 실행**합니다. 추가 구성 요소 설치 창이 나오면 기본값으로 설치합니다. `macOS` 플랫폼만 있으면 되고, iOS 시뮬레이터는 필요 없습니다.
3. Xcode를 닫고 터미널에서 다음 두 줄을 실행합니다.

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

4. 확인:
```bash
xcodebuild -version
```
`Xcode 27.0` 처럼 버전이 나오면 성공입니다. (숫자는 달라도 괜찮습니다)

### 2-4. Homebrew 설치
Homebrew는 개발 도구를 명령어 한 줄로 설치하게 해 주는 프로그램입니다. 이미 있다면 건너뜁니다.

```bash
brew --version
```
`Homebrew 4.x` 같은 버전이 나오면 이미 설치된 것입니다. `command not found`가 나오면 [brew.sh](https://brew.sh/ko/) 첫 화면의 설치 명령을 복사해 실행하세요.

설치가 끝나면 마지막에 **"Next steps"** 아래에 2~3줄의 명령어가 나옵니다. **그 명령어들을 그대로 복사해 실행해야** `brew` 명령을 쓸 수 있습니다. 그 뒤 터미널을 닫았다가 다시 열고 `brew --version`으로 확인합니다.

### 2-5. 필요한 도구 두 개 설치
```bash
brew install xcodegen swiftlint
```
- **XcodeGen**: 설정 파일(`project.yml`)로 Xcode 프로젝트를 자동으로 만들어 줍니다.
- **SwiftLint**: 코드 스타일을 검사합니다.

확인:
```bash
xcodegen --version
swiftlint version
```
둘 다 버전 숫자가 나오면 준비 끝입니다.

### 2-6. 프로젝트 폴더 놓을 위치
이 프로젝트 폴더는 **홈 폴더 바로 아래**(예: `/Users/내이름/mac-native-ai-system`)에 두는 것을 권장합니다.
iCloud로 동기화되는 `데스크탑`이나 `문서` 폴더에 두면, 빌드할 때 생기는 큰 파일이 계속 동기화되어 느려질 수 있습니다.

---

## 3. 처음 실행해 보기

### 3-1. 프로젝트 폴더로 이동
```bash
cd ~/mac-native-ai-system
```
> 폴더 위치가 다르다면 `cd ` (cd와 공백)까지 입력한 뒤, Finder에서 프로젝트 폴더를 터미널 창으로 끌어다 놓고 Enter를 누르세요. 경로가 자동으로 입력됩니다.

### 3-2. 프로젝트 만들기
```bash
./scripts/bootstrap.sh
```
정상이면 마지막에 이렇게 나옵니다.
```
Created project at /Users/.../mac-native-ai-system/NativeStarter.xcodeproj

NativeStarter.xcodeproj 생성 완료. 다음 단계: ./scripts/verify.sh all
```
여러 번 실행해도 괜찮습니다. 매번 같은 결과가 나옵니다.

### 3-3. 전체 검사 실행
```bash
./scripts/verify.sh all
```
- 1~3분 걸립니다. **처음 한 번은 더 오래** 걸립니다.
- 중간에 **앱 창이 저절로 열리고 버튼이 눌렸다가 닫힙니다.** 자동 테스트가 화면을 조작하는 것이니 정상입니다. 이때 **마우스와 키보드를 건드리지 마세요.** 건드리면 테스트가 실패할 수 있습니다.
- 테스트 중 화면에 **'자동화 실행 중'** 표시가 나타나는 것도 정상입니다. 프로그램이 마우스와 키보드를 대신 조작하고 있음을 알리려고 macOS가 직접 띄우는 보안 표시이며, 테스트가 끝나면 사라집니다. 스크린샷에는 찍히지 않습니다.
- 처음에는 macOS가 **"손쉬운 사용(접근성)" 또는 자동화 권한**을 요청하거나 비밀번호를 물어볼 수 있습니다. 허용해 주세요.

끝나면 결과 보고서가 화면에 출력됩니다. 맨 위에 다음 줄이 보이면 성공입니다.
```
- 전체 결과: **PASS** (exit 0)
```

### 3-4. Xcode로 열어 보기 (선택)
```bash
open NativeStarter.xcodeproj
```
Xcode 창 왼쪽 위의 ▶ 버튼을 누르면 앱이 실행됩니다. 코드를 직접 보고 싶을 때만 쓰면 되고, 검사는 `verify.sh`가 합니다.

> Xcode에서 프로젝트 설정을 바꾸지는 마세요. 설정은 `project.yml`에서 관리하고, Xcode에서 바꾼 설정은 다음 실행 때 사라집니다.

---

## 4. 결과 확인하기

### 4-1. 결과 폴더 열기
결과는 프로젝트 안의 `.artifacts` 폴더에 저장됩니다. 이름이 점(`.`)으로 시작하는 폴더는 Finder에서 **숨겨져** 있습니다.

가장 쉬운 방법은 터미널에서 다음 명령을 실행하는 것입니다. 마지막 검사 결과 폴더가 Finder로 열립니다.
```bash
open "$(cat .artifacts/latest-run)"
```
Finder에서 숨김 폴더를 보고 싶으면 프로젝트 폴더에서 `⌘ + ⇧ + .`(Command + Shift + 마침표)를 누르세요.

### 4-2. 결과 폴더 안에 있는 것
| 이름 | 무엇인가요 | 꼭 봐야 하나요 |
|---|---|---|
| `verification.md` | 검사 결과 요약 보고서 | **예** |
| `screenshots/` | 테스트 중에 찍은 앱 화면 | **예** |
| `xcodebuild.log` | 빌드와 테스트의 전체 기록 | 실패했을 때 |
| `swiftlint.log` | 코드 스타일 검사 기록 | 코드 스타일 검사가 FAIL일 때 |
| `warnings.log` | 경고 목록 | 경고 수가 0이 아닐 때 |
| `results.xcresult` | Xcode용 상세 결과 (더블클릭하면 Xcode에서 열림) | 깊이 조사할 때 |
| `attachments/`, `test-summary.json` | 원본 자료 | 거의 안 봄 |

### 4-3. `verification.md` 읽는 법
실제 결과 예시입니다.
```
- 전체 결과: **PASS** (exit 0)            ← 가장 중요
- 모드: all                               ← 어떤 검사를 했는지
- 코드 스타일 검사 (swiftlint --strict): PASS
- 빌드: PASS                              ← 앱이 만들어졌는지
- 컴파일러/링커 경고: 0건 (...)           ← 경고 수 (실패는 아님)
- 단위 테스트 (NativeStarterTests): PASS (통과 6)   ← 계산 로직 테스트
- UI 테스트 (NativeStarterUITests): PASS (통과 2)   ← 화면 조작 테스트
- xcresult 합계: Passed (전체 8, 통과 8, 실패 0, 건너뜀 0)
- 스크린샷 추출: EXPORTED (스크린샷 4장)
- 화면 검토: PENDING (...)                ← 스크린샷을 아직 사람이 안 봤다는 뜻
```
- **PASS**: 실제로 실행했고 통과함
- **FAIL**: 실행했는데 실패함. 아래에 `## 실패한 테스트`가 있으면 무엇이 실패했는지 적혀 있습니다.
- **NOT RUN**: 실행하지 않음. 통과가 **아닙니다**.

`화면 검토: PENDING`은 항상 이렇게 나옵니다. 스크립트는 그림을 판단할 수 없기 때문에, 스크린샷은 **사람이 직접 열어 봐야** 합니다.

### 4-4. 스크린샷 확인
`screenshots/` 안에 테스트 이름으로 된 폴더가 있고, 그 안에 번호 순서대로 그림이 있습니다.

| 파일 | 기대하는 화면 |
|---|---|
| `01-initial-launch.png` | 앱을 처음 켰을 때 `Count: 0` |
| `02-before-increment.png` | 버튼 누르기 직전 `Count: 0` (01과 같아 보이는 것이 정상) |
| `03-after-increment.png` | Increment 두 번 누른 후 `Count: 2` |
| `04-after-reset.png` | Reset 누른 후 `Count: 0` |

볼 것: 글자가 잘리거나 겹치지 않았는지, 깨진 글자가 없는지, 버튼이 제자리에 있는지, 숫자가 위 표와 같은지.

---

## 5. AI에게 첫 기능 시켜 보기

AI 코딩 에이전트(예: Claude Code)를 이 프로젝트 폴더에서 실행합니다. 설치 방법은 각 도구의 공식 안내를 따르세요.
에이전트는 프로젝트의 `AGENTS.md`를 읽고 그 규칙(검사 실행, 거짓 보고 금지, 커밋 금지 등)을 따릅니다.

이 시스템에서는 AI가 바로 코드를 고치지 않고 **명세 → 사람 승인 → 구현** 순서로 일합니다.
명세는 "무엇을 만들고 어떻게 확인할지"를 적은 문서(`docs/PRODUCT_SPEC.md`)입니다. AI가 쓰고, 사람이 읽고 승인합니다.

### 연습 예제: 숫자를 1 내리는 버튼 추가
**1단계 — 요구사항 말하기.** Claude Code에서 이렇게 입력합니다.

> /spec Reset 버튼 왼쪽에 숫자를 1 내리는 Decrement 버튼을 추가해 줘. 숫자는 0보다 작아지지 않아야 해.

AI가 `docs/PRODUCT_SPEC.md`를 만들고(코드는 아직 건드리지 않음) 기능 번호(예: `F-1`), 수용 기준, 미결 질문을 알려 줍니다.

**2단계 — 명세 읽고 승인하기.** `docs/PRODUCT_SPEC.md`를 열어 봅니다.
- 수용 기준이 내가 원하는 동작과 같은지 확인합니다. 다르면 직접 고치거나 AI에게 "AC-2는 이렇게 바꿔 줘"라고 말합니다.
- "미결 질문"에 답합니다. 답을 AI에게 말하면 명세에 반영해 줍니다. 질문이 다 정리되면 `- 없음`이 됩니다.
- 마음에 들면 맨 위 `- 상태: 초안`을 `- 상태: 승인`으로 직접 바꿉니다.

**3단계 — 구현 시키기.**

> /implement F-1

AI는 먼저 명세가 승인됐는지 검사하고, 승인되지 않았으면 구현하지 않고 멈춥니다. 승인됐다면 구현하고 `verify.sh all`을 실행한 뒤, 명세의 "검증 결과"에 결과를 적어 줍니다.

Claude Code가 아닌 AI 도구에서는 `/spec`, `/implement` 대신 [README 4절](../README.md#4-ai-에이전트-사용법-명세--승인--구현)의 요청 문장을 쓰세요.

### 에이전트가 끝났다고 하면 확인할 것
1. 에이전트가 알려 준 결과 폴더의 `verification.md`에서 `전체 결과: **PASS**`인지
2. Unit/UI 테스트 개수가 **늘었는지** (새 기능의 테스트가 실제로 추가됐다는 뜻)
3. 새 스크린샷에 Decrement 버튼이 보이고, 숫자가 기대대로 바뀌었는지
4. 명세의 "검증 결과"에서 수용 기준마다 PASS인지. 확인했으면 수용 기준의 `- [ ]`를 `- [x]`로 직접 체크

하나라도 이상하면 그 내용을 그대로 에이전트에게 말하면 됩니다. 예: "03 스크린샷에서 Decrement 버튼 글자가 잘려 보여. 고쳐 줘."

---

## 6. 자주 쓰는 명령어

모두 프로젝트 폴더에서 실행합니다. (`cd ~/mac-native-ai-system` 먼저)

| 명령어 | 하는 일 | 걸리는 시간 |
|---|---|---|
| `./scripts/verify.sh all` | 전체 검사 (보통 이것만 쓰면 됨) | 1~3분 |
| `./scripts/verify.sh build` | 빌드만 확인 | 수십 초 |
| `./scripts/verify.sh unit` | 계산 로직 테스트만 | 수십 초 |
| `./scripts/verify.sh ui` | 화면 테스트 + 스크린샷만 | 1~2분 |
| `./scripts/prune-evidence.sh` | 쌓인 결과 폴더 목록과 크기 보기 (삭제하지 않음) | 즉시 |
| `./scripts/bootstrap.sh` | Xcode 프로젝트 다시 만들기 | 수 초 |
| `./scripts/check-spec.sh docs/PRODUCT_SPEC.md` | 명세가 승인됐는지, 빠진 칸이 없는지 검사 | 즉시 |

검사는 **한 번에 하나만** 실행하세요. 동시에 실행하면 메모리가 부족해지므로 스크립트가 두 번째 실행을 막습니다.

---

## 7. 문제가 생겼을 때

| 화면에 나온 메시지 | 원인 | 해결 |
|---|---|---|
| `zsh: command not found: brew` | Homebrew 설치 후 "Next steps" 명령을 실행하지 않음 | 2-4의 "Next steps" 명령을 실행하고 터미널을 다시 열기 |
| `XcodeGen을 설치하세요: brew install xcodegen` | XcodeGen 미설치 | `brew install xcodegen` |
| `전체 Xcode를 설치하고 선택하세요: ...` 또는 `xcrun: error: invalid active developer path` | Xcode가 없거나 선택되지 않음 | 2-3의 `sudo xcode-select ...` 실행 |
| `You have not agreed to the Xcode license` | 라이선스 미동의 | `sudo xcodebuild -license accept` |
| `permission denied: ./scripts/verify.sh` | 압축 파일로 받으면서 실행 권한이 사라짐 | `chmod +x scripts/*.sh` |
| `no such file or directory: ./scripts/...` | 프로젝트 폴더가 아닌 곳에서 실행 | 3-1의 `cd` 다시 하기 |
| `다른 verify.sh가 실행 중입니다` | 다른 검사가 실행 중이거나, 이전 검사가 중간에 강제 종료됨 | 실행 중인 검사가 정말 없으면 `rmdir .artifacts/verify.lock` 후 다시 실행 |
| `코드 스타일 검사 ...: FAIL` | 코드 스타일 규칙 위반 | 결과 폴더의 `swiftlint.log`에서 파일과 줄 번호 확인. 에이전트에게 "swiftlint.log의 위반을 고쳐 줘" |
| `UI 테스트 ...: FAIL` 인데 코드를 바꾼 적 없음 | 테스트 중 마우스를 움직였거나 권한을 거부함 | 손대지 않고 다시 실행. 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 Xcode 관련 항목 허용 |
| `빌드: FAIL` | 코드에 오류가 있음 | `xcodebuild.log`에서 `error:`를 검색. 에이전트에게 로그와 함께 전달 |
| 디스크 공간 부족 | 결과 폴더와 빌드 캐시가 쌓임 | `./scripts/prune-evidence.sh`로 크기 확인 후, 확인한 오래된 결과 폴더만 직접 삭제 |

그래도 안 되면 결과 폴더의 `verification.md`와 `xcodebuild.log`를 에이전트에게 보여 주고 "원인을 찾아 줘"라고 요청하세요.

---

## 8. 다음 단계

- 내 앱 시작하기: Claude Code에서 `/new-app 만들고 싶은 앱 설명`을 입력하면 AI가 `~/app-specs/앱이름/PRODUCT_SPEC.md`에 명세를 씁니다. 읽고 승인한 뒤 터미널에서 `new-mac-app --spec ~/app-specs/앱이름/PRODUCT_SPEC.md`를 실행하면 홈 폴더에 새 프로젝트가 만들어집니다. 그 폴더에서 `./scripts/verify.sh all`, 그다음 `/implement F-1`부터 진행하세요. (처음 한 번 설치가 필요합니다.) 자세한 내용은 [README의 '다른 앱에 재사용'](../README.md#5-다른-앱에-재사용)을 보세요.
- 다른 사람에게 앱 나눠 주기 (Apple 개발자 계정 필요): [README의 '배포' 절](../README.md#8-배포-developer-id-서명과-apple-공증)
- 더 자세한 동작 원리, 저장 공간 관리, 한계: [README.md](../README.md)
- AI 에이전트가 지키는 규칙: [AGENTS.md](../AGENTS.md)

---

## 9. 용어 사전

| 용어 | 뜻 |
|---|---|
| 터미널 | 글자로 Mac에 명령을 내리는 프로그램 |
| 명령어 / 스크립트 | 터미널에 입력하는 지시 / 여러 명령을 묶어 둔 파일 (`scripts/` 폴더) |
| Xcode | Apple의 앱 개발 프로그램 |
| Swift / SwiftUI | Apple 앱을 만드는 프로그래밍 언어 / 화면을 만드는 방법 |
| 빌드 | 코드를 실행 가능한 앱으로 만드는 과정 |
| 테스트 | 코드가 의도대로 동작하는지 자동으로 확인하는 작은 프로그램 |
| 단위 테스트 (Unit test) | 계산 같은 로직만 따로 확인하는 테스트. 빠름 |
| UI 테스트 | 실제로 앱을 띄워 버튼을 누르며 확인하는 테스트 |
| 명세 (제품 명세) | 무엇을 만들고 어떻게 확인할지 적은 문서 (`docs/PRODUCT_SPEC.md`). AI가 쓰고 사람이 승인 |
| 수용 기준 | "이렇게 되면 완성"이라는 조건. `F-1.AC-1`처럼 번호가 붙고 각각 테스트로 확인 |
| assertion | 테스트 안의 "이 값은 반드시 이래야 한다"는 확인 문장. 틀리면 테스트 실패 |
| Lint / SwiftLint | 코드 스타일과 흔한 실수를 검사하는 도구 |
| 경고 (warning) | 앱은 만들어지지만 고치는 게 좋은 부분 |
| XcodeGen / `project.yml` | 설정 파일 하나로 Xcode 프로젝트를 만들어 주는 도구 / 그 설정 파일 |
| `.xcodeproj` | Xcode 프로젝트 파일. 여기서는 자동 생성되므로 직접 고치지 않음 |
| 스킴 (scheme), 타깃 (target) | Xcode에서 "무엇을 어떻게 빌드/테스트할지" 정하는 단위 |
| 번들 ID (Bundle ID) | 앱의 고유 이름. 예: `com.example.NativeStarter` |
| DerivedData | 빌드 중간 결과물을 모아 두는 캐시 폴더. 지워도 다시 빌드하면 생김 |
| `.xcresult` | Xcode 테스트 결과 파일 |
| 코드 서명 (ad-hoc) | 앱에 서명을 붙이는 과정. 개발 중에는 내 Mac에서만 실행하는 간단한 서명을 씀 |
| Developer ID / 공증 | 다른 Mac에 배포하기 위한 Apple 인증 서명 / Apple이 앱을 검사해 안전하다고 확인해 주는 절차 |
| Gatekeeper | 인터넷에서 받은 앱을 실행 전에 검사하는 macOS 보안 기능 |
| App Sandbox | 앱이 허락된 범위 밖의 파일·기능에 접근하지 못하게 막는 macOS 보안 장치 |
| AI 에이전트 | 지시를 받아 직접 파일을 고치고 명령을 실행하는 AI 도구 |
| 커밋 (commit) / Git | 변경 내용을 저장 기록으로 남기는 것 / 그 기록을 관리하는 도구 |
| 종료 코드 (exit code) | 명령이 끝날 때 남기는 숫자. 0은 성공, 그 외는 실패 |
