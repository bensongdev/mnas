# AI 에이전트 계약 — macOS 네이티브 앱

## 역할
주어진 수용 기준을 만족하는 가장 작고 안전한 변경을 구현한다. 제품 결정과 승인은 사람이 한다.

## 아키텍처
- 네이티브 SwiftUI를 우선하고, AppKit은 꼭 필요한 곳에만 쓴다.
- 도메인 로직을 뷰와 분리하고, 도메인 동작에 대한 테스트를 추가한다.
- 기존 컴포넌트와 관례를 재사용하고, 추측성 추상화는 피한다.
- 새 패키지 의존성, 권한, entitlement, 네트워크 호출, 영구 데이터 마이그레이션은 트레이드오프를 문서화하고 승인을 요청하기 전에는 추가하지 않는다.
- 비밀 정보나 개인 데이터를 소스 관리, 로그, 스크린샷, 생성된 보고서에 절대 넣지 않는다.

## 제품 명세
- 기능 구현은 `docs/PRODUCT_SPEC.md`가 `scripts/check-spec.sh`를 통과(상태 `승인`, 미결 질문 없음)할 때, 그 명세에 있는 기능(`F-n`)만 한다. 통과하지 못하면 구현하지 않고 이유를 보고한다.
- 명세의 상태를 `승인`으로 바꾸는 것은 사람만 한다. 사람이 명시적으로 "승인"이라고 지시한 경우에만 대신 바꾼다.
- 요구사항이 바뀌면 코드보다 명세를 먼저 고치고(`/spec`), 상태를 `초안`으로 되돌려 재승인을 받는다. 명세를 고치는 단계에서는 코드를 수정하지 않는다.
- 모호한 요구사항은 추측해서 채우지 않고 명세의 미결 질문에 적는다.
- 구현 후 명세에 쓰는 것은 `## 검증 결과`와 해당 기능의 `기능 상태`뿐이다. 수용 기준 체크박스는 사람이 체크한다.

## 완료 정의 (Definition of Done)
1. 구현할 기능이 승인된 명세에 있는지 확인하고, 그 수용 기준(`F-n.AC-n`)을 구현과 테스트의 기준으로 삼는다.
2. 최소한의 변경으로 구현하고, 동작과 회귀를 검증하는 테스트를 포함한다.
3. Xcode가 있는 macOS에서 `scripts/verify.sh all`을 실행한다. 실행할 수 없으면 명시적으로 NOT RUN으로 보고하고, 절대 PASS라고 주장하지 않는다.
4. UI 변경 시 영향을 받는 상태를 UI 테스트로 실행하고, 이름을 붙인 창 스크린샷을 `.keepAlways`로 `.xcresult`에 첨부한다.
5. 첨부물을 추출해 존재 여부뿐 아니라 이미지 자체를 확인한다. 에이전트가 이미지를 볼 수 없으면 HUMAN REVIEW REQUIRED로 표시한다.
6. 최소한 초기 상태, 변경된 상태, 그리고 해당되는 경우 오류/빈 상태의 증거를 확보한다. 기존 UI를 수정할 때는 변경 전/후를 포함한다.
7. 검증 보고서를 제공한다: 변경 사항, 실행한 명령, PASS/FAIL/SKIPPED, 증거 경로, 한계, 위험.
8. 스크린샷만으로 기능의 정확성을 추론하지 않는다. assertion과 테스트 로그로 동작을 입증해야 한다.
9. 결과는 실행 폴더의 `verification.md` 기준으로 보고한다. `전체 결과: PASS`가 아니거나 필요한 항목이 `NOT RUN`이면 완료가 아니다. `화면 검토: PENDING`은 이미지를 확인한 뒤 보고서에서 직접 판정한다.

## 테스트 작성 규칙
- 상태 변화는 먼저 assertion으로 검증하고, 그 다음 스크린샷을 남긴다.
- macOS SwiftUI `Text`의 문자열은 접근성 `value`로 읽는다(`label` 아님). `contains`가 아니라 정확히 일치하는지 비교한다.
- 스크린샷 이름은 `NN-상태-설명` 형식으로 붙인다 (예: `01-initial-launch`, `03-after-increment`). 이 형식이 아닌 첨부는 `verify.sh`가 자동 첨부로 보고 FAIL 처리한다.
- UI 테스트의 디버그 출력은 창 단위(`app.windows.firstMatch.debugDescription`)로 한다. `app.debugDescription`은 메뉴 막대의 최근 항목과 사용자 이름까지 로그에 남긴다.
- 검증 스크립트를 수정하면 통제된 실패(테스트 실패, 컴파일 오류 등)를 주입해 FAIL과 0이 아닌 종료 코드를 확인하고, 주입한 변경은 원상 복구한다.

## 실행 규칙
- 명시적 허락 없이 DerivedData, 아카이브, `.artifacts/runs`의 실행 증거, 사용자 파일, 다른 프로젝트를 삭제하지 않는다. 정리할 때는 `scripts/prune-evidence.sh`로 목록과 크기를 보여 주고 승인을 받는다.
- 8GB RAM / 256GB SSD 기기이므로 시뮬레이터/테스트 세션을 병렬로 실행하지 않는다. `.artifacts/verify.lock`은 실행 중인 검증이 없음을 확인하기 전에는 지우지 않는다.
- `project.yml` 스킴의 녹화 차단 설정(`preferredScreenCaptureFormat: screenshots`, `captureScreenshotsAutomatically: false`, `systemAttachmentLifetime: keepNever`)을 지우지 않는다. 지우면 UI 테스트 실패 시 화면 전체가 녹화되어 증거에 남는다. 녹화가 남은 실행 폴더는 열어 보지 말고 승인을 받아 통째로 지운다.
- `CODE_SIGNING_ALLOWED=NO`를 설정하지 않는다. Apple Silicon에서 UI 테스트 러너가 강제 종료된다. 로컬 ad-hoc 서명(`CODE_SIGN_IDENTITY = -`)을 유지한다.
- 빌드 설정, 타깃, 스킴은 `project.yml`에서만 수정한다. `*.xcodeproj`는 생성물이며 Git에서 제외되고 다시 생성될 때 덮어써진다.
- 앱 이름/Bundle ID 변경은 `scripts/rename-app.sh`로 하고, 타깃 이름 규칙(`<Name>`, `<Name>Tests`, `<Name>UITests`)을 유지한다.
- 새 컴파일러/링커 경고를 만들지 않는다. 경고가 생기면 보고서에 개수와 원인을 적는다.
- 생성된 증거는 프로젝트 소스 폴더가 아닌 `.artifacts/`(gitignore 대상)에 둔다.
- 실패 시 닫힘(fail closed): 검증을 실행하지 못했다면 완료 상태는 UNVERIFIED다.
- 사용자 지시 없이 `git commit`, `git push`, 배포, 공증(notarize)을 실행하지 않는다. 공증은 `scripts/release.sh`로만 하고, 결과는 `.artifacts/releases/<시각>/release-verification.md` 기준으로 보고한다.
- 서명 인증서, 앱 암호, 팀 ID 등 계정 정보를 저장소나 로그에 넣지 않는다. 공증 로그인 정보는 키체인 프로필로만 사용한다.

## 응답 템플릿
- 구현 내용: ...
- 수용 기준: ...
- 검증: build PASS/FAIL/NOT RUN; unit PASS/FAIL/NOT RUN; UI PASS/FAIL/NOT RUN
- 증거: 경로, 화면 이름, `.xcresult`
- 사람 검토: required / approved
- 남은 위험: ...
