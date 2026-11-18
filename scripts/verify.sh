#!/usr/bin/env bash
# AI 에이전트와 사람이 함께 쓰는 검증 진입점. macOS 기본 /bin/bash 3.2와 호환되어야 한다.
# 종료 코드: 0 = 실행한 검사 모두 통과, 1 = 검사 실패, 2 = 사용법/환경 오류.
# 모드: all(기본) = 린트+빌드+단위 테스트+화면 밖 스냅샷. 마우스·키보드를 쓰지 않는다.
#       full = all + 실제 클릭 UI 테스트, ui = UI 테스트만. 둘 다 마우스·키보드를 조작하므로
#       AI_UI_CONTROL=1 또는 CI=true 일 때만 실행한다.
set -uo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-all}"
if [[ ! "$MODE" =~ ^(build|unit|ui|all|full)$ ]]; then echo "사용법: scripts/verify.sh [build|unit|ui|all|full]" >&2; exit 2; fi
if [[ ("$MODE" == ui || "$MODE" == full) && "${AI_UI_CONTROL:-}" != 1 && "${CI:-}" != true ]]; then
  echo "$MODE 모드는 UI 테스트가 마우스와 키보드를 조작합니다. 테스트 중에는 Mac을 쓸 수 없습니다." >&2
  echo "사람이 허락한 경우에만 실행하세요: AI_UI_CONTROL=1 ./scripts/verify.sh $MODE" >&2
  echo "평소 검사는 화면을 조작하지 않는 ./scripts/verify.sh all 을 쓰고, UI 테스트는 CI에서 확인합니다." >&2
  exit 2
fi
if [[ "$(uname -s)" != "Darwin" ]]; then echo "이 스크립트는 Xcode가 설치된 macOS가 필요합니다" >&2; exit 2; fi
if ! command -v xcodebuild >/dev/null; then echo "xcodebuild가 없습니다: 전체 Xcode를 설치하세요" >&2; exit 2; fi
if [[ ! -f project.yml ]]; then echo "project.yml이 없습니다. 프로젝트 폴더에서 실행하세요" >&2; exit 2; fi

# 이름은 project.yml에서 읽는다(<Name>, <Name>Tests, <Name>UITests). 필요하면 환경 변수로 덮어쓴다.
APP_NAME="${APP_NAME:-$(sed -n 's/^name:[[:space:]]*//p' project.yml | head -1 | tr -d "\"'")}"
if [[ -z "$APP_NAME" ]]; then echo "project.yml에서 'name:'을 읽지 못했습니다" >&2; exit 2; fi
SCHEME="${SCHEME:-$APP_NAME}"
UNIT_TARGET="${UNIT_TARGET:-${APP_NAME}Tests}"
UI_TARGET="${UI_TARGET:-${APP_NAME}UITests}"
PROJECT="$APP_NAME.xcodeproj"

# 검증은 한 번에 하나만: Xcode 빌드/테스트를 병렬로 돌리면 8GB 기기의 메모리가 부족해진다.
mkdir -p .artifacts
LOCK=".artifacts/verify.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  echo "다른 verify.sh가 실행 중입니다($LOCK). 실행 중인 검증이 없다면 이 디렉터리를 지우세요: rmdir $LOCK" >&2; exit 2
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# project.yml이 바뀌었으면 다시 생성해서, 오래된 프로젝트로 검증하는 일이 없게 한다.
if command -v xcodegen >/dev/null; then
  xcodegen generate --use-cache --quiet || { echo "xcodegen generate 실패: project.yml을 확인하세요" >&2; exit 2; }
elif [[ ! -d "$PROJECT" ]]; then
  echo "먼저 scripts/bootstrap.sh를 실행하세요 (xcodegen 필요)" >&2; exit 2
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
RUN=".artifacts/runs/$STAMP"
mkdir -p "$RUN"
printf '%s\n' "$RUN" > .artifacts/latest-run
STATUS=0

