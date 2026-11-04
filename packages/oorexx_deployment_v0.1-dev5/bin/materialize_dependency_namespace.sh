#!/bin/sh
# Materialise an already-resolved ooRexx dependency lock into an isolated,
# deterministic package namespace.  This is a POSIX provider helper: dependency
# authority comes from the lock (normally SSC), not from ambient REXX_PATH.
set -eu

lock=''
roots=''
out=''
entries=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --lock) lock=$2; shift 2 ;;
    --roots) roots=$2; shift 2 ;;
    --output) out=$2; shift 2 ;;
    --entry)
      if [ -z "$entries" ]; then entries=$2; else entries="$entries
$2"; fi
      shift 2 ;;
    --help|-h)
      cat <<'USAGE'
usage: materialize_dependency_namespace.sh --lock LOCK.tsv --roots ROOTS.tsv \
       --output DIR --entry COMPONENT:relative/package.cls [--entry ...]

ROOTS.tsv columns:
  component<TAB>component-root<TAB>artifact-hash

The artifact hash must match the corresponding artifact record in LOCK.tsv when
that lock carries a hash.  Ambient REXX_PATH is never consulted.
USAGE
      exit 0 ;;
    *) echo "FAIL unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$lock" ] && [ -f "$lock" ] || { echo 'FAIL --lock is required' >&2; exit 2; }
[ -n "$roots" ] && [ -f "$roots" ] || { echo 'FAIL --roots is required' >&2; exit 2; }
[ -n "$out" ] || { echo 'FAIL --output is required' >&2; exit 2; }
[ -n "$entries" ] || { echo 'FAIL at least one --entry is required' >&2; exit 2; }
command -v sha256sum >/dev/null 2>&1 || { echo 'FAIL sha256sum is required by this POSIX provider' >&2; exit 2; }

TAB=$(printf '\t')
tmp=${out}.tmp.$$
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
rm -rf "$tmp"
mkdir -p "$tmp/components" "$tmp/evidence"
cp "$lock" "$tmp/evidence/dependency.lock.tsv"
cp "$roots" "$tmp/evidence/component-roots.tsv"

# Reject an unresolved or malformed lock before touching the destination.
awk -F '\t' '
  $1=="issue" && ($3=="1" || toupper($3)=="TRUE" || toupper($3)==".TRUE") { bad=1; print "required issue: "$4 > "/dev/stderr" }
  $1=="component" && !($9=="1" || toupper($9)=="TRUE" || toupper($9)==".TRUE") { bad=1; print "unsatisfied component: "$2 > "/dev/stderr" }
  $1=="package" && !($7=="1" || toupper($7)=="TRUE" || toupper($7)==".TRUE") { bad=1; print "unsatisfied package: "$2" -> "$4 > "/dev/stderr" }
  END { exit bad ? 1 : 0 }
' "$lock" || { echo 'FAIL dependency lock is not satisfied' >&2; exit 4; }

root_for() {
  wanted=$1
  awk -F '\t' -v w="$wanted" 'toupper($1)==toupper(w) { print $2; exit }' "$roots"
}
root_hash_for() {
  wanted=$1
  awk -F '\t' -v w="$wanted" 'toupper($1)==toupper(w) { print $3; exit }' "$roots"
}
lock_hash_for() {
  wanted=$1
  awk -F '\t' -v w="$wanted" '$1=="artifact" && toupper($2)==toupper(w) { print $6; exit }' "$lock"
}
component_dir() {
  c=$1
  safe=$(printf '%s' "$c" | tr -c 'A-Za-z0-9_-' '_')
  key=$(printf '%s' "$c" | sha256sum | awk '{print substr($1,1,12)}')
  printf '%s-%s' "$safe" "$key"
}
validate_rel() {
  p=$1
  case "$p" in
    ''|/*|../*|*/../*|*/..|..|*"$TAB"*|*"\n"*) return 1 ;;
  esac
  return 0
}

# Verify every supplied component root against the immutable artifact identity in
# the lock where available.  A root map may contain extra components; they are
# ignored unless reachable from the lock/entry set.
awk -F '\t' 'NF && NF<2 { print "malformed roots row: "$0 > "/dev/stderr"; bad=1 } END { exit bad?1:0 }' "$roots" || exit 4

manifest_rows="$tmp/evidence/materialized-files.tsv"
: > "$manifest_rows"
path_rows="$tmp/evidence/rexx-path.relative.txt"
: > "$path_rows"
seen_files="$tmp/evidence/.seen-files"
seen_dirs="$tmp/evidence/.seen-dirs"
: > "$seen_files"; : > "$seen_dirs"

