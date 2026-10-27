#!/usr/bin/env bash
# Independent phase-gated BSF4ooRexx/JDORFX qualification. Does not change the interpreter.
set -euo pipefail
phase=${1:-}
fail(){ printf 'FAIL %s: %s\n' "${phase:-preflight}" "$*" >&2; exit 2; }
[[ $# -eq 1 && ( $phase == native || $phase == bsf || $phase == jdorfx ) ]] || fail 'usage: qualify.sh native|bsf|jdorfx'
need_file(){ [[ -f $1 ]] || fail "file not found: $1"; }
need_dir(){ [[ -d $1 ]] || fail "directory not found: $1"; }
need_cmd(){ command -v "$1" >/dev/null || fail "command not found: $1"; }
[[ ${OO_ROOT:-} == /* ]] || fail 'OO_ROOT must be an absolute ooRexx installation prefix'
need_file "$OO_ROOT/bin/rexx"
need_dir "$OO_ROOT/lib"
need_cmd mktemp
need_cmd timeout
repeats=${REPEATS:-3}
[[ $repeats =~ ^[1-9][0-9]*$ && ${#repeats} -le 5 ]] || fail 'REPEATS must be an integer from 1 to 99999'
max_seconds=${MAX_SECONDS:-90}
[[ $max_seconds =~ ^[1-9][0-9]*$ && ${#max_seconds} -le 5 ]] || fail 'MAX_SECONDS must be a positive integer <= 99999'
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
run_case(){
  local name=$1 outfile=$2
  shift 2
  if ! timeout --signal=TERM --kill-after=5 "${max_seconds}s" "$@" >"$outfile" 2>&1; then
    cat "$outfile" >&2
    fail "$name failed or timed out"
  fi
}
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
if [[ $phase == native ]]; then
  [[ ${RX2CPP_ROOT:-} == /* ]] || fail 'RX2CPP_ROOT must name an absolute checkout of animatedads/oorexx/oorexx2cpp'
  need_cmd g++
  need_dir "$OO_ROOT/include"
  src="$RX2CPP_ROOT/ootest/interpreter_bugs/crash"
  need_dir "$src"
  for f in stalecrash.cpp stalecrash.rex validgc.cpp validgc.rex; do need_file "$src/$f"; cp "$src/$f" "$work/$f"; done
  for name in stalecrash validgc; do
    g++ -std=c++17 -O0 -shared -fPIC -I"$OO_ROOT/include" -o "$work/lib$name.so" "$work/$name.cpp" || fail "compile $name"
  done
  export LD_LIBRARY_PATH="$work:$LD_LIBRARY_PATH"
  for ((i=1;i<=repeats;i++)); do
    (cd "$work" && run_case stalecrash "$work/stale.$i.log" "$OO_ROOT/bin/rexx" stalecrash.rex)
    grep -Fq 'CheckCondition=1' "$work/stale.$i.log" || fail 'native condition not immediately reported'
    grep -Fq 'survived the collection' "$work/stale.$i.log" || fail 'GC did not survive'
    grep -Fq 'SYNTAX 88.922' "$work/stale.$i.log" || fail 'SYNTAX 88.922 absent'
    (cd "$work" && run_case validgc "$work/valid.$i.log" "$OO_ROOT/bin/rexx" validgc.rex)
    grep -Fq 'valid send, CheckCondition=0' "$work/valid.$i.log" || fail 'valid control condition unexpected'
    grep -Fq 'survived the collection' "$work/valid.$i.log" || fail 'valid control GC failed'
  done
  printf 'PASS native: %s patched-error and %s valid-control GC runs\n' "$repeats" "$repeats"
  exit 0
fi
[[ ${BSF_HOME:-} == /* ]] || fail 'BSF_HOME must name an absolute unpacked BSF4ooRexx850 root'
need_file "$BSF_HOME/BSF.CLS"
[[ ${BSF_JAR:-} == /* ]] || fail 'BSF_JAR must be an absolute, explicitly selected bridge JAR'
need_file "$BSF_JAR"
[[ ${BSF_NATIVE_LIBRARY:-} == /* ]] || fail 'BSF_NATIVE_LIBRARY must be an absolute, architecture-matched native .so'
need_file "$BSF_NATIVE_LIBRARY"
need_cmd java
if [[ -n ${JAVA_HOME:-} ]]; then
  need_dir "$JAVA_HOME/lib"
else
  need_cmd readlink
  java_binary=$(readlink -f "$(command -v java)")
  JAVA_HOME=$(dirname "$(dirname "$java_binary")")
fi
export CLASSPATH="$BSF_JAR${CLASSPATH:+:$CLASSPATH}"
mkdir -p "$work/native"
cp -- "$BSF_NATIVE_LIBRARY" "$work/native/libBSF4ooRexx850.so"
ln -s libBSF4ooRexx850.so "$work/native/libBSF4ooRexx.so"
export LD_LIBRARY_PATH="$work/native:$JAVA_HOME/lib/server:$JAVA_HOME/lib:$LD_LIBRARY_PATH"
export REXX_PATH="$work:$BSF_HOME${REXX_PATH:+:$REXX_PATH}"
if [[ $phase == bsf ]]; then
  [[ ${RX2CPP_ROOT:-} == /* ]] || fail 'RX2CPP_ROOT must name an absolute ooRexx2cpp checkout'
  fixtures="$RX2CPP_ROOT/native/fixtures"
  need_dir "$fixtures"
  for demo in bsf_demo bsf_callback; do
    need_file "$fixtures/$demo.cls"
    need_file "$fixtures/${demo}_client.rex"
    cp "$fixtures/$demo.cls" "$work/"
    cat "$fixtures/${demo}_client.rex" >"$work/$demo.rex"
    printf '\n::requires "%s.cls"\n' "$demo" >>"$work/$demo.rex"
    for ((i=1;i<=repeats;i++)); do
      (cd "$work" && run_case "$demo" "$work/$demo.$i.log" "$OO_ROOT/bin/rexx" "$demo.rex")
      grep -Fq 'done' "$work/$demo.$i.log" || fail "$demo did not complete"
      if [[ $demo == bsf_callback ]]; then
        grep -Fq 'after Java thread:' "$work/$demo.$i.log" || fail 'Java-thread callback missing'
        grep -Fq 'sorted by length:' "$work/$demo.$i.log" || fail 'Comparator callback missing'
      else
        grep -Fq 'StringBuilder length:' "$work/$demo.$i.log" || fail 'Java object smoke missing'
      fi
    done
  done
  printf 'PASS bsf: Java object and callbacks (%s repeats each)\n' "$repeats"
  exit 0
fi
[[ ${JDORFX_HOME:-} == /* ]] || fail 'JDORFX_HOME must be absolute selected release root'
need_dir "$JDORFX_HOME"
[[ ${JDORFX_SCRIPT:-} == /* ]] || fail 'JDORFX_SCRIPT must name a real sample from the selected archive'
need_file "$JDORFX_SCRIPT"
if [[ -n ${JAVAFX_MODULE_PATH:-} ]]; then
  need_dir "$JAVAFX_MODULE_PATH"
  need_file "$JAVAFX_MODULE_PATH/javafx.graphics.jar"
  [[ $JAVAFX_MODULE_PATH != *[[:space:]]* ]] || fail 'JAVAFX_MODULE_PATH with whitespace unsupported by JAVA_TOOL_OPTIONS'
  export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} --module-path=$JAVAFX_MODULE_PATH --add-modules=javafx.graphics,javafx.controls"
fi
if ! java --list-modules 2>/dev/null | grep -Eq '^javafx.graphics(@|$)'; then
  [[ -n ${JAVAFX_MODULE_PATH:-} || -n ${JAVAFX_CLASSPATH:-} ]] || fail 'JavaFX graphics absent: configure module/class path explicitly'
fi
[[ -n ${DISPLAY:-} || -n ${WAYLAND_DISPLAY:-} || ${JDORFX_HEADLESS_OK:-0} == 1 ]] || fail 'JDORFX needs a display or explicit headless configuration'
export REXX_PATH="$JDORFX_HOME:$REXX_PATH"
for ((i=1;i<=repeats;i++)); do
  run_case jdorfx "$work/jdorfx.$i.log" "$OO_ROOT/bin/rexx" "$JDORFX_SCRIPT"
  if [[ -n ${JDORFX_EXPECTED_TEXT:-} ]]; then
    grep -Fq -- "$JDORFX_EXPECTED_TEXT" "$work/jdorfx.$i.log" || fail 'JDORFX expected output missing'
  fi
done
printf 'PASS jdorfx: selected sample exited normally (%s repeats); visual equivalence NOT assessed\n' "$repeats"