LINT="NOT RUN"
if command -v swiftlint >/dev/null; then
  if swiftlint lint --strict --quiet --config .swiftlint.yml >"$RUN/swiftlint.log" 2>&1; then LINT="PASS"
  else LINT="FAIL (swiftlint.log 참고)"; STATUS=1; fi
else
  LINT="NOT RUN (설치: brew install swiftlint)"
fi

RESULT="$RUN/results.xcresult"
DERIVED="${AI_DERIVED_DATA_PATH:-.artifacts/DerivedData}"
mkdir -p "$DERIVED"
ACTION=test
TEST_FILTER=""
case "$MODE" in
  build) ACTION=build ;;
  unit|all) TEST_FILTER="-only-testing:$UNIT_TARGET" ;;
  ui) TEST_FILTER="-only-testing:$UI_TARGET" ;;
esac
# Xcode는 기본적으로 실패한 실행마다 약 190MB의 시스템 진단을 첨부한다. 실패 메시지와 스크린샷은 어느 쪽이든 남는다(
# 화면 녹화는 project.yml 스킴에서 끈다). 까다로운 실패를 조사할 때만
# AI_TEST_DIAGNOSTICS=on-failure 로 켠다.
if [[ "$ACTION" == test ]]; then
  TEST_FILTER="$TEST_FILTER -collect-test-diagnostics ${AI_TEST_DIAGNOSTICS:-never}"
fi
# $TEST_FILTER는 일부러 따옴표 없이 쓴다: bash 3.2에서는 빈 배열이 `set -u`와 충돌한다.
# shellcheck disable=SC2086
xcodebuild "$ACTION" -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath "$DERIVED" \
  -resultBundlePath "$RESULT" $TEST_FILTER >"$RUN/xcodebuild.log" 2>&1
XCODEBUILD_EXIT=$?
if [[ $XCODEBUILD_EXIT -ne 0 ]]; then STATUS=1; fi

# 우리 코드의 컴파일러/링커 경고 (appintentsmetadataprocessor 같은 도구 메시지는 제외).
grep -E ': warning: ' "$RUN/xcodebuild.log" | sort -u >"$RUN/warnings.log"
WARNINGS=$(wc -l <"$RUN/warnings.log" | tr -d ' ')

# test 모드에서는 테스트 실패에도 xcodebuild가 0이 아닌 값으로 끝나므로, 컴파일 실패를 따로 감지한다.
if grep -qE 'The following build commands failed|\*\* BUILD FAILED \*\*|because the build failed' "$RUN/xcodebuild.log"; then
  BUILD="FAIL (xcodebuild.log 참고)"
elif [[ $XCODEBUILD_EXIT -eq 0 ]] || grep -qE "^Testing started|^Test Suite" "$RUN/xcodebuild.log"; then
  BUILD="PASS"
else
  BUILD="FAIL (xcodebuild exit $XCODEBUILD_EXIT)"
fi

# 결과 번들(xcresult)의 합계를 기준으로 삼는다. 읽지 못하면 실패로 처리한다.
TOTALS="NOT RUN (build 모드)"
SUMMARY="$RUN/test-summary.json"
if [[ "$ACTION" == test ]]; then
  if [[ -d "$RESULT" ]] && xcrun xcresulttool get test-results summary --path "$RESULT" >"$SUMMARY" 2>"$RUN/summary.log"; then
    field() { plutil -extract "$1" raw -o - "$SUMMARY" 2>/dev/null || echo "?"; }
    TOTALS="$(field result) (전체 $(field totalTestCount), 통과 $(field passedTests),"
    TOTALS="$TOTALS 실패 $(field failedTests), 건너뜀 $(field skippedTests))"
    if [[ "$(field result)" != Passed || "$(field totalTestCount)" == 0 ]]; then STATUS=1; fi
  else
    TOTALS="FAIL (xcresult를 읽지 못함, summary.log 참고)"; STATUS=1
  fi
fi

