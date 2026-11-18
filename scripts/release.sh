#!/usr/bin/env bash
# Developer ID 서명 → Apple 공증 → staple → 배포 검증까지 수행한다. macOS 기본 /bin/bash 3.2와 호환되어야 한다.
# 앱을 Apple 서버로 전송하는 외부 작업이므로 사용자가 지시했을 때만 실행한다.
# 종료 코드: 0 = 모든 단계 통과, 1 = 단계 실패, 2 = 사용법/환경/준비물 오류.
#
# 사용법: scripts/release.sh            전체 (서명 → 공증 → staple → 배포 검증)
#         scripts/release.sh --sign-only  ①~③만 (Apple로 전송하지 않고 서명까지만 검사)
#
# 준비(한 번만): xcrun notarytool store-credentials "mac-native-ai-notary" --apple-id <애플ID> --team-id <팀ID>
# 환경 변수(선택):
#   NOTARY_PROFILE  키체인에 저장한 notarytool 프로필 이름 (기본: mac-native-ai-notary)
#   SIGN_IDENTITY   서명 인증서 이름. 없으면 키체인에서 "Developer ID Application" 인증서를 하나 찾아 쓴다.
set -uo pipefail
cd "$(dirname "$0")/.."
SIGN_ONLY=0
case "${1:-}" in
  "") ;;
  --sign-only) SIGN_ONLY=1 ;;
  *) echo "사용법: scripts/release.sh [--sign-only]" >&2; exit 2 ;;
esac
if [[ "$(uname -s)" != "Darwin" ]]; then echo "이 스크립트는 Xcode가 설치된 macOS가 필요합니다" >&2; exit 2; fi

APP_NAME="$(sed -n 's/^name:[[:space:]]*//p' project.yml | head -1 | tr -d "\"'")"
if [[ -z "$APP_NAME" ]]; then echo "project.yml에서 'name:'을 읽지 못했습니다" >&2; exit 2; fi
NOTARY_PROFILE="${NOTARY_PROFILE:-mac-native-ai-notary}"

# 서명 인증서: 지정하지 않았으면 Developer ID Application 인증서가 정확히 하나일 때만 자동 선택한다.
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  IDS="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p')"
  if [[ -z "$IDS" ]]; then echo "키체인에 'Developer ID Application' 인증서가 없습니다" >&2; exit 2; fi
  if [[ $(printf '%s\n' "$IDS" | wc -l) -gt 1 ]]; then
    echo "Developer ID 인증서가 여러 개입니다. SIGN_IDENTITY로 하나를 지정하세요:" >&2; printf '  %s\n' "$IDS" >&2; exit 2
  fi
  SIGN_IDENTITY="$IDS"
fi
TEAM_ID="$(printf '%s' "$SIGN_IDENTITY" | sed -n 's/.*(\([A-Z0-9]\{10\}\))$/\1/p')"
if [[ -z "$TEAM_ID" ]]; then echo "인증서 이름에서 팀 ID를 읽지 못했습니다: $SIGN_IDENTITY" >&2; exit 2; fi

# 공증 프로필이 키체인에 있는지 먼저 확인한다 (Apple 서버에 조회).
if [[ $SIGN_ONLY -eq 0 ]] && ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "notarytool 프로필 '$NOTARY_PROFILE'을 쓸 수 없습니다. 먼저 다음을 실행하세요:" >&2
  echo "  xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --apple-id <애플ID> --team-id $TEAM_ID" >&2
  exit 2
fi

mkdir -p .artifacts
LOCK=".artifacts/release.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  echo "다른 release.sh가 실행 중입니다($LOCK). 실행 중인 배포가 없다면 지우세요: rmdir $LOCK" >&2; exit 2
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT=".artifacts/releases/$STAMP"
mkdir -p "$OUT"
DERIVED="${AI_DERIVED_DATA_PATH:-.artifacts/DerivedData}"
APP="$OUT/$APP_NAME.app"
ZIP="$OUT/$APP_NAME-notarize.zip"

