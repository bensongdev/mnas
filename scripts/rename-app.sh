#!/usr/bin/env bash
# 복제한 프로젝트의 앱 이름을 바꾼다: scripts/rename-app.sh <새이름> [번들ID접두사]
# project.yml과 Swift 소스 내용/파일명을 고친다. 아무것도 삭제하지 않는다: 예전에 생성된
# .xcodeproj는 그대로 두므로 확인한 뒤 직접 지운다.
set -euo pipefail
cd "$(dirname "$0")/.."
NEW="${1:-}"
PREFIX="${2:-}"
if [[ ! "$NEW" =~ ^[A-Za-z][A-Za-z0-9]*$ ]]; then
  echo "사용법: scripts/rename-app.sh <새이름> [번들ID접두사]  (새이름: 영문자/숫자만, 영문자로 시작. 예: MyApp com.mycompany)" >&2
  exit 2
fi
if [[ -n "$PREFIX" && ! "$PREFIX" =~ ^[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z0-9-]+)*$ ]]; then
  echo "번들 ID 접두사가 올바르지 않습니다: $PREFIX (예: com.mycompany)" >&2; exit 2
fi
OLD="$(sed -n 's/^name:[[:space:]]*//p' project.yml | head -1 | tr -d "\"'")"
if [[ -z "$OLD" ]]; then echo "project.yml에서 'name:'을 읽지 못했습니다" >&2; exit 2; fi
if [[ "$OLD" == "$NEW" && -z "$PREFIX" ]]; then echo "이미 이름이 $NEW 입니다"; exit 0; fi

FILES=(project.yml)
while IFS= read -r f; do FILES+=("$f"); done < <(grep -rl --include='*.swift' "$OLD" App AppTests AppUITests || true)
# 단순 문자열 치환으로 <Old>Tests, <Old>UITests, <Old>App, TEST_HOST 경로까지 함께 바뀐다.
for f in "${FILES[@]}"; do sed -i '' "s/$OLD/$NEW/g" "$f"; done
if [[ -n "$PREFIX" ]]; then sed -i '' "s/^\\([[:space:]]*bundleIdPrefix:\\).*/\\1 $PREFIX/" project.yml; fi
while IFS= read -r f; do mv "$f" "${f//$OLD/$NEW}"; done < <(find App AppTests AppUITests -name "*$OLD*.swift")

echo "$OLD -> $NEW 로 이름을 바꿨습니다. 수정한 파일: ${FILES[*]}"
grep -n '^[[:space:]]*bundleIdPrefix:' project.yml
if [[ -d "$OLD.xcodeproj" ]]; then echo "예전 프로젝트 $OLD.xcodeproj 는 남겨 두었습니다 ($NEW 빌드를 확인한 뒤 직접 지우세요)"; fi
echo "다음 단계: scripts/bootstrap.sh && scripts/verify.sh all"