# 테스트 번들별 상태: 통과 수는 XCTest 로그("Test Case '-[Bundle.Class test]' passed")에서,
# 실패 수는 xcresult에서 센다. 그래야 "failed" 줄을 남기지 않는 크래시도 실패로 집계된다.
bundle_status() {
  local pass fail
  pass=$(grep -cE "^Test Case '-\[$1\.[^]]+\]' passed" "$RUN/xcodebuild.log")
  fail=$(grep -cE "\"targetName\" : \"$1\"" "$SUMMARY" 2>/dev/null)
  if [[ ${fail:-0} -gt 0 ]]; then echo "FAIL (통과 $pass, 실패 $fail)"
  elif [[ $pass -eq 0 ]]; then echo "FAIL (통과한 테스트 0개)"
  else echo "PASS (통과 $pass)"; fi
}
UNIT="NOT RUN ($MODE 모드)"; UI="NOT RUN ($MODE 모드)"
if [[ "$MODE" == all ]]; then UI="NOT RUN (all 모드는 화면을 조작하지 않음. CI 또는 AI_UI_CONTROL=1 ./scripts/verify.sh full)"; fi
if [[ "$MODE" == unit || "$MODE" == all || "$MODE" == full ]]; then UNIT="$(bundle_status "$UNIT_TARGET")"; fi
if [[ "$MODE" == ui || "$MODE" == full ]]; then UI="$(bundle_status "$UI_TARGET")"; fi
case "$UNIT$UI" in *FAIL*) STATUS=1 ;; esac