# 단계 결과를 기록하고, 실패하면 보고서를 쓰고 끝낸다.
STEPS=()
VERSION="?"; BUILD_NO="?"; SUBMISSION="-"; DIST="-"
step() { STEPS+=("- $1: $2"); }
report() {
  local overall=$1
  {
    echo "# 배포(공증) 검증 보고서"
    echo
    echo "- 전체 결과: **$overall**"
    echo "- 실행 시각: $STAMP"
    echo "- 앱: $APP_NAME $VERSION ($BUILD_NO)"
    echo "- 서명 인증서: Developer ID Application (팀 $TEAM_ID)"
    echo "- 공증 제출 ID: $SUBMISSION"
    echo "- 배포 파일: $DIST"
    echo
    echo "## 단계"
    for s in "${STEPS[@]}"; do echo "$s"; done
    echo
    echo "## 파일"
    echo "- verify.log (사전 검증), build.log, $APP_NAME.xcarchive (dSYM 포함), codesign.txt, notary-submit.json, notary-log.json, gatekeeper.txt"
    echo
    echo "## 사람 검토 체크리스트"
    echo "- [ ] 다른 Mac에서 배포 파일을 내려받아 실행해 봄 (첫 실행 시 '인터넷에서 다운로드한 앱' 확인창은 정상)"
    echo "- [ ] 번들 ID와 버전이 배포 의도와 맞음"
  } > "$OUT/release-verification.md"
  printf '\n보고서: %s/release-verification.md\n' "$OUT"
  cat "$OUT/release-verification.md"
}
fail() { step "$1" "FAIL ($2)"; report FAIL; exit 1; }

# ① 사전 검증: 테스트를 통과하지 못한 코드는 배포하지 않는다. 배포는 사람이 직접 실행하는 작업이므로
# 실제 클릭 UI 테스트까지 돌린다(full). 그동안 마우스·키보드를 쓰지 말라고 안내한다.
echo "사전 검증(verify.sh full)을 시작합니다. UI 테스트가 끝날 때까지(수 분) 마우스와 키보드를 쓰지 마세요."
if AI_UI_CONTROL=1 ./scripts/verify.sh full >"$OUT/verify.log" 2>&1; then
  step "① 사전 검증 (verify.sh full)" "PASS ($(cat .artifacts/latest-run))"
else
  fail "① 사전 검증 (verify.sh full)" "verify.log 참고"
fi

# ② Release 아카이브 → Developer ID 내보내기. 내보내기 단계에서 Xcode가 배포용으로 다시 서명하며
#    디버그 권한(get-task-allow)은 빼고, 샌드박스처럼 앱에 필요한 권한은 유지한다.
cat >"$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Developer ID Application</string>
  <key>teamID</key><string>$TEAM_ID</string>
</dict></plist>
PLIST
if xcodebuild archive -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED" -archivePath "$OUT/$APP_NAME.xcarchive" \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$SIGN_IDENTITY" DEVELOPMENT_TEAM="$TEAM_ID" \
    OTHER_CODE_SIGN_FLAGS="--timestamp" >"$OUT/build.log" 2>&1 \
  && xcodebuild -exportArchive -archivePath "$OUT/$APP_NAME.xcarchive" -exportPath "$OUT/export" \
    -exportOptionsPlist "$OUT/ExportOptions.plist" >>"$OUT/build.log" 2>&1; then
  ditto "$OUT/export/$APP_NAME.app" "$APP"
  rm -rf "$OUT/export"
  VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$APP/Contents/Info.plist" 2>/dev/null || echo "?")"
  BUILD_NO="$(plutil -extract CFBundleVersion raw -o - "$APP/Contents/Info.plist" 2>/dev/null || echo "?")"
  step "② Release 아카이브 및 Developer ID 내보내기" "PASS"
else
  fail "② Release 아카이브 및 Developer ID 내보내기" "build.log 참고"
fi

