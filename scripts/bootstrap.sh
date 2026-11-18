#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then echo "macOS가 필요합니다" >&2; exit 1; fi
if ! xcode-select -p >/dev/null 2>&1 || ! xcrun --find xcodebuild >/dev/null 2>&1; then
  echo "전체 Xcode를 설치하고 선택하세요: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2; exit 1
fi
if ! command -v xcodegen >/dev/null; then echo "XcodeGen을 설치하세요: brew install xcodegen" >&2; exit 1; fi
if ! command -v swiftlint >/dev/null; then echo "참고: SwiftLint가 없어 verify.sh의 코드 스타일 검사가 NOT RUN으로 보고됩니다 (brew install swiftlint)" >&2; fi
xcodegen generate
APP_NAME="$(sed -n 's/^name:[[:space:]]*//p' project.yml | head -1 | tr -d "\"'")"
printf '\n%s.xcodeproj 생성 완료. 다음 단계: ./scripts/verify.sh all\n' "$APP_NAME"