add_dir() {
  d=$1
  grep -F -x -- "$d" "$seen_dirs" >/dev/null 2>&1 && return 0
  printf '%s\n' "$d" >> "$seen_dirs"
  printf '%s\n' "$d" >> "$path_rows"
}

copy_locked_file() {
  comp=$1
  rel=$2
  validate_rel "$rel" || { echo "FAIL unsafe dependency path: $comp:$rel" >&2; exit 4; }
  key="$comp$TAB$rel"
  grep -F -x -- "$key" "$seen_files" >/dev/null 2>&1 && return 0
  printf '%s\n' "$key" >> "$seen_files"

  srcroot=$(root_for "$comp")
  [ -n "$srcroot" ] && [ -d "$srcroot" ] || { echo "FAIL no component root for $comp" >&2; exit 4; }
  expected=$(lock_hash_for "$comp")
  supplied=$(root_hash_for "$comp")
  if [ -n "$expected" ]; then
    [ -n "$supplied" ] || { echo "FAIL root map lacks artifact hash for $comp" >&2; exit 4; }
    [ "$expected" = "$supplied" ] || { echo "FAIL artifact authority mismatch for $comp" >&2; exit 4; }
  fi
  src="$srcroot/$rel"
  [ -f "$src" ] || { echo "FAIL locked package file missing: $comp:$rel" >&2; exit 4; }
  cdir=$(component_dir "$comp")
  dstrel="components/$cdir/$rel"
  dst="$tmp/$dstrel"
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  h=$(sha256sum "$dst" | awk '{print $1}')
  printf '%s\t%s\t%s\t%s\n' "$comp" "$rel" "$dstrel" "$h" >> "$manifest_rows"
  add_dir "components/$cdir/$(dirname "$rel")"
}

# Explicit entry packages are roots of the executable package graph.  Syntax is
# COMPONENT:path; split on the first colon only (component ids must not contain
# colon in this provider contract).
printf '%s\n' "$entries" | while IFS= read -r ep; do
  comp=${ep%%:*}
  rel=${ep#*:}
  [ "$comp" != "$ep" ] && [ -n "$comp" ] && [ -n "$rel" ] || { echo "FAIL bad --entry $ep" >&2; exit 4; }
  copy_locked_file "$comp" "$rel"
done

# Copy every reachable consumer and provider file recorded by the dependency
# lock.  This creates only the reachable package namespace, not a whole-ZIP dump.
while IFS="$TAB" read -r kind consumer consumerpkg required provider providerpath satisfied reason_rest; do
  [ "$kind" = package ] || continue
  copy_locked_file "$consumer" "$consumerpkg"
  copy_locked_file "$provider" "$providerpath"
done < "$lock"

rm -f "$seen_files" "$seen_dirs"

# Absolute REXX_PATH is generated only after the namespace location is fixed.
: > "$tmp/evidence/rexx-path.txt"
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  printf '%s/%s\n' "$out" "$rel" >> "$tmp/evidence/rexx-path.txt"
done < "$path_rows"

# A shell fragment is provided for launchers.  It replaces, rather than extends,
# ambient REXX_PATH.  Dependency authority has already been decided by SSC/lock.
rexx_path=$(awk 'BEGIN{ORS=""} NR>1{printf ":"} {printf "%s",$0}' "$tmp/evidence/rexx-path.txt")
printf "REXX_PATH='%s'\nexport REXX_PATH\n" "$(printf '%s' "$rexx_path" | sed "s/'/'\\\\''/g")" > "$tmp/environment.sh"

# Seal namespace contents.  The evidence copies are deliberately included.
(
  cd "$tmp"
  find components evidence -type f ! -name MANIFEST.sha256 -print | LC_ALL=C sort | while IFS= read -r f; do sha256sum "$f"; done
  sha256sum environment.sh
) > "$tmp/MANIFEST.sha256"

# Verify before publish; then replace atomically at directory granularity where
# the platform permits rename(2).  Existing corrupt output is never accepted.
(
  cd "$tmp"
  sha256sum -c MANIFEST.sha256 >/dev/null
)
rm -rf "$out.new.$$"
mv "$tmp" "$out.new.$$"
trap 'rm -rf "$out.new.$$"' EXIT HUP INT TERM
rm -rf "$out"
mv "$out.new.$$" "$out"
trap - EXIT HUP INT TERM

echo "READY dependency-namespace output=$out files=$(wc -l < "$out/evidence/materialized-files.tsv" | tr -d ' ') rexx-path=$(tr '\n' ':' < "$out/evidence/rexx-path.relative.txt" | sed 's/:$//')"