# ③ 서명 검사: 유효성, Developer ID, 타임스탬프, Hardened Runtime, 디버그 권한 없음,
#    그리고 개발 빌드(①에서 만든 Debug 앱)에 있던 권한이 배포 빌드에서 빠지지 않았는지.
{
  codesign --verify --deep --strict --verbose=2 "$APP" 2>&1
  codesign -dvv "$APP" 2>&1
  echo "--- entitlements"
  codesign -d --entitlements - --xml "$APP" 2>/dev/null | plutil -p - 2>&1
} >"$OUT/codesign.txt"
SIGN_PROBLEMS=""
codesign --verify --deep --strict "$APP" >/dev/null 2>&1 || SIGN_PROBLEMS="$SIGN_PROBLEMS 서명무효"
grep -q "^Authority=Developer ID Application" "$OUT/codesign.txt" || SIGN_PROBLEMS="$SIGN_PROBLEMS DeveloperID아님"
grep -q "^Timestamp=" "$OUT/codesign.txt" || SIGN_PROBLEMS="$SIGN_PROBLEMS 타임스탬프없음"
grep -qE "^CodeDirectory .*flags=.*runtime" "$OUT/codesign.txt" || SIGN_PROBLEMS="$SIGN_PROBLEMS HardenedRuntime없음"
grep -q '"com.apple.security.get-task-allow" => true' "$OUT/codesign.txt" && SIGN_PROBLEMS="$SIGN_PROBLEMS get-task-allow포함"
# 권한 이름 목록. 테스트 실행용으로 Xcode가 Debug에만 넣는 get-task-allow와 temporary-exception은 비교에서 뺀다.
ent_keys() {
  codesign -d --entitlements - --xml "$1" 2>/dev/null | plutil -p - 2>/dev/null \
    | sed -n 's/^  "\([^"]*\)" =>.*/\1/p' | grep -vE 'get-task-allow|temporary-exception' | sort
}
DEBUG_APP="$DERIVED/Build/Products/Debug/$APP_NAME.app"
MISSING="$(comm -23 <(ent_keys "$DEBUG_APP") <(ent_keys "$APP") | tr '\n' ' ')"
if [[ -n "$MISSING" ]]; then SIGN_PROBLEMS="$SIGN_PROBLEMS 권한누락:${MISSING% }"; fi
if [[ -z "$SIGN_PROBLEMS" ]]; then step "③ 서명 검사" "PASS (Developer ID, 타임스탬프, Hardened Runtime, 디버그 권한 없음, 권한: $(ent_keys "$APP" | sed 's/com.apple.security.//' | tr '\n' ' ' | sed 's/ $//'))"
else fail "③ 서명 검사" "${SIGN_PROBLEMS# }; codesign.txt 참고"; fi

if [[ $SIGN_ONLY -eq 1 ]]; then
  for s in "④ Apple 공증" "⑤ 공증 티켓 첨부 (staple)" "⑥ Gatekeeper 배포 검증" "⑦ 배포 파일 생성"; do
    step "$s" "NOT RUN (--sign-only)"
  done
  report "PASS (서명까지만, 배포 불가)"
  exit 0
fi

# ④ 공증 제출: Apple 서버에서 검사가 끝날 때까지 기다린다.
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json \
  >"$OUT/notary-submit.json" 2>"$OUT/notary-submit.err"
SUBMISSION="$(plutil -extract id raw -o - "$OUT/notary-submit.json" 2>/dev/null || echo "-")"
NOTARY_STATUS="$(plutil -extract status raw -o - "$OUT/notary-submit.json" 2>/dev/null || echo "알 수 없음")"
if [[ "$SUBMISSION" != "-" ]]; then
  xcrun notarytool log "$SUBMISSION" --keychain-profile "$NOTARY_PROFILE" "$OUT/notary-log.json" >/dev/null 2>&1
fi
rm -f "$ZIP"
if [[ "$NOTARY_STATUS" == Accepted ]]; then step "④ Apple 공증" "PASS (Accepted)"
else fail "④ Apple 공증" "상태 $NOTARY_STATUS; notary-log.json, notary-submit.err 참고"; fi

# ⑤ 공증 티켓을 앱에 붙여 오프라인에서도 Gatekeeper를 통과하게 한다.
if xcrun stapler staple "$APP" >"$OUT/staple.log" 2>&1 && xcrun stapler validate "$APP" >>"$OUT/staple.log" 2>&1; then
  step "⑤ 공증 티켓 첨부 (staple)" "PASS"
else
  fail "⑤ 공증 티켓 첨부 (staple)" "staple.log 참고"
fi

# ⑥ 배포 검증: Gatekeeper 판정과 Apple의 배포 전 검사.
{
  echo "--- spctl"; spctl --assess --type execute --verbose=4 "$APP" 2>&1
  echo "--- syspolicy_check distribution"; syspolicy_check distribution "$APP" 2>&1
} >"$OUT/gatekeeper.txt"
if grep -q "source=Notarized Developer ID" "$OUT/gatekeeper.txt" && grep -q ": accepted" "$OUT/gatekeeper.txt" \
   && syspolicy_check distribution "$APP" >/dev/null 2>&1; then
  step "⑥ Gatekeeper 배포 검증" "PASS (Notarized Developer ID, syspolicy_check 통과)"
else
  fail "⑥ Gatekeeper 배포 검증" "gatekeeper.txt 참고"
fi

# ⑦ 배포용 zip (staple된 앱).
DIST="$OUT/$APP_NAME-$VERSION.zip"
ditto -c -k --keepParent "$APP" "$DIST"
step "⑦ 배포 파일 생성" "PASS ($(du -h "$DIST" | cut -f1 | tr -d ' '))"
report PASS
exit 0