# 첨부물을 추출하고 스크린샷을 테스트별로 정리한다: screenshots/<테스트>/<첨부 이름>.png
# 테스트가 이름 규칙(NN-상태-설명)으로 직접 붙인 PNG만 스크린샷으로 인정한다. 그 밖의 첨부(Xcode의 실패
# 화면 녹화, 자동 스크린샷 등)는 화면 전체를 담아 개인 정보가 들어갈 수 있으므로 FAIL로 보고한다.
EXPORT="NOT RUN (테스트를 실행하지 않음)"
SHOTS=()
STRAY=""; STRAY_COUNT=0
if [[ "$ACTION" == test && -d "$RESULT" ]]; then
  ATT="$RUN/attachments"; mkdir -p "$ATT" "$RUN/screenshots"
  if xcrun xcresulttool export attachments --path "$RESULT" --output-path "$ATT" >"$RUN/export.log" 2>&1; then
    MANIFEST="$ATT/manifest.json"; t=0
    while plutil -extract "$t" raw -o - "$MANIFEST" >/dev/null 2>&1; do
      TEST_ID="$(plutil -extract "$t.testIdentifier" raw -o - "$MANIFEST")"
      DIR="$RUN/screenshots/$(printf '%s' "$TEST_ID" | tr '/' '.' | tr -d '()')"
      a=0
      while FILE="$(plutil -extract "$t.attachments.$a.exportedFileName" raw -o - "$MANIFEST" 2>/dev/null)"; do
        NAME="$(plutil -extract "$t.attachments.$a.suggestedHumanReadableName" raw -o - "$MANIFEST")"
        if [[ "$FILE" == *.png && "$NAME" =~ ^[0-9][0-9]-[^/]+$ ]]; then
          mkdir -p "$DIR"
          DEST="$DIR/$(printf '%s' "$NAME" | sed -E 's/_[0-9]+_[0-9A-F-]{36}//')"
          ln -f "$ATT/$FILE" "$DEST" 2>/dev/null || cp "$ATT/$FILE" "$DEST"
          SHOTS+=("${DEST#"$RUN"/}")
        else
          STRAY="${STRAY}- attachments/$FILE ($TEST_ID)"$'\n'; STRAY_COUNT=$((STRAY_COUNT + 1))
        fi
        a=$((a + 1))
      done
      t=$((t + 1))
    done
    EXPORT="EXPORTED (스크린샷 ${#SHOTS[@]}장)"
    if [[ $STRAY_COUNT -gt 0 ]]; then
      EXPORT="FAIL (스크린샷 ${#SHOTS[@]}장, 이름 규칙 밖의 자동 첨부 ${STRAY_COUNT}개: 화면 녹화 등 개인 정보 포함 가능)"; STATUS=1
    fi
    if [[ "$MODE" != unit && ${#SHOTS[@]} -eq 0 ]]; then
      EXPORT="FAIL (스냅샷/UI 테스트가 스크린샷을 남기지 않음)"; STATUS=1
    fi
  else
    EXPORT="FAIL (export.log 참고, xcresult를 Xcode에서 확인)"; STATUS=1
  fi
fi

if [[ $STATUS -eq 0 ]]; then OVERALL=PASS; else OVERALL=FAIL; fi
{
  echo "# 검증 보고서"
  echo
  echo "- 전체 결과: **$OVERALL** (exit $STATUS)"
  echo "- 실행 시각: $STAMP"
  echo "- 모드: $MODE"
  echo "- 앱/스킴: $APP_NAME / $SCHEME"
  echo "- 실행 환경: macOS $(sw_vers -productVersion 2>/dev/null || echo 알 수 없음)"
  echo "- Xcode: $(xcodebuild -version 2>/dev/null | tr '\n' ' ')"
  echo "- 코드 스타일 검사 (swiftlint --strict): $LINT"
  echo "- 빌드: $BUILD"
  echo "- 컴파일러/링커 경고: ${WARNINGS}건 (warnings.log 참고, 실패로 처리하지 않음)"
  echo "- 단위 테스트 ($UNIT_TARGET): $UNIT"
  echo "- UI 테스트 ($UI_TARGET): $UI"
  echo "- xcresult 합계: $TOTALS"
  echo "- 스크린샷 추출: $EXPORT"
  echo "- 화면 검토: PENDING (스크린샷을 직접 열어 확인하세요. 파일이 있다고 화면이 정상인 것은 아닙니다)"
  echo "- 검증하지 않은 것: 다른 기기에서의 동작, 권한, 배포/공증"
  if [[ -f "$RUN/test-summary.json" ]] && plutil -extract testFailures.0 raw -o - "$RUN/test-summary.json" >/dev/null 2>&1; then
    echo
    echo "## 실패한 테스트"
    f=0
    while plutil -extract "testFailures.$f" raw -o - "$RUN/test-summary.json" >/dev/null 2>&1; do
      echo "- $(plutil -extract "testFailures.$f.testIdentifierString" raw -o - "$RUN/test-summary.json"):" \
        "$(plutil -extract "testFailures.$f.failureText" raw -o - "$RUN/test-summary.json")"
      f=$((f + 1))
    done
  fi
  if [[ $STRAY_COUNT -gt 0 ]]; then
    echo
    echo "## 자동 첨부 (FAIL)"
    echo "Xcode가 자동으로 만든 첨부(실패 시 화면 녹화, 자동 스크린샷 등)이거나 이름 규칙(NN-상태-설명)을 따르지 않는 첨부입니다."
    echo "화면 전체가 담겨 다른 앱의 개인 정보가 들어 있을 수 있습니다. results.xcresult 안에도 같은 내용이 있습니다."
    echo "열어 보기 전에 project.yml 스킴의 녹화 설정을 확인하고, 이 실행 폴더는 사람의 승인을 받아 통째로 지우세요."
    printf '%s' "$STRAY"
  fi
  if [[ ${#SHOTS[@]} -gt 0 ]]; then
    echo
    echo "## 스크린샷 (테스트별)"
    for s in "${SHOTS[@]}"; do echo "- $s"; done
  fi
  echo
  echo "## 파일"
  echo "- xcodebuild.log, warnings.log, swiftlint.log"
  echo "- results.xcresult, test-summary.json, attachments/ (테스트를 실행한 경우)"
  echo
  echo "## 사람 검토 체크리스트"
  echo "- [ ] 필요한 상태가 모두 캡처되어 있고 열어 볼 수 있다"
  echo "- [ ] 잘림, 겹침, 깨진 글자가 없다"
  echo "- [ ] 동작이 이미지뿐 아니라 assertion과 로그로 입증된다"
  echo "- [ ] 증거에 비밀 정보나 개인 정보가 없다"
} > "$RUN/verification.md"
printf '\n보고서: %s/verification.md\n' "$RUN"
cat "$RUN/verification.md"
exit "$STATUS"
