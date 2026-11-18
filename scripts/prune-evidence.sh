#!/usr/bin/env bash
# 사람이 지울 것을 고를 수 있도록 실행별 크기와 결과를 보여 준다. 아무것도 삭제하지 않는다.
set -euo pipefail
cd "$(dirname "$0")/.."
TARGET=".artifacts/runs"
DERIVED="${AI_DERIVED_DATA_PATH:-.artifacts/DerivedData}"
if [[ ! -d "$TARGET" ]]; then echo "저장된 검증 실행이 없습니다"; exit 0; fi
echo '크기     결과   실행 폴더'
for run in "$TARGET"/*/; do
  run="${run%/}"
  result="$(sed -n 's/^- 전체 결과: \*\*\([A-Z]*\)\*\*.*/\1/p' "$run/verification.md" 2>/dev/null || true)"
  printf '%-8s %-6s %s\n' "$(du -sh "$run" | cut -f1)" "${result:-?}" "$run"
done
printf '\n실행 폴더 합계: %s\n' "$(du -sh "$TARGET" | cut -f1)"
if [[ -d "$DERIVED" ]]; then printf '빌드 캐시 (%s): %s\n' "$DERIVED" "$(du -sh "$DERIVED" | cut -f1)"; fi
printf '\n이 스크립트는 목록만 보여 줍니다. 확인한 뒤 필요한 것만 직접 지우세요. 예:\n'
printf '  rm -rf %s/<RUN>       # 확인한 실행 폴더 하나\n' "$TARGET"
printf '  rm -rf %s   # 빌드 캐시. 다음 검증 때 처음부터 다시 빌드함\n' "$DERIVED"
