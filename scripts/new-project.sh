#!/usr/bin/env bash
# 이 템플릿으로 새 앱 프로젝트를 만든다: scripts/new-project.sh <앱이름> [번들ID접두사] [만들 폴더]
# Git에 커밋된 파일만 복사하므로 .artifacts, 생성된 .xcodeproj, 커밋하지 않은 변경은 따라가지 않는다.
# 만들 폴더를 생략하면 홈 폴더(~)에 <앱이름> 폴더를 만든다. 이미 있는 폴더는 건드리지 않는다.
set -euo pipefail
# ~/.local/bin 등에 심볼릭 링크로 설치해도 템플릿 위치를 찾도록 링크를 따라간다.
TEMPLATE="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
NAME="${1:-}"
PREFIX="${2:-}"
DEST="${3:-$HOME/$NAME}"

if [[ ! "$NAME" =~ ^[A-Za-z][A-Za-z0-9]*$ ]]; then
  echo "사용법: $(basename "$0") <앱이름> [번들ID접두사] [만들 폴더]" >&2
  echo "  앱이름: 영문자/숫자만, 영문자로 시작. 예: $(basename "$0") MyApp com.mycompany" >&2
  exit 2
fi
for tool in git xcodegen; do
  command -v "$tool" >/dev/null || { echo "$tool 이 필요합니다 (README의 설치 단계 참고)" >&2; exit 2; }
done
if [[ -e "$DEST" ]]; then echo "이미 있는 경로입니다: $DEST (다른 이름이나 폴더를 지정하세요)" >&2; exit 2; fi
git -C "$TEMPLATE" rev-parse --verify -q HEAD >/dev/null \
  || { echo "템플릿 저장소에 커밋이 없습니다: $TEMPLATE" >&2; exit 2; }
if [[ -n "$(git -C "$TEMPLATE" status --porcelain)" ]]; then
  echo "참고: 템플릿에 커밋하지 않은 변경이 있습니다. 새 프로젝트에는 마지막 커밋 내용만 들어갑니다."
fi

mkdir -p "$DEST"
git -C "$TEMPLATE" archive --format=tar HEAD | tar -x -C "$DEST"
"$DEST/scripts/rename-app.sh" "$NAME" $PREFIX
git -C "$DEST" init -q -b main
"$DEST/scripts/bootstrap.sh"

echo
echo "새 프로젝트를 만들었습니다: $DEST"
echo "Git 저장소는 초기화만 했고 커밋은 하지 않았습니다."
echo "다음 단계:"
echo "  cd \"$DEST\""
echo "  ./scripts/verify.sh all      # 빌드와 테스트가 통과하는지 확인"
echo "  open $NAME.xcodeproj         # Xcode로 열기"
