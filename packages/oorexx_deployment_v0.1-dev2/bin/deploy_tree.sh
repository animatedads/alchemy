#!/bin/sh
set -eu
usage(){
  echo "usage: $0 --source DIR --target-root PATH [--host HOST] [--user USER] [--identity KEY] [--dry-run]" >&2
}
SOURCE=''; TARGET_ROOT=''; HOST=''; USER_NAME=''; IDENTITY=''; DRY=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --source) SOURCE=$2; shift 2;;
    --target-root) TARGET_ROOT=$2; shift 2;;
    --host) HOST=$2; shift 2;;
    --user) USER_NAME=$2; shift 2;;
    --identity) IDENTITY=$2; shift 2;;
    --dry-run) DRY=1; shift;;
    *) usage; exit 2;;
  esac
done
[ -n "$SOURCE" ] && [ -d "$SOURCE" ] && [ -n "$TARGET_ROOT" ] || { usage; exit 2; }
command -v sha256sum >/dev/null 2>&1 || { echo 'FAIL sha256sum unavailable on deployment controller' >&2; exit 3; }
command -v tar >/dev/null 2>&1 || { echo 'FAIL tar unavailable on deployment controller' >&2; exit 3; }

tree_hash(){
  (cd "$1" && find . -type f ! -path './run/*' ! -name '.deployment-tree-sha256' -print | LC_ALL=C sort | while IFS= read -r f; do
     h=$(sha256sum "$f" | awk '{print $1}')
     printf '%s  %s\n' "$h" "$f"
   done) | sha256sum | awk '{print $1}'
}
GEN=$(tree_hash "$SOURCE")
REMOTE=${TARGET_ROOT%/}/releases/$GEN
CURRENT=${TARGET_ROOT%/}/current
if [ "$DRY" -eq 1 ]; then
  printf 'PLAN generation=%s target=%s current=%s host=%s\n' "$GEN" "$REMOTE" "$CURRENT" "${HOST:-local}"
  exit 0
fi

if [ -z "$HOST" ]; then
  mkdir -p "$TARGET_ROOT/releases"
  remote_ok=0
  if [ -f "$REMOTE/.deployment-tree-sha256" ] && [ "$(cat "$REMOTE/.deployment-tree-sha256" 2>/dev/null || true)" = "$GEN" ]; then
    [ "$(tree_hash "$REMOTE")" = "$GEN" ] && remote_ok=1
  fi
  if [ "$remote_ok" -ne 1 ]; then
    rm -rf "$REMOTE" "$REMOTE.tmp"
    mkdir -p "$REMOTE.tmp"
    (cd "$SOURCE" && tar -cf - --exclude='./run' .) | (cd "$REMOTE.tmp" && tar -xf -)
    printf '%s\n' "$GEN" > "$REMOTE.tmp/.deployment-tree-sha256"
    mv "$REMOTE.tmp" "$REMOTE"
  fi
  ln -sfn "$REMOTE" "$CURRENT.tmp"
  if mv -Tf "$CURRENT.tmp" "$CURRENT" 2>/dev/null; then :; else rm -f "$CURRENT"; ln -s "$REMOTE" "$CURRENT"; fi
  printf 'STAGED generation=%s current=%s\n' "$GEN" "$CURRENT"
  exit 0
fi

command -v ssh >/dev/null 2>&1 || { echo 'FAIL ssh unavailable on deployment controller' >&2; exit 3; }
DEST=$HOST; [ -n "$USER_NAME" ] && DEST=$USER_NAME@$HOST
# Use argv arrays through a helper function; target paths are passed as positional arguments to sh.
ssh_do(){
  if [ -n "$IDENTITY" ]; then ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -i "$IDENTITY" "$DEST" "$@"
  else ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$DEST" "$@"
  fi
}
ssh_do sh -s -- "$TARGET_ROOT" "$GEN" <<'EOS'
set -eu
root=$1; gen=$2
mkdir -p "$root/releases"
remote="$root/releases/$gen"
if [ -f "$remote/.deployment-tree-sha256" ] && [ "$(cat "$remote/.deployment-tree-sha256")" = "$gen" ]; then exit 0; fi
rm -rf "$remote" "$remote.tmp"; mkdir -p "$remote.tmp"
EOS
if ! ssh_do sh -s -- "$REMOTE" "$GEN" <<'EOS'
set -eu
remote=$1; gen=$2
[ -f "$remote/.deployment-tree-sha256" ] && [ "$(cat "$remote/.deployment-tree-sha256")" = "$gen" ] || exit 1
actual=$(cd "$remote" && find . -type f ! -path './run/*' ! -name '.deployment-tree-sha256' -print | LC_ALL=C sort | while IFS= read -r f; do h=$(sha256sum "$f" | awk '{print $1}'); printf '%s  %s\n' "$h" "$f"; done | sha256sum | awk '{print $1}')
[ "$actual" = "$gen" ]
EOS
then
  if [ -n "$IDENTITY" ]; then
    (cd "$SOURCE" && tar -cf - --exclude='./run' .) | ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -i "$IDENTITY" "$DEST" sh -s -- "$REMOTE" <<'EOS'
set -eu
remote=$1
cd "$remote.tmp"; tar -xf -
EOS
  else
    (cd "$SOURCE" && tar -cf - --exclude='./run' .) | ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$DEST" sh -s -- "$REMOTE" <<'EOS'
set -eu
remote=$1
cd "$remote.tmp"; tar -xf -
EOS
  fi
  ssh_do sh -s -- "$REMOTE" "$GEN" <<'EOS'
set -eu
remote=$1; gen=$2
printf '%s\n' "$gen" > "$remote.tmp/.deployment-tree-sha256"
mv "$remote.tmp" "$remote"
EOS
fi
ssh_do sh -s -- "$TARGET_ROOT" "$REMOTE" <<'EOS'
set -eu
root=$1; remote=$2
current="$root/current"
ln -sfn "$remote" "$current.tmp"
if mv -Tf "$current.tmp" "$current" 2>/dev/null; then :; else rm -f "$current"; ln -s "$remote" "$current"; fi
EOS
printf 'STAGED generation=%s current=%s host=%s\n' "$GEN" "$CURRENT" "$HOST"
