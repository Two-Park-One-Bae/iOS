#!/usr/bin/env bash
# models.lock 에 적힌 CoreML 모델을 ML 레포 DVC(S3)에서 받는다 (NM-482).
#
#   Tools/models.sh fetch   받는다. 이미 같은 REV 로 받은 것은 건너뛴다
#   Tools/models.sh check   받은 것이 models.lock 과 맞는지만 본다(네트워크 안 씀). 빌드 단계가 부른다
#
# 필요한 것: dvc(S3 지원) · AWS 프로필 nursemate-dvc · ML 레포(private) 를 클론할 수 있는 git 자격증명.
# 프로필은 AWS_PROFILE 로 바꿀 수 있다.
#
# 받은 흔적(stamp)은 .models/ 에 남긴다. mlpackage 안에 쓰지 않는 이유: 번들에 섞여 들어가기 때문이다.
set -euo pipefail

# git 훅(post-merge → make beta)에서 불리면 GIT_DIR 등이 넘어온다. 다른 레포를 다루므로 지운다.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX
# 인증이 안 되면 아이디를 묻고 멈추는 대신 바로 실패한다 — 훅·젠킨스에는 답할 사람이 없다.
export GIT_TERMINAL_PROMPT=0

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK="$ROOT/models.lock"
STAMPS="$ROOT/.models"
ML_REPO="https://github.com/Two-Park-One-Bae/ML"
# ML 레포는 git CLI 로 여기에 받아 두고 dvc get 은 이 로컬 클론을 읽는다.
# dvc get 에 GitHub URL 을 주면 DVC 가 자체 git 구현으로 클론하는데, 그쪽은 키체인 자격증명을
# 못 찾고 터미널에서 아이디를 물었다(훅 실행 시). git CLI 는 평소 push·pull 과 같은 인증을 쓴다.
ML_CLONE="$STAMPS/ML"
export AWS_PROFILE="${AWS_PROFILE:-nursemate-dvc}"

REV="$(sed -n 's/^REV=//p' "$LOCK")"
[ -n "$REV" ] || { echo "error: models.lock 에 REV 가 없다"; exit 1; }

# 주석·빈 줄·REV 줄을 뺀 "<ML 경로> <목적지>" 줄만
entries() { grep -v -E '^[[:space:]]*(#|$|REV=)' "$LOCK"; }

stamp_of() { echo "$STAMPS/$(basename "$1").stamp"; }

is_current() {  # $1=ML 경로 $2=목적지
  local dst="$ROOT/$2" stamp
  stamp="$(stamp_of "$2")"
  [ -d "$dst" ] && [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$REV $1" ]
}

cmd_check() {
  local bad=0 src dst
  while read -r src dst; do
    if ! is_current "$src" "$dst"; then
      echo "error: 모델이 없거나 models.lock 과 다르다 — $dst"
      bad=1
    fi
  done < <(entries)
  if [ "$bad" -ne 0 ]; then
    echo "error: 저장소 루트에서 'make models' 를 먼저 실행하세요 (필요한 것: dvc · AWS 프로필 $AWS_PROFILE)."
    exit 1
  fi
}

ML_READY=0
ensure_ml_clone() {  # REV 가 들어 있는 ML 로컬 클론을 준비한다 (fetch 한 번에 한 번만)
  [ "$ML_READY" -eq 1 ] && return
  if [ -d "$ML_CLONE/.git" ]; then
    git -C "$ML_CLONE" cat-file -e "$REV^{commit}" 2>/dev/null || git -C "$ML_CLONE" fetch -q origin
  else
    echo "== ML 레포 클론 ($ML_REPO) =="
    git clone -q --no-checkout "$ML_REPO" "$ML_CLONE" || {
      echo "error: ML 레포(private)를 클론하지 못했다 — 이 셸의 git 이 GitHub 에 로그인돼 있는지 확인하세요 (gh auth status)."
      exit 1
    }
  fi
  git -C "$ML_CLONE" cat-file -e "$REV^{commit}" 2>/dev/null || {
    echo "error: ML 레포에 커밋 $REV 가 없다 — models.lock 의 REV 를 확인하세요."
    exit 1
  }
  ML_READY=1
}

cmd_fetch() {
  command -v dvc >/dev/null || { echo "error: dvc 가 없다 — brew install dvc"; exit 1; }
  mkdir -p "$STAMPS"
  local src dst tmp
  while read -r src dst; do
    if is_current "$src" "$dst"; then
      echo "✅ $(basename "$dst") (이미 받음)"
      continue
    fi
    ensure_ml_clone
    echo "⬇️  $(basename "$dst") ← ML@${REV:0:7}:$src"
    # 임시 위치에 다 받은 뒤 바꿔 끼운다 — 받다 실패해도 기존 파일이 반쯤 지워진 채 남지 않게.
    tmp="$(mktemp -d)"
    dvc get "$ML_CLONE" "$src" --rev "$REV" -o "$tmp/$(basename "$dst")"
    rm -rf "$ROOT/$dst"
    mkdir -p "$(dirname "$ROOT/$dst")"
    mv "$tmp/$(basename "$dst")" "$ROOT/$dst"
    rm -rf "$tmp"
    echo "$REV $src" > "$(stamp_of "$dst")"
  done < <(entries)
  cmd_check
}

case "${1:-}" in
  fetch) cmd_fetch ;;
  check) cmd_check ;;
  *) echo "usage: $0 fetch|check"; exit 2 ;;
esac
